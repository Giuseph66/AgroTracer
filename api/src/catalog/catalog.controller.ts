import { Controller, Get, Inject, Query } from '@nestjs/common';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';

@Controller('catalog')
export class CatalogController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  @Get('vet-products')
  async vetProducts(@Query('active') active = 'true') {
    const { rows } = await this.pool.query(
      `SELECT code, name, active_ingredient AS "activeIngredient",
              withdrawal_slaughter_days AS "withdrawalSlaughterDays",
              withdrawal_milk_days AS "withdrawalMilkDays"
         FROM core.vet_product
        WHERE active = $1::boolean
        ORDER BY name`,
      [active],
    );
    return { data: rows };
  }
}
