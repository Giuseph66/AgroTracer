import { Inject, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';

import { PG_POOL } from '../database/database.module';
import { EventEnvelopeDto, EventVerdict } from './event.dto';

export type DeviceRow = {
  id: string;
  status: string;
  public_key: string | null;
  organization_id: string;
  last_sequence: string;
};

export type StoredVerdict = EventVerdict & { conflictId?: string };

@Injectable()
export class EventsRepository {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  withTransaction<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
    return this.pool.connect().then(async (client) => {
      try {
        await client.query('BEGIN');
        const out = await fn(client);
        await client.query('COMMIT');
        return out;
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    });
  }

  async findDevice(deviceId: string): Promise<DeviceRow | undefined> {
    const { rows } = await this.pool.query<DeviceRow>(
      `SELECT id, status, public_key, organization_id, last_sequence
         FROM core.device WHERE id = $1`,
      [deviceId],
    );
    return rows[0];
  }

  /** R23: veredicto já emitido para este eventId, se houver. */
  async findVerdict(eventId: string): Promise<StoredVerdict | undefined> {
    const { rows } = await this.pool.query(
      `SELECT event_id, status, code, detail, conflict_id
         FROM core.ingestion_verdict WHERE event_id = $1`,
      [eventId],
    );
    const r = rows[0];
    if (!r) return undefined;
    return {
      eventId: r.event_id,
      status: r.status,
      code: r.code ?? undefined,
      detail: r.detail ?? undefined,
      conflictId: r.conflict_id ?? undefined,
    };
  }

  /** R22: dono atual de um (deviceId, deviceSequence). */
  async findEventIdBySequence(
    deviceId: string,
    sequence: number,
  ): Promise<string | undefined> {
    const { rows } = await this.pool.query(
      `SELECT event_id FROM core.ingestion_verdict
        WHERE device_id = $1 AND device_sequence = $2 AND status = 'ACCEPTED'`,
      [deviceId, sequence],
    );
    return rows[0]?.event_id;
  }

  async saveVerdict(
    client: PoolClient,
    e: EventEnvelopeDto,
    v: StoredVerdict,
  ): Promise<void> {
    await client.query(
      `INSERT INTO core.ingestion_verdict
         (event_id, status, code, detail, device_id, device_sequence, conflict_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (event_id) DO NOTHING`,
      [
        e.eventId,
        v.status,
        v.code ?? null,
        v.detail ?? null,
        e.deviceId,
        e.deviceSequence,
        v.conflictId ?? null,
      ],
    );
  }

  async animalExists(animalId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `SELECT 1 FROM core.animal WHERE id = $1`,
      [animalId],
    );
    return rowCount === 1;
  }

  /** Estado derivado do animal, para as regras R13/R14/R18. */
  async animalState(animalId: string): Promise<
    | {
        lifecycle_status: string;
        quarantined: boolean;
        withdrawal_until: Date | null;
        last_weight_kg: string | null;
        last_weight_at: Date | null;
      }
    | undefined
  > {
    const { rows } = await this.pool.query(
      `SELECT lifecycle_status, quarantined, withdrawal_until,
              last_weight_kg, last_weight_at
         FROM read_model.animal_state WHERE animal_id = $1`,
      [animalId],
    );
    return rows[0];
  }

  /** R3: animal que detém este RFID ativo, se houver. */
  async animalHoldingRfid(rfid: string): Promise<string | undefined> {
    const { rows } = await this.pool.query(
      `SELECT animal_id FROM core.animal_identifier
        WHERE rfid_code = $1 AND active AND identifier_type = 'RFID'`,
      [rfid],
    );
    return rows[0]?.animal_id;
  }

  async vetProduct(code: string): Promise<{
    code: string;
    withdrawal_slaughter_days: number;
    active: boolean;
  } | undefined> {
    const { rows } = await this.pool.query(
      `SELECT code, withdrawal_slaughter_days, active
         FROM core.vet_product WHERE code = $1`,
      [code],
    );
    return rows[0];
  }

  async paddock(id: string): Promise<{ id: string; property_id: string } | undefined> {
    const { rows } = await this.pool.query(
      `SELECT id, property_id FROM core.paddock WHERE id = $1 AND active`,
      [id],
    );
    return rows[0];
  }

  async resolveAnimalByRfid(rfid: string): Promise<string | undefined> {
    return this.animalHoldingRfid(rfid);
  }

  async insertEvent(
    client: PoolClient,
    e: EventEnvelopeDto,
    opts: { clockSkewMs?: number; timeSuspect: boolean },
  ): Promise<void> {
    await client.query(
      `INSERT INTO core.event
         (id, schema_version, event_type, subject_type, animal_id, subject_id,
          occurred_at, recorded_at, organization_id, actor_id, device_id,
          device_sequence, app_version, property_id, payload_hash, signature,
          source_system, correction_of, sync_status, clock_skew_ms, time_suspect)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,
               'PENDING_BLOCKCHAIN',$19,$20)`,
      [
        e.eventId,
        e.schemaVersion,
        e.eventType,
        e.subjectType,
        e.animalId ?? (e.eventType === 'REGISTER_ANIMAL' ? e.subjectId : null),
        e.subjectId,
        e.occurredAt,
        e.recordedAt,
        e.organizationId,
        e.actorId,
        e.deviceId,
        e.deviceSequence,
        e.appVersion,
        e.propertyId ?? null,
        e.payloadHash,
        e.signature,
        e.sourceSystem,
        e.correctionOf ?? null,
        opts.clockSkewMs ?? null,
        opts.timeSuspect,
      ],
    );

    await client.query(
      `INSERT INTO core.event_payload (event_id, schema_version, canonical_json)
       VALUES ($1,$2,$3)`,
      [e.eventId, e.schemaVersion, JSON.stringify(e.payload)],
    );

    // Toda escrita aceita nasce com âncora pendente (Doc 8 §5).
    await client.query(
      `INSERT INTO core.blockchain_anchor
         (id, subject_type, subject_id, payload_hash, channel, chaincode_fn, status)
       VALUES (gen_random_uuid(), 'EVENT', $1, $2, 'traceagro-main', $3, 'PENDING')`,
      [e.eventId, e.payloadHash, chaincodeFnFor(e.eventType)],
    );

    await client.query(
      `UPDATE core.device SET last_sequence = GREATEST(last_sequence, $2)
        WHERE id = $1`,
      [e.deviceId, e.deviceSequence],
    );
  }

  async insertAnimal(client: PoolClient, e: EventEnvelopeDto): Promise<void> {
    const birthType = str(e.payload['birthType']) ?? 'IMPORTED_RECORD';
    const sex = str(e.payload['sex']);
    if (!sex) throw new Error('REGISTER_ANIMAL sem sexo');
    const birthDate = str(e.payload['birthDate']) ?? null;
    const animalId = e.animalId ?? e.subjectId;

    await client.query(
      `INSERT INTO core.animal
         (id, official_animal_id, species_code, breed_code, sex, birth_date,
          birth_type, dam_id, sire_ref)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [
        animalId,
        str(e.payload['officialAnimalId']) ?? null,
        str(e.payload['speciesCode']) ?? 'BOVINE',
        str(e.payload['breedCode']) ?? null,
        sex,
        birthDate,
        birthType,
        str(e.payload['damId']) ?? null,
        str(e.payload['sireRef']) ?? null,
      ],
    );

    await client.query(
      `INSERT INTO read_model.animal_state
         (animal_id, current_property_id, current_herd_lot, event_count, updated_at)
       VALUES ($1,$2,$3,1,now())`,
      [animalId, e.propertyId ?? null, str(e.payload['herdLot']) ?? null],
    );

    const identifiers = Array.isArray(e.payload['initialIdentifiers'])
      ? (e.payload['initialIdentifiers'] as unknown[])
      : [];
    for (const raw of identifiers) {
      if (!raw || typeof raw !== 'object') continue;
      const item = raw as Record<string, unknown>;
      const type = str(item['type']);
      if (!type) continue;
      await client.query(
        `INSERT INTO core.animal_identifier
           (id, animal_id, identifier_type, rfid_code, visual_tag_number,
            official_number, active, linked_at, link_event_id)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,true,$6,$7)`,
        [
          animalId,
          type,
          str(item['rfidCode']) ?? null,
          str(item['visualTagNumber']) ?? null,
          str(item['officialNumber']) ?? null,
          e.occurredAt,
          e.eventId,
        ],
      );
    }
  }

  async insertConflict(
    client: PoolClient,
    e: EventEnvelopeDto,
    conflictType: string,
    detail: Record<string, unknown>,
    syncJobId?: string,
  ): Promise<string> {
    const { rows } = await client.query(
      `INSERT INTO core.sync_conflict
         (id, sync_job_id, event_id, conflict_type, detail)
       VALUES (gen_random_uuid(), $1, $2, $3, $4)
       RETURNING id`,
      [syncJobId ?? null, e.eventId, conflictType, JSON.stringify(detail)],
    );
    return rows[0].id;
  }

  async openConflicts(): Promise<unknown[]> {
    const { rows } = await this.pool.query(
      `SELECT c.id, c.event_id, c.conflict_type, c.detail, c.created_at,
              v.code
         FROM core.sync_conflict c
         LEFT JOIN core.ingestion_verdict v ON v.event_id = c.event_id
        WHERE c.resolution_status = 'OPEN'
        ORDER BY c.created_at DESC`,
    );
    return rows;
  }

  async createSyncJob(
    deviceId: string,
    eventCount: number,
    clockSkewMs?: number,
  ): Promise<string> {
    const { rows } = await this.pool.query(
      `INSERT INTO core.sync_job
         (id, device_id, direction, event_count, clock_skew_ms, status)
       VALUES (gen_random_uuid(), $1, 'PUSH', $2, $3, 'PROCESSING')
       RETURNING id`,
      [deviceId, eventCount, clockSkewMs ?? null],
    );
    return rows[0].id;
  }

  async closeSyncJob(
    id: string,
    counts: { accepted: number; rejected: number; conflicts: number },
  ): Promise<void> {
    await this.pool.query(
      `UPDATE core.sync_job
          SET accepted_count = $2::int, rejected_count = $3::int,
              conflict_count = $4::int,
              status = CASE WHEN $3::int + $4::int = 0
                            THEN 'COMPLETED' ELSE 'PARTIAL' END,
              finished_at = now()
        WHERE id = $1`,
      [id, counts.accepted, counts.rejected, counts.conflicts],
    );
  }

  // ------------------------------------------------------------- projeções

  async applyWeighing(
    client: PoolClient,
    e: EventEnvelopeDto,
    weightKg: number,
    source: string,
  ): Promise<void> {
    await client.query(
      `INSERT INTO read_model.weight_record
         (event_id, animal_id, weight_kg, weight_source, occurred_at)
       VALUES ($1,$2,$3,$4,$5)`,
      [e.eventId, e.animalId, weightKg, source, e.occurredAt],
    );

    // R9/R11: peso atual e GMD derivam das pesagens válidas, calculados aqui
    // e não informados pelo cliente.
    await client.query(
      `WITH valid AS (
         SELECT weight_kg, occurred_at
           FROM read_model.weight_record
          WHERE animal_id = $1 AND valid
          ORDER BY occurred_at DESC
          LIMIT 2
       ), latest AS (SELECT * FROM valid LIMIT 1),
          prev AS (SELECT * FROM valid OFFSET 1 LIMIT 1)
       INSERT INTO read_model.animal_state
         (animal_id, last_weight_kg, last_weight_at, gmd_kg_day, event_count,
          updated_at)
       SELECT $1, latest.weight_kg, latest.occurred_at,
              CASE
                -- GMD só tem significado entre pesagens separadas por pelo
                -- menos um dia. Duas pesagens no mesmo dia (repetição no brete,
                -- conferência) não produzem ganho médio diário: mantém o
                -- anterior em vez de inventar um número.
                WHEN prev.occurred_at IS NULL THEN NULL
                WHEN EXTRACT(EPOCH FROM (latest.occurred_at - prev.occurred_at))
                     < 86400 THEN NULL
                ELSE ROUND(((latest.weight_kg - prev.weight_kg) /
                     (EXTRACT(EPOCH FROM (latest.occurred_at - prev.occurred_at))
                      / 86400.0))::numeric, 3)
              END,
              1, now()
         FROM latest LEFT JOIN prev ON true
       ON CONFLICT (animal_id) DO UPDATE
         SET last_weight_kg = EXCLUDED.last_weight_kg,
             last_weight_at = EXCLUDED.last_weight_at,
             gmd_kg_day     = COALESCE(EXCLUDED.gmd_kg_day,
                                       read_model.animal_state.gmd_kg_day),
             event_count    = read_model.animal_state.event_count + 1,
             updated_at     = now()`,
      [e.animalId],
    );
  }

  async applyHealthEvent(
    client: PoolClient,
    e: EventEnvelopeDto,
    productRef: string | null,
    dosage: string | null,
    withdrawalUntil: string | null,
    batchId: string | null,
  ): Promise<void> {
    let derivedWithdrawal = withdrawalUntil;
    if (!derivedWithdrawal && productRef) {
      const product = await client.query(
        `SELECT withdrawal_slaughter_days FROM core.vet_product
          WHERE code = $1 AND active`,
        [productRef],
      );
      const days = Number(product.rows[0]?.withdrawal_slaughter_days ?? 0);
      if (days > 0) {
        derivedWithdrawal = new Date(
          new Date(e.occurredAt).getTime() + days * 86400000,
        ).toISOString();
      }
    }

    await client.query(
      `INSERT INTO read_model.health_record
         (event_id, animal_id, record_type, product_ref, dosage,
          withdrawal_until, vet_user_id, occurred_at, batch_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [
        e.eventId,
        e.animalId,
        e.eventType,
        productRef,
        dosage,
        derivedWithdrawal,
        e.actorId,
        e.occurredAt,
        batchId,
      ],
    );

    if (derivedWithdrawal) {
      await client.query(
        `INSERT INTO read_model.animal_state (animal_id, withdrawal_until)
         VALUES ($1,$2)
         ON CONFLICT (animal_id) DO UPDATE
           SET withdrawal_until = GREATEST(
                 COALESCE(read_model.animal_state.withdrawal_until, $2::timestamptz),
                 $2::timestamptz),
               updated_at = now()`,
        [e.animalId, derivedWithdrawal],
      );
    }
  }

  async applyReidentification(
    client: PoolClient,
    e: EventEnvelopeDto,
    payload: Record<string, unknown>,
  ): Promise<void> {
    const oldId = str(payload['oldIdentifierId']);
    const next = payload['newIdentifier'];
    if (!oldId || !next || typeof next !== 'object') {
      throw new Error('REIDENTIFICATION incompleto');
    }
    const item = next as Record<string, unknown>;
    await client.query(
      `UPDATE core.animal_identifier
          SET active = false, unlinked_at = $2, unlink_reason = $3,
              unlink_event_id = $4
        WHERE id = $1 AND animal_id = $5 AND active`,
      [oldId, e.occurredAt, str(payload['reason']) ?? 'ERROR', e.eventId, e.animalId],
    );
    await client.query(
      `INSERT INTO core.animal_identifier
         (id, animal_id, identifier_type, rfid_code, visual_tag_number,
          official_number, active, linked_at, link_event_id)
       VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,true,$6,$7)`,
      [
        e.animalId,
        str(item['type']) ?? 'RFID',
        str(item['rfidCode']) ?? null,
        str(item['visualTagNumber']) ?? null,
        str(item['officialNumber']) ?? null,
        e.occurredAt,
        e.eventId,
      ],
    );
  }

  async applyPaddockChange(
    client: PoolClient,
    e: EventEnvelopeDto,
    paddockId: string,
  ): Promise<void> {
    await client.query(
      `UPDATE read_model.animal_state
          SET current_paddock_id = $2, updated_at = now()
        WHERE animal_id = $1`,
      [e.animalId, paddockId],
    );
  }

  async applyLotChange(
    client: PoolClient,
    e: EventEnvelopeDto,
    lot: string,
  ): Promise<void> {
    await client.query(
      `UPDATE read_model.animal_state
          SET current_herd_lot = $2, updated_at = now()
        WHERE animal_id = $1`,
      [e.animalId, lot],
    );
  }

  async applyQuarantine(
    client: PoolClient,
    e: EventEnvelopeDto,
    quarantined: boolean,
  ): Promise<void> {
    await client.query(
      `UPDATE read_model.animal_state
          SET quarantined = $2,
              lifecycle_status = CASE WHEN $2 THEN 'QUARANTINED' ELSE 'ACTIVE' END,
              updated_at = now()
        WHERE animal_id = $1`,
      [e.animalId, quarantined],
    );
  }

  async applyLifecycle(
    client: PoolClient,
    e: EventEnvelopeDto,
    status: string,
  ): Promise<void> {
    await client.query(
      `UPDATE read_model.animal_state
          SET lifecycle_status = $2, updated_at = now()
        WHERE animal_id = $1`,
      [e.animalId, status],
    );
  }

  async applyOffspringLink(
    client: PoolClient,
    e: EventEnvelopeDto,
    damId: string,
  ): Promise<void> {
    await client.query(
      `UPDATE core.animal SET dam_id = $2 WHERE id = $1 AND dam_id IS NULL`,
      [e.animalId, damId],
    );
  }

  async applyPropertyExit(client: PoolClient, e: EventEnvelopeDto): Promise<void> {
    await client.query(
      `UPDATE read_model.animal_state
          SET lifecycle_status = 'IN_TRANSIT', updated_at = now()
        WHERE animal_id = $1`,
      [e.animalId],
    );
  }

  async applyPropertyEntry(
    client: PoolClient,
    e: EventEnvelopeDto,
    propertyId: string,
  ): Promise<void> {
    await client.query(
      `UPDATE read_model.animal_state
          SET lifecycle_status = 'ACTIVE', current_property_id = $2,
              updated_at = now()
        WHERE animal_id = $1`,
      [e.animalId, propertyId],
    );
  }

  async applyShipmentDispatched(
    client: PoolClient,
    e: EventEnvelopeDto,
  ): Promise<void> {
    const shipmentId = str(e.payload['shipmentId']) ?? e.subjectId;
    const animalIds = stringArray(e.payload['animalIds']);
    await client.query(
      `INSERT INTO core.shipment
         (id, origin_property_id, destination_property_id, purpose,
          carrier_org_id, vehicle_plate, gta_number, gta_uf, expected_arrival,
          status, dispatched_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'DISPATCHED',$10)
       ON CONFLICT (id) DO UPDATE SET status = 'DISPATCHED', dispatched_at = EXCLUDED.dispatched_at`,
      [
        shipmentId,
        e.propertyId,
        str(e.payload['destinationPropertyId']) ?? null,
        str(e.payload['purpose']) ?? 'OTHER',
        str(e.payload['carrierOrgId']) ?? null,
        str(e.payload['vehiclePlate']) ?? null,
        str(e.payload['gtaNumber']) ?? null,
        str(e.payload['gtaUf']) ?? null,
        str(e.payload['expectedArrival']) ?? null,
        e.occurredAt,
      ],
    );
    for (const animalId of animalIds) {
      await client.query(
        `INSERT INTO core.shipment_animal (shipment_id, animal_id)
         VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [shipmentId, animalId],
      );
      await client.query(
        `UPDATE read_model.animal_state
            SET lifecycle_status = 'IN_TRANSIT', updated_at = now()
          WHERE animal_id = $1`,
        [animalId],
      );
    }
  }

  async applyShipmentReceived(
    client: PoolClient,
    e: EventEnvelopeDto,
  ): Promise<void> {
    const shipmentId = str(e.payload['shipmentId']) ?? e.subjectId;
    const readIds = stringArray(e.payload['readAnimalIds']);
    const shipment = await client.query(
      `SELECT destination_property_id FROM core.shipment WHERE id = $1`,
      [shipmentId],
    );
    const destination = shipment.rows[0]?.destination_property_id;
    if (!destination) throw new Error('embarque sem propriedade de destino');

    await client.query(
      `UPDATE core.shipment SET status = $2, received_at = $3 WHERE id = $1`,
      [shipmentId, readIds.length ? 'RECEIVED' : 'RECEIVED_WITH_DISCREPANCY', e.occurredAt],
    );
    await client.query(
      `UPDATE core.shipment_animal
          SET received = (animal_id = ANY($2::uuid[])),
              discrepancy = CASE WHEN animal_id = ANY($2::uuid[]) THEN NULL ELSE 'MISSING' END
        WHERE shipment_id = $1`,
      [shipmentId, readIds],
    );
    for (const animalId of readIds) {
      await this.applyPropertyEntry(client, {
        ...e,
        animalId,
      } as EventEnvelopeDto, destination);
    }
  }

  async applyIdentifierLink(
    client: PoolClient,
    e: EventEnvelopeDto,
    rfid: string | null,
    visual: string | null,
  ): Promise<void> {
    if (rfid) {
      await client.query(
        `INSERT INTO core.animal_identifier
           (id, animal_id, identifier_type, rfid_code, active, linked_at,
            link_event_id)
         VALUES (gen_random_uuid(), $1, 'RFID', $2, true, $3, $4)`,
        [e.animalId, rfid, e.occurredAt, e.eventId],
      );
    }
    if (visual) {
      await client.query(
        `INSERT INTO core.animal_identifier
           (id, animal_id, identifier_type, visual_tag_number, active, linked_at,
            link_event_id)
         VALUES (gen_random_uuid(), $1, 'VISUAL', $2, true, $3, $4)`,
        [e.animalId, visual, e.occurredAt, e.eventId],
      );
    }
  }

  // ------------------------------------------------------------- consultas

  async timeline(animalId: string): Promise<unknown[]> {
    const { rows } = await this.pool.query(
      `SELECT e.id AS "eventId", e.event_type AS "eventType",
              e.occurred_at AS "occurredAt", e.recorded_at AS "recordedAt",
              e.sync_status AS "syncStatus", e.blockchain_tx_id AS "blockchainTxId",
              e.payload_hash AS "payloadHash", e.corrected,
              e.correction_of AS "correctionOf",
              u.name AS "actorName", p.canonical_json AS payload,
              a.status AS "anchorStatus"
         FROM core.event e
         JOIN core.app_user u ON u.id = e.actor_id
         LEFT JOIN core.event_payload p ON p.event_id = e.id
         LEFT JOIN core.blockchain_anchor a
                ON a.subject_id = e.id AND a.subject_type = 'EVENT'
        WHERE e.animal_id = $1
        ORDER BY e.occurred_at DESC`,
      [animalId],
    );
    return rows;
  }

  async animalsByProperty(propertyId: string): Promise<unknown[]> {
    const { rows } = await this.pool.query(
      `SELECT a.id AS "animalId", a.official_animal_id AS "officialAnimalId",
              a.sex, a.breed_code AS "breedCode", a.birth_date AS "birthDate",
              rfid.rfid_code AS "rfidCode",
              visual.visual_tag_number AS "visualTagNumber",
              s.lifecycle_status AS "lifecycleStatus",
              s.current_herd_lot AS "herdLot",
              s.last_weight_kg AS "lastWeightKg", s.gmd_kg_day AS "gmdKgDay",
              s.withdrawal_until AS "withdrawalUntil"
         FROM core.animal a
         LEFT JOIN read_model.animal_state s ON s.animal_id = a.id
         LEFT JOIN core.animal_identifier rfid
                ON rfid.animal_id = a.id AND rfid.active
               AND rfid.identifier_type = 'RFID'
         LEFT JOIN core.animal_identifier visual
                ON visual.animal_id = a.id AND visual.active
               AND visual.identifier_type = 'VISUAL'
        WHERE s.current_property_id = $1 OR $1 IS NULL
        ORDER BY visual.visual_tag_number`,
      [propertyId],
    );
    return rows;
  }
}

/** Mapa evento → função de chaincode (Doc 10 §6). */
export function chaincodeFnFor(eventType: string): string {
  switch (eventType) {
    case 'REGISTER_ANIMAL':
      return 'RegisterAnimal';
    case 'LINK_IDENTIFIER':
      return 'LinkPhysicalIdentifier';
    case 'REIDENTIFICATION':
      return 'ReidentifyAnimal';
    case 'VACCINATION':
    case 'TREATMENT':
      return 'RecordHealthEvent';
    case 'SHIPMENT_DISPATCHED':
    case 'SHIPMENT_RECEIVED':
      return 'RecordMovement';
    case 'CORRECTED':
      return 'CorrectEvent';
    default:
      return 'RecordEvent';
  }
}

function str(v: unknown): string | undefined {
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

function stringArray(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((item): item is string => typeof item === 'string') : [];
}
