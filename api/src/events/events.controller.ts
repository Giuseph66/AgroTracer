import { Body, Controller, Get, Post } from '@nestjs/common';

import { EventEnvelopeDto, SyncBatchDto } from './event.dto';
import { EventsService } from './events.service';

@Controller()
export class EventsController {
  constructor(private readonly events: EventsService) {}

  /** Ingestão de 1 evento online (Doc 9 §4.4). */
  @Post('events')
  ingestOne(@Body() dto: EventEnvelopeDto) {
    return this.events.ingestOne(dto);
  }

  /**
   * Ingestão em lote vinda do app offline (Doc 9 §5). Sempre 200 quando o lote
   * foi processado: cada evento traz o próprio veredicto, e a falha de um não
   * derruba os demais.
   */
  @Post('sync/batches')
  async ingestBatch(@Body() dto: SyncBatchDto) {
    const { syncJobId, results } = await this.events.ingestBatch(
      dto.deviceId,
      dto.events,
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
