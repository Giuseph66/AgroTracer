import { Inject, Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';
import { FabricGateway } from './fabric.gateway';

const BATCH_SIZE = 25;
const MAX_ATTEMPTS = 24;
/** Após isso, uma submissão sem confirmação é considerada travada. */
const STALE_SUBMITTED_MS = 30_000;

/**
 * Leva eventos aceitos de PENDING_BLOCKCHAIN a CONFIRMED_ON_BLOCKCHAIN
 * (Doc 8 §5). A ancoragem é assíncrona por definição: falha na rede Fabric
 * nunca desfaz nem bloqueia o evento já aceito (R30) — apenas mantém a âncora
 * pendente para nova tentativa.
 */
@Injectable()
export class AnchorWorker {
  private readonly log = new Logger(AnchorWorker.name);
  private running = false;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly fabric: FabricGateway,
  ) {}

  @Interval(3000)
  async tick(): Promise<void> {
    if (this.running) return; // sem sobreposição de ciclos
    this.running = true;
    try {
      await this.processPending();
    } catch (err) {
      this.log.error('ciclo de ancoragem falhou', err as Error);
    } finally {
      this.running = false;
    }
  }

  async processPending(): Promise<number> {
    // Duas fontes de trabalho:
    //  - PENDING: âncoras novas;
    //  - SUBMITTED parado há mais de STALE_SUBMITTED_MS: o processo morreu
    //    entre submeter e confirmar. Sem isso a âncora fica órfã para sempre.
    //    Reprocessar é seguro porque o registro-âncora é idempotente na rede
    //    (mesmo eventId ⇒ mesma chave de estado no chaincode).
    // SKIP LOCKED permite várias réplicas do worker sem disputar a mesma linha.
    const { rows } = await this.pool.query(
      `SELECT id, subject_id, payload_hash, channel, chaincode_fn, attempt
         FROM core.blockchain_anchor
        WHERE attempt < $2
          AND (status = 'PENDING'
               OR (status = 'SUBMITTED'
                   AND submitted_at < now() - ($3 || ' milliseconds')::interval))
        ORDER BY created_at
        LIMIT $1
        FOR UPDATE SKIP LOCKED`,
      [BATCH_SIZE, MAX_ATTEMPTS, STALE_SUBMITTED_MS],
    );

    let confirmed = 0;
    for (const row of rows) {
      try {
        await this.pool.query(
          `UPDATE core.blockchain_anchor
              SET status = 'SUBMITTED', attempt = attempt + 1, submitted_at = now()
            WHERE id = $1`,
          [row.id],
        );

        const result = await this.fabric.submit({
          chaincodeFn: row.chaincode_fn,
          channel: row.channel,
          eventId: row.subject_id,
          payloadHash: row.payload_hash,
        });

        await this.pool.query(
          `UPDATE core.blockchain_anchor
              SET status = 'CONFIRMED', tx_id = $2, block_number = $3,
                  endorsing_orgs = $4, confirmed_at = now(), last_error = NULL
            WHERE id = $1`,
          [row.id, result.txId, result.blockNumber, JSON.stringify(result.endorsingOrgs)],
        );

        // core.event é append-only para a aplicação; a única transição
        // permitida passa por esta função (migração 004).
        await this.pool.query(`SELECT core.confirm_event_anchor($1, $2)`, [
          row.subject_id,
          result.txId,
        ]);

        confirmed++;
      } catch (err) {
        const message = (err as Error).message;
        // Volta a PENDING: o próximo ciclo tenta de novo até MAX_ATTEMPTS.
        await this.pool.query(
          `UPDATE core.blockchain_anchor
              SET status = CASE WHEN attempt >= $3 THEN 'FAILED' ELSE 'PENDING' END,
                  last_error = $2
            WHERE id = $1`,
          [row.id, message, MAX_ATTEMPTS],
        );
        this.log.warn(`âncora ${row.id} falhou: ${message}`);
      }
    }

    if (confirmed > 0) this.log.log(`${confirmed} evento(s) ancorado(s)`);
    return confirmed;
  }
}
