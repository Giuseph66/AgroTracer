import { Controller, Get, Inject, NotFoundException, Param } from '@nestjs/common';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';

@Controller('devices')
export class DevicesController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Estado de sincronização do dispositivo.
   *
   * `lastSequence` é o que impede um aparelho reinstalado (ou um app recém
   * aberto) de recomeçar a numeração do zero e colidir com eventos que já
   * subiram — o servidor é quem sabe onde a contagem parou (Doc 8 §3).
   */
  @Get(':id/sync-state')
  async syncState(@Param('id') id: string) {
    const { rows } = await this.pool.query(
      `SELECT id, status, last_sequence
         FROM core.device WHERE id = $1`,
      [id],
    );
    const device = rows[0];
    if (!device) throw new NotFoundException();

    return {
      deviceId: device.id,
      status: device.status,
      lastSequence: Number(device.last_sequence),
    };
  }
}
