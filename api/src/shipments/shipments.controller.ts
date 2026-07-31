import { Controller, Get, Inject, Param, Query } from '@nestjs/common';
import { Pool } from 'pg';

import { PG_POOL } from '../database/database.module';

@Controller('shipments')
export class ShipmentsController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  @Get()
  async list(@Query('propertyId') propertyId?: string, @Query('status') status?: string) {
    const { rows } = await this.pool.query(
      `SELECT s.id AS "shipmentId", s.origin_property_id AS "originPropertyId",
              s.destination_property_id AS "destinationPropertyId", s.purpose,
              s.vehicle_plate AS "vehiclePlate", s.gta_number AS "gtaNumber",
              s.status, s.expected_arrival AS "expectedArrival",
              COUNT(sa.animal_id)::int AS "animalCount",
              COUNT(sa.animal_id) FILTER (WHERE sa.received)::int AS "receivedCount",
              COUNT(sa.animal_id) FILTER (WHERE sa.discrepancy IS NOT NULL)::int AS "discrepancyCount"
         FROM core.shipment s
         LEFT JOIN core.shipment_animal sa ON sa.shipment_id = s.id
        WHERE ($1::uuid IS NULL OR s.origin_property_id = $1 OR s.destination_property_id = $1)
          AND ($2::text IS NULL OR s.status = $2)
        GROUP BY s.id
        ORDER BY s.created_at DESC`,
      [propertyId ?? null, status ?? null],
    );
    return { data: rows };
  }

  @Get(':shipmentId')
  async detail(@Param('shipmentId') shipmentId: string) {
    const shipment = await this.pool.query(
      `SELECT id AS "shipmentId", origin_property_id AS "originPropertyId",
              destination_property_id AS "destinationPropertyId", purpose, status,
              vehicle_plate AS "vehiclePlate", gta_number AS "gtaNumber",
              expected_arrival AS "expectedArrival", dispatched_at AS "dispatchedAt",
              received_at AS "receivedAt"
         FROM core.shipment WHERE id = $1`,
      [shipmentId],
    );
    const animals = await this.pool.query(
      `SELECT animal_id AS "animalId", received, discrepancy
         FROM core.shipment_animal WHERE shipment_id = $1 ORDER BY animal_id`,
      [shipmentId],
    );
    return { ...shipment.rows[0], animals: animals.rows };
  }
}
