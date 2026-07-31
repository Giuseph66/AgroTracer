/// Modelos de domínio do app de campo — espelham o Documento 4 (Modelo de
/// Domínio) e o Documento 8 (estados de sincronização). Nesta fase os dados
/// vêm de um repositório mock; a estrutura já segue o contrato real.
library;

/// Estados de sincronização de um evento (Doc 8 §5).
enum SyncState {
  localDraft('Rascunho'),
  pendingSync('Aguardando envio'),
  syncing('Enviando'),
  acceptedByApi('Aceito'),
  pendingBlockchain('Ancorando'),
  confirmedOnBlockchain('Comprovado'),
  rejectedByApi('Rejeitado'),
  conflict('Conflito');

  const SyncState(this.label);
  final String label;
}

/// Ciclo de vida derivado do animal (Doc 4 §4.1).
enum LifecycleStatus {
  active('Ativo'),
  inTransit('Em trânsito'),
  quarantined('Quarentena'),
  slaughtered('Abatido'),
  dead('Óbito'),
  closed('Encerrado');

  const LifecycleStatus(this.label);
  final String label;
}

/// Tipos de evento usados nas telas desta fase (subconjunto do Doc 5).
enum EventKind {
  registerAnimal('Registro do animal'),
  linkIdentifier('Identificador vinculado'),
  reidentification('Troca de brinco'),
  weighing('Pesagem'),
  lotChange('Troca de lote'),
  vaccination('Vacinação'),
  treatment('Tratamento'),
  withdrawalPeriod('Carência'),
  shipmentDispatched('Embarque expedido'),
  shipmentReceived('Embarque recebido'),
  corrected('Correção');

  const EventKind(this.label);
  final String label;

  /// Nome do tipo no contrato da API (Doc 5 §3) — SCREAMING_SNAKE_CASE.
  String get wireName => switch (this) {
        EventKind.registerAnimal => 'REGISTER_ANIMAL',
        EventKind.linkIdentifier => 'LINK_IDENTIFIER',
        EventKind.reidentification => 'REIDENTIFICATION',
        EventKind.weighing => 'WEIGHING',
        EventKind.lotChange => 'LOT_CHANGE',
        EventKind.vaccination => 'VACCINATION',
        EventKind.treatment => 'TREATMENT',
        EventKind.withdrawalPeriod => 'WITHDRAWAL_PERIOD',
        EventKind.shipmentDispatched => 'SHIPMENT_DISPATCHED',
        EventKind.shipmentReceived => 'SHIPMENT_RECEIVED',
        EventKind.corrected => 'CORRECTED',
      };

  static EventKind? fromWire(String wire) {
    for (final k in EventKind.values) {
      if (k.wireName == wire) return k;
    }
    return null;
  }
}

class Animal {
  const Animal({
    required this.animalId,
    required this.visualTagNumber,
    required this.rfidCode,
    this.officialAnimalId,
    required this.sex,
    required this.breed,
    required this.ageMonths,
    required this.lot,
    required this.status,
    required this.lastWeightKg,
    required this.gmdKgDay,
    this.withdrawalUntil,
  });

  final String animalId;
  final String visualTagNumber;
  final String rfidCode;
  final String? officialAnimalId;
  final String sex; // 'M' | 'F'
  final String breed;
  final int ageMonths;
  final String lot;
  final LifecycleStatus status;
  final double lastWeightKg;
  final double gmdKgDay;
  final DateTime? withdrawalUntil;

  String get shortDescription =>
      '$sex · $breed · $ageMonths m · $lot';
}

class TraceEvent {
  const TraceEvent({
    required this.eventId,
    required this.kind,
    required this.occurredAt,
    required this.syncState,
    required this.actor,
    this.detail,
    this.flagged = false,
  });

  final String eventId;
  final EventKind kind;
  final DateTime occurredAt;
  final SyncState syncState;
  final String actor;
  final String? detail;
  final bool flagged;
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.eventId,
    required this.kind,
    required this.subject,
    required this.state,
    required this.recordedAt,
    this.errorCode,
  });

  final String eventId;
  final EventKind kind;
  final String subject; // brinco visual ou lote
  final SyncState state;
  final DateTime recordedAt;
  final String? errorCode;
}
