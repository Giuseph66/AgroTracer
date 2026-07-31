import { Global, Module, OnApplicationShutdown } from '@nestjs/common';
import { Pool } from 'pg';

export const PG_POOL = Symbol('PG_POOL');

@Global()
@Module({
  providers: [
    {
      provide: PG_POOL,
      useFactory: () =>
        new Pool({
          host: process.env.PGHOST ?? 'localhost',
          port: Number(process.env.PGPORT ?? 5433),
          user: process.env.PGUSER ?? 'traceagro_app',
          password: process.env.PGPASSWORD ?? 'traceagro_app_dev',
          database: process.env.PGDATABASE ?? 'traceagro',
          max: Number(process.env.PGPOOL_MAX ?? 10),
        }),
    },
  ],
  exports: [PG_POOL],
})
export class DatabaseModule implements OnApplicationShutdown {
  constructor() {}

  async onApplicationShutdown() {
    // O pool é fechado pelo Nest ao destruir o provider; nada a fazer aqui.
  }
}
