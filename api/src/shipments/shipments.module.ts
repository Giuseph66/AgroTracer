import { Module } from '@nestjs/common';

import { ShipmentsController } from './shipments.controller';

@Module({ controllers: [ShipmentsController] })
export class ShipmentsModule {}
