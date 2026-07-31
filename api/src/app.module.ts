import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';

import { AnchorModule } from './anchor/anchor.module';
import { AreasModule } from './areas/areas.module';
import { AnimalsModule } from './animals/animals.module';
import { CatalogModule } from './catalog/catalog.module';
import { DatabaseModule } from './database/database.module';
import { DevicesModule } from './devices/devices.module';
import { EventsModule } from './events/events.module';
import { ShipmentsModule } from './shipments/shipments.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    DatabaseModule,
    EventsModule,
    CatalogModule,
    AreasModule,
    ShipmentsModule,
    AnimalsModule,
    AnchorModule,
    DevicesModule,
  ],
})
export class AppModule {}
