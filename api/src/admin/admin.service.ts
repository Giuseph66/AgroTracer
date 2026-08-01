import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { v7 as uuidv7 } from 'uuid';
import { Pool, PoolClient } from 'pg';

import { AuthPrincipal } from '../auth/auth.types';
import { PolicyService } from '../auth/policy.service';
import { PG_POOL } from '../database/database.module';

export type CreateUserInput = {
  name: string;
  email: string;
  roles: string[];
};

export type UpdateUserInput = {
  name?: string;
  email?: string;
  status?: 'ACTIVE' | 'SUSPENDED';
  roles?: string[];
};

@Injectable()
export class AdminService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly policy: PolicyService,
  ) {}

  roles(principal: AuthPrincipal) {
    return this.policy.roles().filter(
      (role) => role.code !== 'ADMP' || principal.roles.includes('ADMP'),
    );
  }

  async users(principal: AuthPrincipal) {
    const { rows } = await this.pool.query(
      `SELECT u.id, u.name, u.email, u.status,
              u.professional_credential AS "professionalCredential",
              u.created_at AS "createdAt",
              COALESCE(array_agg(b.role_code ORDER BY b.role_code)
                FILTER (WHERE b.role_code IS NOT NULL AND
                  b.valid_from <= now() AND
                  (b.valid_to IS NULL OR b.valid_to > now())), '{}') AS roles
         FROM core.app_user u
         LEFT JOIN core.user_role_binding b
           ON b.user_id = u.id AND b.organization_id = u.organization_id
        WHERE u.organization_id = $1::uuid
        GROUP BY u.id
        ORDER BY (u.status = 'ACTIVE') DESC, lower(u.name)`,
      [principal.organizationId],
    );
    return rows;
  }

  async create(principal: AuthPrincipal, input: CreateUserInput) {
    this.assertAssignableRoles(principal, input.roles);
    return this.transaction(async (client) => {
      const id = uuidv7();
      try {
        await client.query(
          `INSERT INTO core.app_user
             (id, oidc_subject, name, email, organization_id)
           VALUES ($1::uuid, $2, $3, $2, $4::uuid)`,
          [id, input.email.toLowerCase(), input.name.trim(), principal.organizationId],
        );
      } catch (error) {
        if (isUniqueViolation(error)) {
          throw new ConflictException({
            code: 'ERR-AUTH-USER-EXISTS',
            message: 'já existe uma pessoa com este e-mail',
          });
        }
        throw error;
      }
      await this.addRoles(client, id, principal.organizationId, input.roles);
      await this.audit(client, principal, 'USER_CREATED', id, {
        roles: input.roles,
      });
      return this.user(client, principal.organizationId, id);
    });
  }

  async update(
    principal: AuthPrincipal,
    userId: string,
    input: UpdateUserInput,
  ) {
    if (input.roles) this.assertAssignableRoles(principal, input.roles);
    if (userId === principal.actorId && input.status === 'SUSPENDED') {
      throw new BadRequestException({
        code: 'ERR-AUTH-SELF',
        message: 'use outro administrador para suspender sua própria conta',
      });
    }
    if (
      userId === principal.actorId &&
      input.roles &&
      !input.roles.some((role) => role === 'ADMO' || role === 'ADMP')
    ) {
      throw new BadRequestException({
        code: 'ERR-AUTH-SELF',
        message: 'sua conta precisa manter um perfil administrativo',
      });
    }

    return this.transaction(async (client) => {
      const exists = await client.query(
        `SELECT 1 FROM core.app_user
          WHERE id = $1::uuid AND organization_id = $2::uuid`,
        [userId, principal.organizationId],
      );
      if (exists.rowCount === 0) {
        throw new NotFoundException({
          code: 'ERR-AUTH-USER-NOT-FOUND',
          message: 'pessoa não encontrada nesta organização',
        });
      }

      if (input.name !== undefined || input.email !== undefined ||
          input.status !== undefined) {
        try {
          await client.query(
            `UPDATE core.app_user
                SET name = COALESCE($3, name),
                    email = COALESCE($4, email),
                    oidc_subject = COALESCE($4, oidc_subject),
                    status = COALESCE($5, status),
                    revoked_at = CASE
                      WHEN $5 = 'SUSPENDED' THEN now()
                      WHEN $5 = 'ACTIVE' THEN NULL
                      ELSE revoked_at
                    END
              WHERE id = $1::uuid AND organization_id = $2::uuid`,
            [
              userId,
              principal.organizationId,
              input.name?.trim(),
              input.email?.toLowerCase(),
              input.status,
            ],
          );
        } catch (error) {
          if (isUniqueViolation(error)) {
            throw new ConflictException({
              code: 'ERR-AUTH-USER-EXISTS',
              message: 'já existe uma pessoa com este e-mail',
            });
          }
          throw error;
        }
      }

      if (input.roles !== undefined) {
        await client.query(
          `UPDATE core.user_role_binding
              SET valid_to = now()
            WHERE user_id = $1::uuid AND organization_id = $2::uuid
              AND valid_from <= now()
              AND (valid_to IS NULL OR valid_to > now())
              AND NOT (role_code = ANY($3::text[]))`,
          [userId, principal.organizationId, input.roles],
        );
        await this.addRoles(
          client,
          userId,
          principal.organizationId,
          input.roles,
        );
      }

      await this.audit(client, principal, 'USER_ACCESS_UPDATED', userId, input);
      return this.user(client, principal.organizationId, userId);
    });
  }

  private async addRoles(
    client: PoolClient,
    userId: string,
    organizationId: string,
    roles: string[],
  ) {
    for (const role of roles) {
      await client.query(
        `INSERT INTO core.user_role_binding
           (user_id, organization_id, role_code, valid_from)
         SELECT $1::uuid, $2::uuid, $3, now()
          WHERE NOT EXISTS (
            SELECT 1 FROM core.user_role_binding
             WHERE user_id = $1::uuid AND organization_id = $2::uuid
               AND role_code = $3 AND valid_from <= now()
               AND (valid_to IS NULL OR valid_to > now())
          )`,
        [userId, organizationId, role],
      );
    }
  }

  private assertAssignableRoles(principal: AuthPrincipal, roles: string[]) {
    if (roles.includes('ADMP') && !principal.roles.includes('ADMP')) {
      throw new ForbiddenException({
        code: 'ERR-AUTH-ROLE-SCOPE',
        message: 'somente outro administrador da plataforma concede ADMP',
      });
    }
  }

  private async user(client: PoolClient, organizationId: string, userId: string) {
    const { rows } = await client.query(
      `SELECT u.id, u.name, u.email, u.status,
              u.professional_credential AS "professionalCredential",
              u.created_at AS "createdAt",
              COALESCE(array_agg(b.role_code ORDER BY b.role_code)
                FILTER (WHERE b.role_code IS NOT NULL AND
                  b.valid_from <= now() AND
                  (b.valid_to IS NULL OR b.valid_to > now())), '{}') AS roles
         FROM core.app_user u
         LEFT JOIN core.user_role_binding b
           ON b.user_id = u.id AND b.organization_id = u.organization_id
        WHERE u.id = $1::uuid AND u.organization_id = $2::uuid
        GROUP BY u.id`,
      [userId, organizationId],
    );
    return rows[0];
  }

  private async audit(
    client: PoolClient,
    principal: AuthPrincipal,
    action: string,
    targetId: string,
    detail: object,
  ) {
    await client.query(
      `INSERT INTO core.audit_log
         (id, actor_id, organization_id, action, target_type, target_id, detail)
       VALUES ($1::uuid, $2::uuid, $3::uuid, $4, 'USER', $5, $6::jsonb)`,
      [
        uuidv7(),
        principal.actorId,
        principal.organizationId,
        action,
        targetId,
        JSON.stringify(detail),
      ],
    );
  }

  private async transaction<T>(work: (client: PoolClient) => Promise<T>) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await work(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

function isUniqueViolation(error: unknown): error is { code: string } {
  return typeof error === 'object' && error !== null &&
    'code' in error && error.code === '23505';
}
