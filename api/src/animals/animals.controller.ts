import { Controller, Get, Param, Query, Req } from '@nestjs/common';

import { AuthPrincipal } from '../auth/auth.types';
import { EventsService } from '../events/events.service';

/**
 * Fachada de consulta (Doc 9 §4.3): não existe CRUD de animal — o cadastro
 * nasce de REGISTER_ANIMAL e o estado é projeção dos eventos aceitos.
 */
@Controller()
export class AnimalsController {
  constructor(private readonly events: EventsService) {}

  @Get('animals')
  async list(
    @Query('propertyId') propertyId: string | undefined,
    @Req() request: { user?: AuthPrincipal },
  ) {
    return {
      data: await this.events.animals(request.user?.propertyId ?? propertyId ?? ''),
    };
  }

  @Get('animals/:id/timeline')
  async timeline(@Param('id') id: string) {
    return { data: await this.events.timeline(id) };
  }

  @Get('animals/:id/identifiers')
  async identifiers(@Param('id') id: string) {
    return { data: await this.events.identifiers(id) };
  }

  @Get('animals/:id/relations')
  async relations(@Param('id') id: string) {
    return { data: await this.events.relations(id) };
  }
}
