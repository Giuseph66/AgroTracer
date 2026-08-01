import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AuthService } from './auth.service';
import { AuthPrincipal } from './auth.types';
import { REQUIRED_PERMISSION_KEY } from './permission.decorator';
import { PolicyService } from './policy.service';
import { IS_PUBLIC_KEY } from './public.decorator';

type RequestWithUser = { headers: { authorization?: string }; user?: AuthPrincipal };

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly auth: AuthService,
    private readonly policy: PolicyService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const header = request.headers.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token) {
      throw new UnauthorizedException('sessão necessária');
    }
    request.user = await this.auth.verifyToken(token);
    const permission = this.reflector.getAllAndOverride<string>(
      REQUIRED_PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (permission && !this.policy.allows(request.user, permission)) {
      throw new ForbiddenException({
        code: 'ERR-AUTH-403',
        message: 'seu perfil não permite esta ação',
      });
    }
    return true;
  }
}
