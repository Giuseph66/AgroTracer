import { Module } from '@nestjs/common';

import { AnchorController } from './anchor.controller';
import { AnchorWorker } from './anchor.worker';
import { FabricGateway } from './fabric.gateway';

@Module({
  controllers: [AnchorController],
  providers: [FabricGateway, AnchorWorker],
  exports: [AnchorWorker],
})
export class AnchorModule {}
