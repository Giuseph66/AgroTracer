import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';

import { AnchorModule } from './anchor/anchor.module';
import { AnimalsModule } from './animals/animals.module';
import { DatabaseModule } from './database/database.module';
import { DevicesModule } from './devices/devices.module';
import { EventsModule } from './events/events.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    DatabaseModule,
    EventsModule,
    AnimalsModule,
    AnchorModule,
    DevicesModule,
  ],
})
export class AppModule {}
