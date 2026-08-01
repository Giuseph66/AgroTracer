import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { IsArray, IsNumber, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';

class PaddockPointDto {
  @IsNumber()
  @Type(() => Number)
  x!: number;

  @IsNumber()
  @Type(() => Number)
  y!: number;
}

class CreatePaddockDto {
  @IsString()
  name!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PaddockPointDto)
  points!: PaddockPointDto[];
}

class UpdateBoundaryDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PaddockPointDto)
  points!: PaddockPointDto[];
}

@Controller('properties/:propertyId/paddocks')
export class AreasController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  @Get()
  async list(@Param('propertyId') propertyId: string) {
    const { rows } = await this.pool.query(
      `SELECT p.id, p.name, p.version, p.active,
              ROUND((ST_Area(p.geom::geography) / 10000.0)::numeric, 2) AS "areaHa",
              ST_AsGeoJSON(p.geom)::json AS geometry,
              COUNT(s.animal_id)::int AS "animalCount",
              COUNT(*) FILTER (WHERE s.quarantined OR s.withdrawal_until > now())::int AS "alertCount"
         FROM core.paddock p
         LEFT JOIN read_model.animal_state s ON s.current_paddock_id = p.id
        WHERE p.property_id = $1 AND p.active
        GROUP BY p.id
        ORDER BY p.name`,
      [propertyId],
    );
    return { data: rows };
  }

  @Get(':paddockId/animals')
  async animals(@Param('paddockId') paddockId: string) {
    const { rows } = await this.pool.query(
      `SELECT a.id AS "animalId", a.sex, a.breed_code AS "breedCode",
              s.lifecycle_status AS "lifecycleStatus",
              s.quarantined, s.withdrawal_until AS "withdrawalUntil",
              s.last_weight_kg AS "lastWeightKg",
              visual.visual_tag_number AS "visualTagNumber"
         FROM read_model.animal_state s
         JOIN core.animal a ON a.id = s.animal_id
         LEFT JOIN core.animal_identifier visual
           ON visual.animal_id = a.id AND visual.active
          AND visual.identifier_type = 'VISUAL'
        WHERE s.current_paddock_id = $1
        ORDER BY visual.visual_tag_number`,
      [paddockId],
    );
    return { data: rows };
  }

  @Post()
  async create(
    @Param('propertyId') propertyId: string,
    @Body() dto: CreatePaddockDto,
  ) {
    if (dto.points.length < 3) {
      return { error: 'ERR-AREA-002', detail: 'um piquete exige ao menos 3 pontos' };
    }
    const closed = [...dto.points, dto.points[0]];
    const geojson = JSON.stringify({
      type: 'Polygon',
      coordinates: [closed.map((point) => [point.x, point.y])],
    });
    const { rows } = await this.pool.query(
      `INSERT INTO core.paddock (property_id, name, geom)
       SELECT $1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3), 4674)
        WHERE ST_IsValid(ST_SetSRID(ST_GeomFromGeoJSON($3), 4674))
       RETURNING id, name, version,
         ROUND((ST_Area(geom::geography) / 10000.0)::numeric, 2) AS "areaHa",
         ST_AsGeoJSON(geom)::json AS geometry`,
      [propertyId, dto.name.trim(), geojson],
    );
    if (rows.length === 0) {
      return { error: 'ERR-AREA-003', detail: 'polígono inválido ou autointersectante' };
    }
    return rows[0];
  }

  /**
   * Redesenha o contorno de um piquete.
   *
   * A geometria anterior não é sobrescrita: ela é encerrada (`valid_to`) e
   * desativada, e o novo contorno entra como versão seguinte (Doc 4 — geometria
   * versionada). Assim continua possível responder "qual era o piquete quando
   * aquele animal estava nele", que é justamente o que uma auditoria pergunta.
   *
   * Os animais seguem no piquete: a identidade da área é o `id` da versão
   * corrente, então a nova versão herda os vínculos apontando para o mesmo
   * registro lógico.
   */
  @Put(':paddockId/boundary')
  async updateBoundary(
    @Param('propertyId') propertyId: string,
    @Param('paddockId') paddockId: string,
    @Body() dto: UpdateBoundaryDto,
  ) {
    if (dto.points.length < 3) {
      return { error: 'ERR-AREA-002', detail: 'um piquete exige ao menos 3 pontos' };
    }

    const closed = [...dto.points, dto.points[0]];
    const geojson = JSON.stringify({
      type: 'Polygon',
      coordinates: [closed.map((point) => [point.x, point.y])],
    });

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // A geometria que sai precisa ser lida como texto antes do update: é ela
      // que será arquivada, e depois do UPDATE a linha já não a tem.
      const current = await client.query(
        `SELECT id, name, version, valid_from AS "validFrom",
                ST_AsEWKT(geom) AS "geomEwkt"
           FROM core.paddock
          WHERE id = $1 AND property_id = $2 AND active
          FOR UPDATE`,
        [paddockId, propertyId],
      );

      if (current.rowCount === 0) {
        await client.query('ROLLBACK');
        return { error: 'ERR-AREA-004', detail: 'piquete não encontrado' };
      }

      const valid = await client.query(
        `SELECT ST_IsValid(ST_SetSRID(ST_GeomFromGeoJSON($1), 4674)) AS ok`,
        [geojson],
      );
      if (!valid.rows[0]?.ok) {
        await client.query('ROLLBACK');
        return {
          error: 'ERR-AREA-003',
          detail: 'polígono inválido ou autointersectante',
        };
      }

      const previous = current.rows[0];

      // A corrente sobe de versão primeiro. O arquivamento vem depois, senão
      // as duas linhas ficariam com a mesma versão e a chave única
      // (property_id, name, version) recusaria a inserção.
      const updated = await client.query(
        `UPDATE core.paddock
            SET geom = ST_SetSRID(ST_GeomFromGeoJSON($2), 4674),
                version = version + 1,
                valid_from = now()
          WHERE id = $1
        RETURNING id, name, version,
          ROUND((ST_Area(geom::geography) / 10000.0)::numeric, 2) AS "areaHa",
          ST_AsGeoJSON(geom)::json AS geometry`,
        [paddockId, geojson],
      );

      // Guarda o contorno que saiu como registro histórico inativo.
      await client.query(
        `INSERT INTO core.paddock
           (property_id, name, geom, version, valid_from, valid_to, active)
         VALUES ($1, $2, ST_GeomFromEWKT($3), $4, $5, now(), false)`,
        [
          propertyId,
          previous.name,
          previous.geomEwkt,
          previous.version,
          previous.validFrom,
        ],
      );

      await client.query('COMMIT');
      return updated.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /** Contornos anteriores deste piquete, do mais recente para o mais antigo. */
  @Get(':paddockId/history')
  async history(
    @Param('propertyId') propertyId: string,
    @Param('paddockId') paddockId: string,
  ) {
    const { rows } = await this.pool.query(
      `SELECT p.id, p.name, p.version, p.active,
              p.valid_from AS "validFrom", p.valid_to AS "validTo",
              ROUND((ST_Area(p.geom::geography) / 10000.0)::numeric, 2) AS "areaHa",
              ST_AsGeoJSON(p.geom)::json AS geometry
         FROM core.paddock p
         JOIN core.paddock current ON current.id = $1
        WHERE p.property_id = $2 AND p.name = current.name
        ORDER BY p.version DESC, p.valid_from DESC`,
      [paddockId, propertyId],
    );
    return { data: rows };
  }
}
