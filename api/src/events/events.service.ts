import { Injectable, Logger } from '@nestjs/common';

import { payloadHash as computeHash } from './canonical';
import { EventEnvelopeDto, EventType, EventVerdict } from './event.dto';
import { EventsRepository, StoredVerdict } from './events.repository';

/** Tolerância de relógio adiantado antes de marcar TIME_SUSPECT (Doc 8 §9). */
const CLOCK_FUTURE_TOLERANCE_MS = 5 * 60 * 1000;

/** Faixas de peso plausíveis por categoria (Doc 5 §4.3). */
const WEIGHT_MIN_KG = 15;
const WEIGHT_MAX_KG = 1500;

/** Eventos aceitos mesmo com o ciclo do animal encerrado (R14). */
const ALLOWED_AFTER_CLOSE = new Set<string>([
  'DOCUMENT_ATTACHED',
  'CORRECTED',
  'CARCASS_CREATED',
  'RECORD_CLOSED',
]);

@Injectable()
export class EventsService {
  private readonly log = new Logger(EventsService.name);

  constructor(private readonly repo: EventsRepository) {}

  async ingestBatch(
    deviceId: string,
    events: EventEnvelopeDto[],
    clockSkewMs?: number,
  ): Promise<{ syncJobId: string; results: EventVerdict[] }> {
    const syncJobId = await this.repo.createSyncJob(
      deviceId,
      events.length,
      clockSkewMs,
    );

    // R27: a ordem vinculante é a sequência do dispositivo, não a do JSON.
    const ordered = [...events].sort(
      (a, b) => a.deviceSequence - b.deviceSequence,
    );

    const results: EventVerdict[] = [];
    for (const e of ordered) {
      results.push(await this.ingestOne(e, { syncJobId, clockSkewMs }));
    }

    await this.repo.closeSyncJob(syncJobId, {
      accepted: results.filter((r) => r.status === 'ACCEPTED').length,
      rejected: results.filter((r) => r.status === 'REJECTED').length,
      conflicts: results.filter((r) => r.status === 'CONFLICT').length,
    });

    return { syncJobId, results };
  }

  /**
   * Pipeline de ingestão (Doc 9 §4.4), na ordem: dedup → dispositivo →
   * assinatura → hash → sujeito → regras de negócio → persistência.
   * Cada etapa que reprova devolve veredicto persistido, para que o reenvio
   * do mesmo eventId responda idêntico (R23).
   */
  async ingestOne(
    e: EventEnvelopeDto,
    ctx: { syncJobId?: string; clockSkewMs?: number } = {},
  ): Promise<EventVerdict> {
    // 1. Dedup primário por eventId (R22): reenvio devolve o original.
    const seen = await this.repo.findVerdict(e.eventId);
    if (seen) return { ...stripInternal(seen), duplicate: true };

    // 2. Dedup secundário por (deviceId, deviceSequence).
    const seqOwner = await this.repo.findEventIdBySequence(
      e.deviceId,
      e.deviceSequence,
    );
    if (seqOwner && seqOwner !== e.eventId) {
      return this.reject(e, ctx, {
        status: 'CONFLICT',
        code: 'ORDER_VIOLATION',
        detail: `deviceSequence ${e.deviceSequence} já usado pelo evento ${seqOwner}`,
      });
    }

    // 3. Dispositivo registrado e ativo (R25, R40).
    const device = await this.repo.findDevice(e.deviceId);
    if (!device) {
      return this.reject(e, ctx, {
        status: 'REJECTED',
        code: 'ERR-DEV-001',
        detail: 'dispositivo não registrado',
      });
    }
    if (device.status !== 'ACTIVE') {
      return this.reject(e, ctx, {
        status: 'REJECTED',
        code: 'ERR-DEV-001',
        detail: `dispositivo ${device.status.toLowerCase()}`,
      });
    }

    // 4. Assinatura do dispositivo (R26).
    // TODO(F1): verificar ECDSA P-256 sobre
    // `eventId|eventType|subjectId|occurredAt|deviceSequence|payloadHash`
    // contra device.public_key. Enquanto o app não assina de verdade, exigimos
    // apenas presença — a etapa está no lugar certo do pipeline.
    if (!e.signature || e.signature.length < 4) {
      return this.reject(e, ctx, {
        status: 'REJECTED',
        code: 'ERR-EVT-SIGNATURE',
        detail: 'assinatura ausente ou malformada',
      });
    }

    // 5. Integridade do payload: o hash declarado precisa bater com o conteúdo.
    const hash = computeHash(e.payload);
    if (hash !== e.payloadHash) {
      return this.reject(e, ctx, {
        status: 'REJECTED',
        code: 'ERR-EVT-HASH',
        detail: 'payloadHash não corresponde ao payload canônico',
      });
    }

    // 6. Sujeito precisa existir (exceto quando o próprio evento o cria).
    if (e.animalId && e.eventType !== EventType.REGISTER_ANIMAL) {
      const exists = await this.repo.animalExists(e.animalId);
      if (!exists) {
        return this.reject(e, ctx, {
          status: 'CONFLICT',
          code: 'SUBJECT_UNKNOWN',
          detail: `animal ${e.animalId} inexistente nesta base`,
        });
      }

      // R14: ciclo encerrado só aceita tipos compatíveis.
      const state = await this.repo.animalState(e.animalId);
      const closed =
        state &&
        ['SLAUGHTERED', 'DEAD', 'CLOSED'].includes(state.lifecycle_status);
      if (closed && !ALLOWED_AFTER_CLOSE.has(e.eventType)) {
        return this.reject(e, ctx, {
          status: 'CONFLICT',
          code: 'SUBJECT_CLOSED',
          detail: `animal com ciclo ${state!.lifecycle_status} não aceita ${e.eventType}`,
        });
      }
    }

    // 7. Regras específicas por tipo.
    const ruleFailure = await this.checkTypeRules(e);
    if (ruleFailure) return this.reject(e, ctx, ruleFailure);

    // 8. Persistência transacional + projeções + âncora pendente.
    const timeSuspect =
      new Date(e.occurredAt).getTime() >
      Date.now() + CLOCK_FUTURE_TOLERANCE_MS;

    try {
      await this.repo.withTransaction(async (client) => {
        await this.repo.insertEvent(client, e, {
          clockSkewMs: ctx.clockSkewMs,
          timeSuspect,
        });
        await this.applyProjections(client, e);
        await this.repo.saveVerdict(client, e, {
          eventId: e.eventId,
          status: 'ACCEPTED',
        });
      });
    } catch (err) {
      // Corrida entre dois lotes concorrentes com o mesmo evento: o índice
      // único resolve, e a resposta idempotente é a do vencedor.
      const existing = await this.repo.findVerdict(e.eventId);
      if (existing) return { ...stripInternal(existing), duplicate: true };
      this.log.error(`falha ao persistir evento ${e.eventId}`, err as Error);
      throw err;
    }

    return { eventId: e.eventId, status: 'ACCEPTED' };
  }

  private async checkTypeRules(
    e: EventEnvelopeDto,
  ): Promise<Omit<EventVerdict, 'eventId'> | undefined> {
    switch (e.eventType) {
      case EventType.REGISTER_ANIMAL: {
        const animalId = e.animalId ?? e.subjectId;
        if (await this.repo.animalExists(animalId)) {
          return {
            status: 'REJECTED',
            code: 'ERR-ANI-001',
            detail: `animal ${animalId} já existe`,
          };
        }
        const sex = str(e.payload['sex']);
        if (sex !== 'M' && sex !== 'F') {
          return {
            status: 'REJECTED',
            code: 'ERR-ANI-004',
            detail: 'sexo deve ser M ou F',
          };
        }
        if (!str(e.payload['birthType'])) {
          return {
            status: 'REJECTED',
            code: 'ERR-ANI-005',
            detail: 'birthType obrigatório',
          };
        }
        const birthDate = str(e.payload['birthDate']);
        if (birthDate && new Date(birthDate).getTime() > Date.now()) {
          return {
            status: 'REJECTED',
            code: 'ERR-ANI-003',
            detail: 'data de nascimento futura',
          };
        }
        return undefined;
      }

      case EventType.LINK_IDENTIFIER:
      case EventType.REIDENTIFICATION: {
        const next = e.eventType === EventType.REIDENTIFICATION
          ? e.payload['newIdentifier']
          : e.payload;
        const nextRecord = next && typeof next === 'object'
          ? next as Record<string, unknown>
          : e.payload;
        const rfid = str(nextRecord['rfidCode']);
        if (!rfid) return undefined;
        const owner = await this.repo.animalHoldingRfid(rfid);
        // R3: um RFID ativo nunca pertence a dois animais.
        if (owner && owner !== e.animalId) {
          return {
            status: 'CONFLICT',
            code: 'IDENTIFIER_TAKEN',
            detail: `RFID ${rfid} já ativo no animal ${owner}`,
          };
        }
        if (e.eventType === EventType.REIDENTIFICATION &&
            (!str(e.payload['oldIdentifierId']) || !str(e.payload['reason']))) {
          return {
            status: 'REJECTED',
            code: 'ERR-IDF-003',
            detail: 'oldIdentifierId e reason são obrigatórios na troca',
          };
        }
        return undefined;
      }

      case EventType.VACCINATION:
      case EventType.TREATMENT: {
        const productRef = str(e.payload['productRef']);
        if (!productRef || !(await this.repo.vetProduct(productRef))?.active) {
          return {
            status: 'REJECTED',
            code: 'ERR-SAN-003',
            detail: 'produto veterinário ausente ou inativo no catálogo',
          };
        }
        return undefined;
      }

      case EventType.PADDOCK_CHANGE: {
        const paddockId = str(e.payload['paddockId']);
        const paddock = paddockId ? await this.repo.paddock(paddockId) : undefined;
        if (!paddock || (e.propertyId && paddock.property_id !== e.propertyId)) {
          return {
            status: 'REJECTED',
            code: 'ERR-AREA-001',
            detail: 'piquete inexistente ou fora da propriedade do evento',
          };
        }
        return undefined;
      }

      case EventType.WEIGHING: {
        const weight = num(e.payload['weightKg']);
        if (weight === undefined) {
          return {
            status: 'REJECTED',
            code: 'ERR-PES-001',
            detail: 'weightKg ausente',
          };
        }
        if (weight < WEIGHT_MIN_KG || weight > WEIGHT_MAX_KG) {
          return {
            status: 'REJECTED',
            code: 'ERR-PES-001',
            detail: `peso ${weight} kg fora da faixa plausível (${WEIGHT_MIN_KG}–${WEIGHT_MAX_KG})`,
          };
        }
        if (e.animalId) {
          const state = await this.repo.animalState(e.animalId);
          if (state?.lifecycle_status === 'IN_TRANSIT') {
            return {
              status: 'CONFLICT',
              code: 'ERR-MOV-001',
              detail: 'animal em trânsito não pode ser pesado nesta propriedade',
            };
          }
        }
        return undefined;
      }

      default:
        return undefined;
    }
  }

  private async applyProjections(
    client: Parameters<
      Parameters<EventsRepository['withTransaction']>[0]
    >[0],
    e: EventEnvelopeDto,
  ): Promise<void> {
    switch (e.eventType) {
      case EventType.REGISTER_ANIMAL:
        await this.repo.insertAnimal(client, e);
        break;

      case EventType.WEIGHING:
        await this.repo.applyWeighing(
          client,
          e,
          num(e.payload['weightKg'])!,
          str(e.payload['weightSource']) ?? 'MANUAL',
        );
        break;

      case EventType.VACCINATION:
      case EventType.EXAM:
      case EventType.DIAGNOSIS:
      case EventType.TREATMENT:
      case EventType.WITHDRAWAL_PERIOD:
        await this.repo.applyHealthEvent(
          client,
          e,
          str(e.payload['productRef']) ?? null,
          valueAsText(e.payload['dosage']) ?? null,
          str(e.payload['withdrawalUntil']) ?? null,
          // Agrupador de aplicação em lote (Doc 5 §4.4): liga os eventos
          // gerados numa mesma passagem de manejo.
          str(e.payload['batchId']) ?? null,
        );
        break;

      case EventType.LINK_IDENTIFIER:
        await this.repo.applyIdentifierLink(
          client,
          e,
          str(e.payload['rfidCode']) ?? null,
          str(e.payload['visualTagNumber']) ?? null,
        );
        break;

      case EventType.REIDENTIFICATION:
        await this.repo.applyReidentification(client, e, e.payload);
        break;

      case EventType.LOT_CHANGE:
        await this.repo.applyLotChange(
          client,
          e,
          str(e.payload['toLot']) ?? str(e.payload['lot']) ?? 'Sem lote',
        );
        break;

      case EventType.PADDOCK_CHANGE:
        await this.repo.applyPaddockChange(client, e, str(e.payload['paddockId'])!);
        break;

      case EventType.OFFSPRING_LINK:
        await this.repo.applyOffspringLink(client, e, str(e.payload['damId'])!);
        break;

      case EventType.QUARANTINE:
        await this.repo.applyQuarantine(client, e, true);
        break;

      case EventType.RELEASE:
        await this.repo.applyQuarantine(client, e, false);
        break;

      case EventType.PROPERTY_EXIT:
        await this.repo.applyPropertyExit(client, e);
        break;

      case EventType.PROPERTY_ENTRY:
        await this.repo.applyPropertyEntry(
          client,
          e,
          str(e.payload['propertyId']) ?? e.propertyId!,
        );
        break;

      case EventType.SHIPMENT_DISPATCHED:
        await this.repo.applyShipmentDispatched(client, e);
        break;

      case EventType.SHIPMENT_RECEIVED:
        await this.repo.applyShipmentReceived(client, e);
        break;

      case EventType.SLAUGHTER:
        await this.repo.applyLifecycle(client, e, 'SLAUGHTERED');
        break;

      case EventType.DEATH:
        await this.repo.applyLifecycle(client, e, 'DEAD');
        break;

      default:
        break;
    }
  }

  private async reject(
    e: EventEnvelopeDto,
    ctx: { syncJobId?: string },
    v: Omit<EventVerdict, 'eventId'>,
  ): Promise<EventVerdict> {
    const stored = await this.repo.withTransaction(async (client) => {
      let conflictId: string | undefined;
      if (v.status === 'CONFLICT') {
        conflictId = await this.repo.insertConflict(
          client,
          e,
          v.code ?? 'UNKNOWN',
          { detail: v.detail, eventType: e.eventType, payload: e.payload },
          ctx.syncJobId,
        );
      }
      const full: StoredVerdict = { eventId: e.eventId, ...v, conflictId };
      await this.repo.saveVerdict(client, e, full);
      return full;
    });
    return stripInternal(stored);
  }

  timeline(animalId: string) {
    return this.repo.timeline(animalId);
  }

  animals(propertyId: string) {
    return this.repo.animalsByProperty(propertyId);
  }

  conflicts() {
    return this.repo.openConflicts();
  }
}

function stripInternal(v: StoredVerdict): EventVerdict {
  const { conflictId, ...rest } = v;
  return conflictId ? { ...rest, conflictId } : rest;
}

function str(v: unknown): string | undefined {
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

function num(v: unknown): number | undefined {
  return typeof v === 'number' && Number.isFinite(v) ? v : undefined;
}

function valueAsText(v: unknown): string | undefined {
  if (typeof v === 'string') return v;
  if (v === undefined || v === null) return undefined;
  return JSON.stringify(v);
}
