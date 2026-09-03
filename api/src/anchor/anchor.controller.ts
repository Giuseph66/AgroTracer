import {
  Controller,
  Get,
  Inject,
  NotFoundException,
  Param,
  Query,
} from '@nestjs/common';
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
    return { ...rows[0], network: this.networkKind(rows[0].endorsingOrgs) };
  }

  /** Painel de saúde da ancoragem — alimenta o alerta de SLA do Doc 14 §5. */
  @Get()
  async summary() {
    const [summary, confirmed] = await Promise.all([
      this.pool.query(
        `SELECT status, count(*)::int AS count
           FROM core.blockchain_anchor GROUP BY status`,
      ),
      this.currentNetworkConfirmed(),
    ]);
    return {
      data: summary.rows,
      network: {
        mode: process.env.FABRIC_MODE === 'real' ? 'real' : 'simulated',
        expectedOrgs: this.expectedOrgs(),
        confirmed,
      },
    };
  }

  /** Últimas âncoras, sem payloads de negócio, para o painel de laboratório. */
  @Get('recent')
  async recent(@Query('limit') rawLimit?: string) {
    const parsed = Number(rawLimit);
    const limit = Number.isInteger(parsed)
      ? Math.max(1, Math.min(parsed, 100))
      : 24;
    const { rows } = await this.pool.query(
      `SELECT subject_id AS "subjectId", payload_hash AS "payloadHash",
              channel, chaincode_fn AS "chaincodeFn", tx_id AS "txId",
              block_number AS "blockNumber", status, attempt,
              endorsing_orgs AS "endorsingOrgs", created_at AS "createdAt",
              submitted_at AS "submittedAt", confirmed_at AS "confirmedAt",
              last_error AS "lastError"
         FROM core.blockchain_anchor
        ORDER BY created_at DESC
        LIMIT $1`,
      [limit],
    );
    return {
      data: rows.map((row) => ({
        ...row,
        network: this.networkKind(row.endorsingOrgs),
      })),
    };
  }

  private expectedOrgs(): string[] {
    return (process.env.FABRIC_ENDORSING_ORGS ?? '')
      .split(',')
      .map((org) => org.trim())
      .filter(Boolean);
  }

  private networkKind(endorsingOrgs: unknown): 'CURRENT_FABRIC' | 'OTHER_OR_SIMULATED' {
    const expected = this.expectedOrgs();
    const received = Array.isArray(endorsingOrgs) ? endorsingOrgs : [];
    return expected.length > 0 && expected.every((org) => received.includes(org))
      ? 'CURRENT_FABRIC'
      : 'OTHER_OR_SIMULATED';
  }

  private async currentNetworkConfirmed(): Promise<number> {
    const expected = this.expectedOrgs();
    if (expected.length === 0) return 0;
    const { rows } = await this.pool.query(
      `SELECT count(*)::int AS count
         FROM core.blockchain_anchor
        WHERE status = 'CONFIRMED' AND endorsing_orgs @> $1::jsonb`,
      [JSON.stringify(expected)],
    );
    return rows[0].count;
  }
}
