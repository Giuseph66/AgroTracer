import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  Post,
} from '@nestjs/common';
import { IsArray, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';

class PaddockPointDto {
  @Type(() => Number)
  x!: number;

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
}
