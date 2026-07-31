import { Controller, Get, Param, Query } from '@nestjs/common';

import { EventsService } from '../events/events.service';

/**
 * Fachada de consulta (Doc 9 §4.3): não existe CRUD de animal — o cadastro
 * nasce de REGISTER_ANIMAL e o estado é projeção dos eventos aceitos.
 */
@Controller()
export class AnimalsController {
  constructor(private readonly events: EventsService) {}

  @Get('animals')
  async list(@Query('propertyId') propertyId?: string) {
    return { data: await this.events.animals(propertyId ?? '') };
  }

  @Get('animals/:id/timeline')
  async timeline(@Param('id') id: string) {
    return { data: await this.events.timeline(id) };
  }
}
