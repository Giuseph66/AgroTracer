import { Body, Controller, Get, Post, Req } from '@nestjs/common';

import { EventEnvelopeDto, SyncBatchDto } from './event.dto';
import { EventsService } from './events.service';
import { AuthPrincipal } from '../auth/auth.types';

@Controller()
export class EventsController {
  constructor(private readonly events: EventsService) {}

  /** Ingestão de 1 evento online (Doc 9 §4.4). */
  @Post('events')
  ingestOne(@Body() dto: EventEnvelopeDto, @Req() request: { user?: AuthPrincipal }) {
    return this.events.ingestOne(scopeEvent(dto, request.user));
  }

  /**
   * Ingestão em lote vinda do app offline (Doc 9 §5). Sempre 200 quando o lote
   * foi processado: cada evento traz o próprio veredicto, e a falha de um não
   * derruba os demais.
   */
  @Post('sync/batches')
  async ingestBatch(@Body() dto: SyncBatchDto, @Req() request: { user?: AuthPrincipal }) {
    const user = request.user;
    const { syncJobId, results } = await this.events.ingestBatch(
      user?.deviceId ?? dto.deviceId,
      dto.events.map((event) => scopeEvent(event, user)),
      dto.clockSkewMs,
    );
    return { batchId: dto.batchId, syncJobId, results };
  }

  /** Conflitos abertos aguardando resolução humana (Doc 8 §7). */
  @Get('sync/conflicts')
  async conflicts() {
    return { data: await this.events.conflicts() };
  }
}

function scopeEvent(event: EventEnvelopeDto, user?: AuthPrincipal): EventEnvelopeDto {
  if (!user) return event;
  return {
    ...event,
    actorId: user.actorId,
    organizationId: user.organizationId,
    deviceId: user.deviceId,
    propertyId: user.propertyId,
  };
}
