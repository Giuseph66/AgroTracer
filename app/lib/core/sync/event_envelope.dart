import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import 'canonical.dart' as canonical;

const _uuid = Uuid();

/// Identidade do laboratório (semente da migração 002). Em produção vem do
/// enrolamento do dispositivo e do login; aqui fica explícito o que é fixture.
abstract final class DevIdentity {
  static const organizationId = '22222222-2222-4222-8222-222222222222';
  static const actorId = '33333333-3333-4333-8333-333333333333';
  static const deviceId = '44444444-4444-4444-8444-444444444444';
  static const propertyId = '66666666-6666-4666-8666-666666666666';
  static const appVersion = '0.2.0';
  static const defaultIdentity = EventIdentity(
    organizationId: organizationId,
    actorId: actorId,
    deviceId: deviceId,
    propertyId: propertyId,
    appVersion: appVersion,
  );
}

/// Identidade efetiva do operador/dispositivo usada em eventos futuros.
class EventIdentity {
  const EventIdentity({
    required this.organizationId,
    required this.actorId,
    required this.deviceId,
    required this.propertyId,
    required this.appVersion,
    this.actorName = 'João P.',
    this.propertyName = 'Fazenda Santa Rita',
  });

  final String organizationId;
  final String actorId;
  final String deviceId;
  final String propertyId;
  final String appVersion;
  final String actorName;
  final String propertyName;
}

/// Envelope canônico do evento (Doc 5 §1), montado no dispositivo.
class EventEnvelope {
  EventEnvelope({
    required this.eventId,
    required this.eventType,
    required this.subjectType,
    required this.subjectId,
    required this.occurredAt,
    required this.recordedAt,
    required this.deviceSequence,
    required this.payload,
    this.animalId,
    this.propertyId,
    this.correctionOf,
    this.schemaVersion = '1.0',
    this.sourceSystem = 'MOBILE_OFFLINE',
    this.signature = 'sig-stub-dev',
    this.organizationId = DevIdentity.organizationId,
    this.actorId = DevIdentity.actorId,
    this.deviceId = DevIdentity.deviceId,
    this.appVersion = DevIdentity.appVersion,
  }) : payloadHash = canonical.payloadHash(payload);

  factory EventEnvelope.fromJson(Map<String, Object?> json) {
    final payload =
        (json['payload'] as Map?)?.cast<String, Object?>() ?? const {};
    return EventEnvelope(
      eventId: json['eventId'] as String,
      eventType: json['eventType'] as String,
      subjectType: (json['subjectType'] as String?) ?? 'ANIMAL',
      subjectId: json['subjectId'] as String,
      animalId: json['animalId'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      deviceSequence: (json['deviceSequence'] as num).toInt(),
      payload: payload,
      propertyId: json['propertyId'] as String?,
      correctionOf: json['correctionOf'] as String?,
      schemaVersion: (json['schemaVersion'] as String?) ?? '1.0',
      sourceSystem: (json['sourceSystem'] as String?) ?? 'MOBILE_OFFLINE',
      signature: (json['signature'] as String?) ?? 'sig-stub-dev',
      organizationId:
          (json['organizationId'] as String?) ?? DevIdentity.organizationId,
      actorId: (json['actorId'] as String?) ?? DevIdentity.actorId,
      deviceId: (json['deviceId'] as String?) ?? DevIdentity.deviceId,
      appVersion: (json['appVersion'] as String?) ?? DevIdentity.appVersion,
    );
  }

  /// Evento novo, com hash calculado e horários separados (R24).
  factory EventEnvelope.create({
    required EventKind kind,
    required String subjectId,
    required int deviceSequence,
    required Map<String, Object?> payload,
    String? animalId,
    DateTime? occurredAt,
    String subjectType = 'ANIMAL',
    EventIdentity identity = DevIdentity.defaultIdentity,
  }) {
    final now = DateTime.now().toUtc();
    return EventEnvelope(
      eventId: _uuid.v7(),
      eventType: kind.wireName,
      subjectType: subjectType,
      subjectId: subjectId,
      animalId: animalId,
      occurredAt: (occurredAt ?? now).toUtc(),
      recordedAt: now,
      deviceSequence: deviceSequence,
      payload: payload,
      propertyId: identity.propertyId,
      organizationId: identity.organizationId,
      actorId: identity.actorId,
      deviceId: identity.deviceId,
      appVersion: identity.appVersion,
    );
  }

  final String eventId;
  final String schemaVersion;
  final String eventType;
  final String subjectType;
  final String? animalId;
  final String subjectId;
  final DateTime occurredAt;
  final DateTime recordedAt;
  final int deviceSequence;
  final Map<String, Object?> payload;
  final String payloadHash;
  final String? propertyId;
  final String? correctionOf;
  final String sourceSystem;
  final String signature;
  final String organizationId;
  final String actorId;
  final String deviceId;
  final String appVersion;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'schemaVersion': schemaVersion,
    'eventType': eventType,
    'subjectType': subjectType,
    if (animalId != null) 'animalId': animalId,
    'subjectId': subjectId,
    'occurredAt': occurredAt.toIso8601String(),
    'recordedAt': recordedAt.toIso8601String(),
    'organizationId': organizationId,
    'actorId': actorId,
    'deviceId': deviceId,
    'deviceSequence': deviceSequence,
    'appVersion': appVersion,
    if (propertyId != null) 'propertyId': propertyId,
    'payload': payload,
    'payloadHash': payloadHash,
    // TODO(F2): trocar pela assinatura ECDSA P-256 do Keystore quando o
    // enrolamento de dispositivos entrar em produção.
    'signature': signature,
    'sourceSystem': sourceSystem,
    if (correctionOf != null) 'correctionOf': correctionOf,
  };
}
