import { SetMetadata } from '@nestjs/common';

export const REQUIRED_PERMISSION_KEY = 'traceagro.required-permission';

export const RequirePermission = (permission: string) =>
  SetMetadata(REQUIRED_PERMISSION_KEY, permission);
