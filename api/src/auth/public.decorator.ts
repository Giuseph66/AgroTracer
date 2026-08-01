import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'traceagro_public';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
