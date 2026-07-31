import { Controller, Get, Inject, NotFoundException, Param } from '@nestjs/common';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';

@Controller('anchors')
export class AnchorController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /** Prova de um evento: TxID, bloco e organizações endossantes (Doc 9 §4.8). */
  @Get(':subjectId/proof')
  async proof(@Param('subjectId') subjectId: string) {
    const { rows } = await this.pool.query(
      `SELECT id, subject_type AS "subjectType", subject_id AS "subjectId",
              payload_hash AS "payloadHash", channel, chaincode_fn AS "chaincodeFn",
              tx_id AS "txId", block_number AS "blockNumber", status,
              attempt, endorsing_orgs AS "endorsingOrgs",
              submitted_at AS "submittedAt", confirmed_at AS "confirmedAt",
              last_error AS "lastError"
         FROM core.blockchain_anchor
        WHERE subject_id = $1
        ORDER BY created_at DESC
        LIMIT 1`,
      [subjectId],
    );
    if (rows.length === 0) throw new NotFoundException();
    return rows[0];
  }

  /** Painel de saúde da ancoragem — alimenta o alerta de SLA do Doc 14 §5. */
  @Get()
  async summary() {
    const { rows } = await this.pool.query(
      `SELECT status, count(*)::int AS count
         FROM core.blockchain_anchor GROUP BY status`,
    );
    return { data: rows };
  }
}
