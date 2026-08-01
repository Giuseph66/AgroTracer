import { Controller, Get, Header, Inject, NotFoundException, Param, Query, Req } from '@nestjs/common';
import { Pool } from 'pg';

import { AuthPrincipal } from '../auth/auth.types';
import { PG_POOL } from '../database/database.module';

@Controller('reports')
export class ReportsController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  @Get('animals.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  async animalsCsv(
    @Query('propertyId') propertyId: string | undefined,
    @Req() request: { user?: AuthPrincipal },
  ) {
    const scopedProperty = request.user?.propertyId ?? propertyId ?? null;
    const { rows } = await this.pool.query(
      `SELECT visual.visual_tag_number AS visual,
              rfid.rfid_code AS rfid,
              a.official_animal_id AS official,
              a.sex, a.breed_code AS breed,
              s.lifecycle_status AS status,
              s.current_herd_lot AS lot,
              p.name AS paddock,
              s.last_weight_kg AS weight_kg,
              s.gmd_kg_day AS gmd_kg_day,
              s.withdrawal_until AS withdrawal_until
         FROM core.animal a
         JOIN read_model.animal_state s ON s.animal_id = a.id
         LEFT JOIN core.paddock p ON p.id = s.current_paddock_id
         LEFT JOIN core.animal_identifier visual
           ON visual.animal_id = a.id AND visual.active
          AND visual.identifier_type = 'VISUAL'
         LEFT JOIN core.animal_identifier rfid
           ON rfid.animal_id = a.id AND rfid.active
          AND rfid.identifier_type = 'RFID'
        WHERE $1::uuid IS NULL OR s.current_property_id = $1
        ORDER BY visual.visual_tag_number, a.id`,
      [scopedProperty],
    );
    const header = [
      'visual',
      'rfid',
      'official',
      'sex',
      'breed',
      'status',
      'lot',
      'paddock',
      'weight_kg',
      'gmd_kg_day',
      'withdrawal_until',
    ];
    return [header, ...rows.map((row) => header.map((key) => row[key]))]
      .map((line) => line.map(csv).join(','))
      .join('\n');
  }

  @Get('animals/:animalId.json')
  async animalDossier(
    @Param('animalId') animalId: string,
    @Req() request: { user?: AuthPrincipal },
  ) {
    return this.dossier(animalId, request.user?.propertyId);
  }

  @Get('animals/:animalId.pdf')
  @Header('Content-Type', 'application/pdf')
  @Header('Content-Disposition', 'attachment; filename="traceagro-dossie.pdf"')
  async animalDossierPdf(
    @Param('animalId') animalId: string,
    @Req() request: { user?: AuthPrincipal },
  ) {
    const dossier = await this.dossier(animalId, request.user?.propertyId);
    const animal = dossier.animal as Record<string, unknown>;
    const lines = [
      'TRACEAGRO — DOSSIÊ DO ANIMAL',
      `Gerado em ${dossier.generatedAt}`,
      `Brinco visual: ${animal.visual ?? '—'}`,
      `RFID: ${animal.rfid ?? '—'}`,
      `Oficial: ${animal.official ?? '—'}`,
      `Sexo: ${animal.sex ?? '—'}   Raça: ${animal.breed ?? '—'}`,
      `Status: ${animal.status ?? '—'}   Lote: ${animal.lot ?? '—'}`,
      `Peso: ${animal.weightKg ?? '—'} kg   GMD: ${animal.gmdKgDay ?? '—'} kg/dia`,
      `Carência até: ${animal.withdrawalUntil ?? '—'}`,
      '',
      'EVENTOS — HASH E PROVA',
      ...(dossier.events as Array<Record<string, unknown>>).map((event) =>
        `${event.occurredAt} | ${event.eventType} | hash ${event.payloadHash} | TxID ${event.txId ?? 'pendente'}`),
    ];
    return buildPdf(lines);
  }

  private async dossier(animalId: string, propertyId?: string) {
    const animal = await this.pool.query(
      `SELECT visual.visual_tag_number AS visual,
              rfid.rfid_code AS rfid,
              a.official_animal_id AS official,
              a.sex, a.breed_code AS breed,
              s.lifecycle_status AS status,
              s.current_herd_lot AS lot,
              s.last_weight_kg AS "weightKg",
              s.gmd_kg_day AS "gmdKgDay",
              s.withdrawal_until AS "withdrawalUntil"
         FROM core.animal a
         JOIN read_model.animal_state s ON s.animal_id = a.id
         LEFT JOIN core.animal_identifier visual
           ON visual.animal_id = a.id AND visual.active AND visual.identifier_type = 'VISUAL'
         LEFT JOIN core.animal_identifier rfid
           ON rfid.animal_id = a.id AND rfid.active AND rfid.identifier_type = 'RFID'
        WHERE a.id = $1
          AND ($2::uuid IS NULL OR s.current_property_id = $2)
        LIMIT 1`,
      [animalId, propertyId ?? null],
    );
    if (animal.rows.length === 0) throw new NotFoundException('animal not found');

    const events = await this.pool.query(
      `SELECT e.id AS "eventId", e.event_type AS "eventType",
              e.occurred_at AS "occurredAt", e.recorded_at AS "recordedAt",
              e.payload_hash AS "payloadHash", e.sync_status AS "syncStatus",
              e.corrected, u.name AS "actorName",
              a.tx_id AS "txId", a.block_number AS "blockNumber",
              p.canonical_json AS payload
         FROM core.event e
         JOIN core.app_user u ON u.id = e.actor_id
         LEFT JOIN core.event_payload p ON p.event_id = e.id
         LEFT JOIN core.blockchain_anchor a
           ON a.subject_id = e.id AND a.subject_type = 'EVENT'
        WHERE e.animal_id = $1
        ORDER BY e.occurred_at ASC
        LIMIT 500`,
      [animalId],
    );
    return {
      generatedAt: new Date().toISOString(),
      animalId,
      animal: animal.rows[0],
      events: events.rows,
    };
  }
}

function csv(value: unknown): string {
  if (value === null || value === undefined) return '';
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function buildPdf(lines: string[]): Buffer {
  const text = lines.map((line) => `(${pdfText(line)}) Tj 0 -14 Td`).join('\n');
  const stream = `BT\n/F1 9 Tf\n40 800 Td\n${text}\nET`;
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    `<< /Length ${Buffer.byteLength(stream, 'utf8')} >>\nstream\n${stream}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  const chunks = ['%PDF-1.4\n'];
  const offsets = [0];
  for (let index = 0; index < objects.length; index++) {
    offsets.push(Buffer.byteLength(chunks.join(''), 'utf8'));
    chunks.push(`${index + 1} 0 obj\n${objects[index]}\nendobj\n`);
  }
  const xrefOffset = Buffer.byteLength(chunks.join(''), 'utf8');
  chunks.push(`xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`);
  for (let index = 1; index < offsets.length; index++) {
    chunks.push(`${String(offsets[index]).padStart(10, '0')} 00000 n \n`);
  }
  chunks.push(`trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`);
  return Buffer.from(chunks.join(''), 'utf8');
}

function pdfText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replaceAll('\\', '\\\\')
    .replaceAll('(', '\\(')
    .replaceAll(')', '\\)')
    .replace(/[^\x20-\x7E]/g, '?');
}
