import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';

import { AnchorModule } from './anchor/anchor.module';
import { AuthModule } from './auth/auth.module';
import { AreasModule } from './areas/areas.module';
import { AnimalsModule } from './animals/animals.module';
import { CatalogModule } from './catalog/catalog.module';
import { DatabaseModule } from './database/database.module';
import { DevicesModule } from './devices/devices.module';
import { EventsModule } from './events/events.module';
import { ShipmentsModule } from './shipments/shipments.module';
import { ReportsModule } from './reports/reports.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    AuthModule,
    DatabaseModule,
    EventsModule,
    CatalogModule,
    AreasModule,
    ShipmentsModule,
    ReportsModule,
    AnimalsModule,
    AnchorModule,
    DevicesModule,
  ],
})
export class AppModule {}
