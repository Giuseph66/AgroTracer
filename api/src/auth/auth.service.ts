import {
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { createHmac, createPublicKey, timingSafeEqual, verify } from 'node:crypto';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';
import { PolicyService } from './policy.service';
import { AuthConfig, AuthPrincipal } from './auth.types';
import { verifyPassword } from './password';

type JwtClaims = Record<string, unknown> & {
  sub?: string;
  exp?: number;
  iss?: string;
  iat?: number;
};

const DEV_DEVICE_ID = '44444444-4444-4444-8444-444444444444';
const DEV_PROPERTY_ID = '66666666-6666-4666-8666-666666666666';

@Injectable()
export class AuthService {
  private jwks: { expiresAt: number; keys: Record<string, unknown>[] } | null = null;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly policy: PolicyService,
  ) {}

  config(): AuthConfig {
    const mode = process.env.AUTH_MODE === 'oidc' ? 'oidc' : 'dev';
    return {
      required: true,
      mode,
      issuer: process.env.OIDC_ISSUER ?? null,
    };
  }

  async devLogin(email: string, password: string) {
    if (this.config().mode !== 'dev') {
      throw new UnauthorizedException('login local desabilitado');
    }
    const principal = await this.findPrincipal(email, password);
    if (!principal) throw new UnauthorizedException('credenciais inválidas');
    const accessToken = this.signDevToken(principal);
    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn: this.tokenTtlSeconds(),
      principal,
    };
  }

  async me(token: string): Promise<AuthPrincipal> {
    return this.verifyToken(token);
  }

  async verifyToken(token: string): Promise<AuthPrincipal> {
    const claims = this.config().mode === 'oidc'
      ? await this.verifyOidcToken(token)
      : this.verifyDevToken(token);
    const subject = stringValue(claims.sub);
    if (!subject) throw new UnauthorizedException('token sem subject');
    if (typeof claims.exp === 'number' && claims.exp * 1000 <= Date.now()) {
      throw new UnauthorizedException('token expirado');
    }

    const principal = await this.findPrincipal(subject);
    if (!principal) throw new UnauthorizedException('usuário não cadastrado');
    if (this.config().mode === 'oidc' && this.config().issuer &&
        claims.iss !== this.config().issuer) {
      throw new UnauthorizedException('issuer OIDC inválido');
    }
    return {
      ...principal,
      deviceId: stringValue(claims.device_id) ?? principal.deviceId,
    };
  }

  private async findPrincipal(
    subjectOrEmail: string,
    password?: string,
  ): Promise<AuthPrincipal | undefined> {
    const { rows } = await this.pool.query(
      `SELECT u.id AS "actorId", u.oidc_subject AS subject,
              u.name, u.email, u.organization_id AS "organizationId",
              p.name AS "propertyName",
              u.password_hash AS "passwordHash",
              u.status, COALESCE(array_agg(b.role_code)
                FILTER (WHERE b.role_code IS NOT NULL AND
                  b.valid_from <= now() AND (b.valid_to IS NULL OR b.valid_to > now())),
                '{}') AS roles
         FROM core.app_user u
         LEFT JOIN core.property p
           ON p.id = $2::uuid AND p.organization_id = u.organization_id
         LEFT JOIN core.user_role_binding b
           ON b.user_id = u.id AND b.organization_id = u.organization_id
        WHERE (lower(u.email) = lower($1) OR u.oidc_subject = $1 OR u.id::text = $1)
        GROUP BY u.id, p.name
        LIMIT 1`,
      [subjectOrEmail, process.env.AUTH_PROPERTY_ID ?? DEV_PROPERTY_ID],
    );
    const row = rows[0];
    if (!row || row.status !== 'ACTIVE') return undefined;
    if (password !== undefined &&
        (!row.passwordHash || !verifyPassword(password, row.passwordHash))) {
      return undefined;
    }
    return {
      actorId: row.actorId,
      organizationId: row.organizationId,
      propertyId: process.env.AUTH_PROPERTY_ID ?? DEV_PROPERTY_ID,
      propertyName:
        row.propertyName ?? process.env.AUTH_PROPERTY_NAME ?? 'Fazenda Santa Rita',
      deviceId: process.env.AUTH_DEVICE_ID ?? DEV_DEVICE_ID,
      subject: row.subject ?? row.actorId,
      name: row.name,
      email: row.email,
      roles: Array.isArray(row.roles) ? row.roles : [],
      permissions: this.policy.permissionsFor(
        Array.isArray(row.roles) ? row.roles : [],
      ),
    };
  }

  private signDevToken(principal: AuthPrincipal): string {
    const now = Math.floor(Date.now() / 1000);
    const header = encode({ alg: 'HS256', typ: 'JWT' });
    const payload = encode({
      sub: principal.subject,
      actor_id: principal.actorId,
      organization_id: principal.organizationId,
      property_id: principal.propertyId,
      property_name: principal.propertyName,
      device_id: principal.deviceId,
      name: principal.name,
      email: principal.email,
      roles: principal.roles,
      iat: now,
      exp: now + this.tokenTtlSeconds(),
    });
    const input = `${header}.${payload}`;
    const signature = createHmac('sha256', this.jwtSecret())
      .update(input)
      .digest('base64url');
    return `${input}.${signature}`;
  }

  private verifyDevToken(token: string): JwtClaims {
    const [header, payload, signature] = token.split('.');
    if (!header || !payload || !signature) {
      throw new UnauthorizedException('token inválido');
    }
    let claims: JwtClaims;
    try {
      claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as JwtClaims;
      const headerData = JSON.parse(Buffer.from(header, 'base64url').toString('utf8')) as { alg?: string };
      if (headerData.alg !== 'HS256') throw new Error('alg');
    } catch {
      throw new UnauthorizedException('token inválido');
    }
    const expected = createHmac('sha256', this.jwtSecret())
      .update(`${header}.${payload}`)
      .digest('base64url');
    if (!safeEqual(expected, signature)) {
      throw new UnauthorizedException('assinatura do token inválida');
    }
    return claims;
  }

  private async verifyOidcToken(token: string): Promise<JwtClaims> {
    const [encodedHeader, encodedPayload, encodedSignature] = token.split('.');
    if (!encodedHeader || !encodedPayload || !encodedSignature) {
      throw new UnauthorizedException('token OIDC inválido');
    }
    let header: { alg?: string; kid?: string };
    let claims: JwtClaims;
    try {
      header = JSON.parse(Buffer.from(encodedHeader, 'base64url').toString('utf8'));
      claims = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8'));
    } catch {
      throw new UnauthorizedException('token OIDC inválido');
    }
    if (header.alg !== 'RS256' || !header.kid) {
      throw new UnauthorizedException('algoritmo OIDC não suportado');
    }
    const key = await this.jwk(header.kid);
    if (!key) throw new UnauthorizedException('chave OIDC não encontrada');
    try {
      const publicKey = createPublicKey({ key, format: 'jwk' });
      const valid = verify(
        'RSA-SHA256',
        Buffer.from(`${encodedHeader}.${encodedPayload}`),
        publicKey,
        Buffer.from(encodedSignature, 'base64url'),
      );
      if (!valid) throw new Error('signature');
    } catch {
      throw new UnauthorizedException('assinatura OIDC inválida');
    }
    return claims;
  }

  private async jwk(kid: string): Promise<Record<string, unknown> | undefined> {
    const now = Date.now();
    if (!this.jwks || this.jwks.expiresAt <= now) {
      const url = process.env.OIDC_JWKS_URL;
      if (!url) throw new UnauthorizedException('OIDC_JWKS_URL não configurada');
      const response = await fetch(url);
      if (!response.ok) throw new UnauthorizedException('JWKS indisponível');
      const body = await response.json() as { keys?: Record<string, unknown>[] };
      this.jwks = { keys: body.keys ?? [], expiresAt: now + 5 * 60 * 1000 };
    }
    return this.jwks.keys.find((key) => key.kid === kid);
  }

  private jwtSecret(): string {
    return process.env.AUTH_JWT_SECRET ?? 'traceagro-dev-secret-change-me';
  }

  /// Prazo do token dev. Revogação/suspensão são revalidadas no banco a cada
  /// requisição (findPrincipal), então um prazo longo não abre brecha de
  /// acesso — só evita reautenticar o operador em campo sem sinal por horas.
  private tokenTtlSeconds(): number {
    const raw = Number(process.env.AUTH_TOKEN_TTL_SECONDS);
    return Number.isFinite(raw) && raw > 0 ? raw : 60 * 60 * 24 * 30;
  }
}

function encode(value: object): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}
