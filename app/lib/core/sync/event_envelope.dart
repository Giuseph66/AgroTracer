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
  }) : payloadHash = canonical.payloadHash(payload);

  /// Evento novo, com hash calculado e horários separados (R24).
  factory EventEnvelope.create({
    required EventKind kind,
    required String subjectId,
    required int deviceSequence,
    required Map<String, Object?> payload,
    String? animalId,
    DateTime? occurredAt,
    String subjectType = 'ANIMAL',
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
      propertyId: DevIdentity.propertyId,
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

  Map<String, Object?> toJson() => {
        'eventId': eventId,
        'schemaVersion': schemaVersion,
        'eventType': eventType,
        'subjectType': subjectType,
        if (animalId != null) 'animalId': animalId,
        'subjectId': subjectId,
        'occurredAt': occurredAt.toIso8601String(),
        'recordedAt': recordedAt.toIso8601String(),
        'organizationId': DevIdentity.organizationId,
        'actorId': DevIdentity.actorId,
        'deviceId': DevIdentity.deviceId,
        'deviceSequence': deviceSequence,
        'appVersion': DevIdentity.appVersion,
        if (propertyId != null) 'propertyId': propertyId,
        'payload': payload,
        'payloadHash': payloadHash,
        // TODO(F2): assinar com a chave ECDSA P-256 do Android Keystore sobre
        // eventId|eventType|subjectId|occurredAt|deviceSequence|payloadHash.
        // Enquanto isso o servidor exige apenas presença (R26 no pipeline).
        'signature': 'sig-stub-dev',
        'sourceSystem': sourceSystem,
        if (correctionOf != null) 'correctionOf': correctionOf,
      };
}
