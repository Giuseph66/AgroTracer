/// Modelos de domínio do app de campo — espelham o Documento 4 (Modelo de
/// Domínio) e o Documento 8 (estados de sincronização). As telas consomem o
/// contrato real da API e o cache local preserva o mesmo formato offline.
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
  correctRegistration('Correção cadastral'),
  weighing('Pesagem'),
  lotChange('Troca de lote'),
  paddockChange('Troca de piquete'),
  vaccination('Vacinação'),
  exam('Exame'),
  diagnosis('Diagnóstico'),
  treatment('Tratamento'),
  withdrawalPeriod('Carência'),
  quarantine('Quarentena'),
  release('Liberação'),
  calving('Parto'),
  offspringLink('Vínculo de cria'),
  propertyEntry('Entrada na propriedade'),
  propertyExit('Saída da propriedade'),
  shipmentDispatched('Embarque expedido'),
  shipmentReceived('Embarque recebido'),
  gtaRegistered('GTA registrada'),
  corrected('Correção');

  const EventKind(this.label);
  final String label;

  /// Nome do tipo no contrato da API (Doc 5 §3) — SCREAMING_SNAKE_CASE.
  String get wireName => switch (this) {
        EventKind.registerAnimal => 'REGISTER_ANIMAL',
        EventKind.linkIdentifier => 'LINK_IDENTIFIER',
        EventKind.reidentification => 'REIDENTIFICATION',
        EventKind.correctRegistration => 'CORRECT_REGISTRATION',
        EventKind.weighing => 'WEIGHING',
        EventKind.lotChange => 'LOT_CHANGE',
        EventKind.paddockChange => 'PADDOCK_CHANGE',
        EventKind.vaccination => 'VACCINATION',
        EventKind.exam => 'EXAM',
        EventKind.diagnosis => 'DIAGNOSIS',
        EventKind.treatment => 'TREATMENT',
        EventKind.withdrawalPeriod => 'WITHDRAWAL_PERIOD',
        EventKind.quarantine => 'QUARANTINE',
        EventKind.release => 'RELEASE',
        EventKind.calving => 'CALVING',
        EventKind.offspringLink => 'OFFSPRING_LINK',
        EventKind.propertyEntry => 'PROPERTY_ENTRY',
        EventKind.propertyExit => 'PROPERTY_EXIT',
        EventKind.shipmentDispatched => 'SHIPMENT_DISPATCHED',
        EventKind.shipmentReceived => 'SHIPMENT_RECEIVED',
        EventKind.gtaRegistered => 'GTA_REGISTERED',
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
    this.paddockId,
    this.damId,
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
  final String? paddockId;
  final String? damId;

  String get shortDescription =>
      '$sex · $breed · $ageMonths m · $lot';
}

class AnimalRelation {
  const AnimalRelation({
    required this.relation,
    required this.animalId,
    required this.visualTagNumber,
    required this.sex,
    required this.breed,
  });

  final String relation;
  final String animalId;
  final String visualTagNumber;
  final String sex;
  final String breed;
}

class VetProduct {
  const VetProduct({
    required this.code,
    required this.name,
    this.activeIngredient,
    required this.withdrawalSlaughterDays,
    required this.withdrawalMilkDays,
  });

  final String code;
  final String name;
  final String? activeIngredient;
  final int withdrawalSlaughterDays;
  final int withdrawalMilkDays;

  String get withdrawalLabel => withdrawalSlaughterDays == 0
      ? 'sem carência de abate'
      : '$withdrawalSlaughterDays dias de carência';
}

class Paddock {
  const Paddock({
    required this.id,
    required this.name,
    required this.areaHa,
    required this.animalCount,
    required this.alertCount,
    this.boundary = const [],
    this.version = 1,
  });

  final String id;
  final String name;
  final double areaHa;
  final int animalCount;
  final int alertCount;

  /// Contorno do piquete: pares `[longitude, latitude]`, na ordem do GeoJSON
  /// devolvido pela API. Vazio quando a geometria não foi carregada — nesse
  /// caso a área não pode ser desenhada no mapa, só listada.
  final List<List<double>> boundary;

  /// Versão da geometria. Editar o contorno cria a versão seguinte e arquiva
  /// a anterior; o número é o que permite conferir qual desenho valia quando
  /// um animal estava aqui.
  final int version;

  bool get hasAlert => alertCount > 0;
  bool get hasBoundary => boundary.length >= 3;
}

class PaddockAnimal {
  const PaddockAnimal({
    required this.animalId,
    required this.sex,
    required this.breed,
    required this.visualTagNumber,
    required this.lifecycleStatus,
    this.withdrawalUntil,
    required this.lastWeightKg,
  });

  final String animalId;
  final String sex;
  final String breed;
  final String visualTagNumber;
  final String lifecycleStatus;
  final DateTime? withdrawalUntil;
  final double lastWeightKg;

  bool get hasAlert => lifecycleStatus == 'QUARANTINED' || withdrawalUntil != null;
}

class Shipment {
  const Shipment({
    required this.shipmentId,
    required this.purpose,
    required this.status,
    required this.animalCount,
    required this.receivedCount,
    required this.discrepancyCount,
    this.vehiclePlate,
    this.gtaNumber,
  });

  final String shipmentId;
  final String purpose;
  final String status;
  final int animalCount;
  final int receivedCount;
  final int discrepancyCount;
  final String? vehiclePlate;
  final String? gtaNumber;

  bool get needsAttention => discrepancyCount > 0 || status == 'DISPATCHED';
}

class ShipmentAnimal {
  const ShipmentAnimal({
    required this.animalId,
    this.visualTagNumber,
    this.rfidCode,
    required this.received,
    this.discrepancy,
  });

  final String animalId;
  final String? visualTagNumber;
  final String? rfidCode;
  final bool received;
  final String? discrepancy;

  String get label => visualTagNumber ?? rfidCode ?? animalId.substring(0, 8);
}

class ShipmentDetail {
  const ShipmentDetail({
    required this.shipmentId,
    required this.status,
    this.gtaNumber,
    this.gtaUf,
    required this.animals,
  });

  final String shipmentId;
  final String status;
  final String? gtaNumber;
  final String? gtaUf;
  final List<ShipmentAnimal> animals;
}

class AnimalIdentifier {
  const AnimalIdentifier({
    required this.id,
    required this.type,
    this.rfidCode,
    this.visualTagNumber,
    this.officialNumber,
    required this.active,
    required this.linkedAt,
    this.unlinkedAt,
    this.unlinkReason,
  });

  final String id;
  final String type;
  final String? rfidCode;
  final String? visualTagNumber;
  final String? officialNumber;
  final bool active;
  final DateTime linkedAt;
  final DateTime? unlinkedAt;
  final String? unlinkReason;

  String get label => rfidCode ?? visualTagNumber ?? officialNumber ?? 'sem valor';
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
