import { Type } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsInt,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Min,
  ValidateNested,
} from 'class-validator';

/** Tipos do catálogo (Doc 5 §3). Subconjunto ativo nesta fase. */
export enum EventType {
  REGISTER_ANIMAL = 'REGISTER_ANIMAL',
  LINK_IDENTIFIER = 'LINK_IDENTIFIER',
  REIDENTIFICATION = 'REIDENTIFICATION',
  CORRECT_REGISTRATION = 'CORRECT_REGISTRATION',
  WEIGHING = 'WEIGHING',
  LOT_CHANGE = 'LOT_CHANGE',
  PADDOCK_CHANGE = 'PADDOCK_CHANGE',
  DIET_CHANGE = 'DIET_CHANGE',
  VACCINATION = 'VACCINATION',
  EXAM = 'EXAM',
  DIAGNOSIS = 'DIAGNOSIS',
  TREATMENT = 'TREATMENT',
  WITHDRAWAL_PERIOD = 'WITHDRAWAL_PERIOD',
  QUARANTINE = 'QUARANTINE',
  RELEASE = 'RELEASE',
  BREEDING = 'BREEDING',
  INSEMINATION = 'INSEMINATION',
  PREGNANCY_CHECK = 'PREGNANCY_CHECK',
  CALVING = 'CALVING',
  OFFSPRING_LINK = 'OFFSPRING_LINK',
  PROPERTY_ENTRY = 'PROPERTY_ENTRY',
  PROPERTY_EXIT = 'PROPERTY_EXIT',
  SHIPMENT_DISPATCHED = 'SHIPMENT_DISPATCHED',
  SHIPMENT_RECEIVED = 'SHIPMENT_RECEIVED',
  CUSTODY_TRANSFERRED = 'CUSTODY_TRANSFERRED',
  GTA_REGISTERED = 'GTA_REGISTERED',
  SLAUGHTER = 'SLAUGHTER',
  DEATH = 'DEATH',
  CARCASS_CREATED = 'CARCASS_CREATED',
  DOCUMENT_ATTACHED = 'DOCUMENT_ATTACHED',
  CORRECTED = 'CORRECTED',
}

export enum SourceSystem {
  MOBILE_OFFLINE = 'MOBILE_OFFLINE',
  MOBILE_ONLINE = 'MOBILE_ONLINE',
  WEB = 'WEB',
  API_INTEGRATION = 'API_INTEGRATION',
  SYSTEM = 'SYSTEM',
}

/** Envelope canônico do evento (Doc 5 §1). */
export class EventEnvelopeDto {
  @IsUUID(7)
  eventId: string;

  @IsString()
  @Matches(/^\d+\.\d+$/)
  schemaVersion: string;

  @IsEnum(EventType)
  eventType: EventType;

  @IsString()
  subjectType: string;

  @IsOptional()
  @IsUUID()
  animalId?: string;

  @IsString()
  subjectId: string;

  @IsISO8601()
  occurredAt: string;

  @IsISO8601()
  recordedAt: string;

  @IsUUID()
  organizationId: string;

  @IsUUID()
  actorId: string;

  @IsUUID()
  deviceId: string;

  @IsInt()
  @Min(0)
  deviceSequence: number;

  @IsString()
  appVersion: string;

  @IsOptional()
  @IsUUID()
  propertyId?: string;

  /** Payload completo embutido na ingestão; separado em EventPayload ao persistir. */
  @IsObject()
  payload: Record<string, unknown>;

  @IsString()
  @Length(64, 64)
  @Matches(/^[0-9a-f]{64}$/)
  payloadHash: string;

  @IsString()
  signature: string;

  @IsEnum(SourceSystem)
  sourceSystem: SourceSystem;

  @IsOptional()
  @IsUUID(7)
  correctionOf?: string;
}

export class SyncBatchDto {
  @IsUUID(7)
  batchId: string;

  @IsUUID()
  deviceId: string;

  @IsOptional()
  @IsInt()
  clockSkewMs?: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EventEnvelopeDto)
  events: EventEnvelopeDto[];
}

export type EventVerdict = {
  eventId: string;
  status: 'ACCEPTED' | 'REJECTED' | 'CONFLICT';
  duplicate?: boolean;
  code?: string;
  detail?: string;
  conflictId?: string;
};
