import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';

import { AuthController } from './auth.controller';
import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { PolicyService } from './policy.service';

@Global()
@Module({
  controllers: [AuthController],
  providers: [
    AuthService,
    PolicyService,
    AuthGuard,
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
  exports: [AuthService, PolicyService],
})
export class AuthModule {}
