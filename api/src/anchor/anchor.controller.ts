import {
  Controller,
  Get,
  Inject,
  NotFoundException,
  Param,
  Query,
  Req,
} from '@nestjs/common';
import { Pool } from 'pg';

import { AuthPrincipal } from '../auth/auth.types';
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

  /** Cobertura por animal: eventos da API versus âncoras da Fabric atual. */
  @Get('animals')
  async animals(@Req() request: { user?: AuthPrincipal }) {
    const propertyId = request.user?.propertyId;
    if (!propertyId) return { data: [], summary: emptyAnimalCoverage() };

    const expected = this.expectedOrgs();
    const expectedJson = JSON.stringify(
      expected.length > 0 ? expected : ['__fabric_not_configured__'],
    );
    const { rows } = await this.pool.query(
      `SELECT a.id AS "animalId", a.official_animal_id AS "officialAnimalId",
              visual.visual_tag_number AS "visualTagNumber",
              count(e.id)::int AS "eventCount",
              count(e.id) FILTER (WHERE e.event_type = 'REGISTER_ANIMAL')::int
                AS "registrationEventCount",
              count(e.id) FILTER (
                WHERE ba.status = 'CONFIRMED'
                  AND ba.endorsing_orgs @> $2::jsonb
              )::int AS "currentFabricEventCount",
              count(e.id) FILTER (
                WHERE e.event_type = 'REGISTER_ANIMAL'
                  AND ba.status = 'CONFIRMED'
                  AND ba.endorsing_orgs @> $2::jsonb
              )::int AS "currentFabricRegistrationCount",
              (array_agg(e.event_type ORDER BY e.occurred_at DESC)
                FILTER (WHERE e.id IS NOT NULL))[1] AS "lastEventType",
              max(e.occurred_at) AS "lastEventAt"
         FROM core.animal a
         JOIN read_model.animal_state s ON s.animal_id = a.id
         LEFT JOIN core.animal_identifier visual
                ON visual.animal_id = a.id AND visual.active
               AND visual.identifier_type = 'VISUAL'
         LEFT JOIN core.event e ON e.animal_id = a.id
         LEFT JOIN core.blockchain_anchor ba
                ON ba.subject_id = e.id AND ba.subject_type = 'EVENT'
        WHERE s.current_property_id = $1
        GROUP BY a.id, a.official_animal_id, visual.visual_tag_number
        ORDER BY visual.visual_tag_number NULLS LAST, a.id`,
      [propertyId, expectedJson],
    );
    const data = rows.map((row) => ({
      ...row,
      registrationStatus: registrationStatus(row),
    }));
    return {
      data,
      summary: {
        animals: data.length,
        withCurrentFabricEvent: data.filter(
          (animal) => animal.currentFabricEventCount > 0,
        ).length,
        registeredOnCurrentFabric: data.filter(
          (animal) => animal.registrationStatus === 'CURRENT_FABRIC',
        ).length,
        notRegisteredOnCurrentFabric: data.filter(
          (animal) => animal.registrationStatus !== 'CURRENT_FABRIC',
        ).length,
      },
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

type AnimalCoverageRow = {
  registrationEventCount: number;
  currentFabricRegistrationCount: number;
};

function registrationStatus(
  row: AnimalCoverageRow,
): 'CURRENT_FABRIC' | 'OTHER_OR_SIMULATED' | 'NO_REGISTER_EVENT' {
  if (row.currentFabricRegistrationCount > 0) return 'CURRENT_FABRIC';
  if (row.registrationEventCount > 0) return 'OTHER_OR_SIMULATED';
  return 'NO_REGISTER_EVENT';
}

function emptyAnimalCoverage() {
  return {
    animals: 0,
    withCurrentFabricEvent: 0,
    registeredOnCurrentFabric: 0,
    notRegisteredOnCurrentFabric: 0,
  };
}
