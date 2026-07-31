import { Module } from '@nestjs/common';

import { EventsModule } from '../events/events.module';
import { AnimalsController } from './animals.controller';

@Module({
  imports: [EventsModule],
  controllers: [AnimalsController],
})
export class AnimalsModule {}
