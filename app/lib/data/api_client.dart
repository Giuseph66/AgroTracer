import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// Cliente HTTP da API de leitura. Escrita nunca passa por aqui: todo fato do
/// domínio entra pela fila de eventos (Doc 9 §4.3).
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<Animal>> animals(String propertyId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/animals?propertyId=$propertyId'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(_animalFromJson)
        .toList();
  }

  Future<List<TraceEvent>> timeline(String animalId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/animals/$animalId/timeline'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data.cast<Map<String, Object?>>().map(_eventFromJson).toList();
  }

  void close() => _client.close();
}

Animal _animalFromJson(Map<String, Object?> j) {
  final birth = j['birthDate'] as String?;
  final months = birth == null
      ? 0
      : (DateTime.now().difference(DateTime.parse(birth)).inDays / 30.44)
          .floor();
  final withdrawal = j['withdrawalUntil'] as String?;
  return Animal(
    animalId: j['animalId'] as String,
    visualTagNumber: (j['visualTagNumber'] as String?) ?? '—',
    rfidCode: _formatRfid(j['rfidCode'] as String?),
    officialAnimalId: _formatOfficial(j['officialAnimalId'] as String?),
    sex: (j['sex'] as String?) ?? '?',
    breed: _breedLabel(j['breedCode'] as String?),
    ageMonths: months,
    lot: (j['herdLot'] as String?) ?? 'Sem lote',
    status: _statusFrom(j['lifecycleStatus'] as String?,
        quarantined: withdrawal != null &&
            DateTime.parse(withdrawal).isAfter(DateTime.now())),
    lastWeightKg: _toDouble(j['lastWeightKg']) ?? 0,
    gmdKgDay: _toDouble(j['gmdKgDay']) ?? 0,
    withdrawalUntil: withdrawal == null ? null : DateTime.parse(withdrawal),
  );
}

TraceEvent _eventFromJson(Map<String, Object?> j) {
  final type = j['eventType'] as String;
  final payload = (j['payload'] as Map?)?.cast<String, Object?>() ?? const {};
  return TraceEvent(
    eventId: j['eventId'] as String,
    kind: EventKind.fromWire(type) ?? EventKind.corrected,
    occurredAt: DateTime.parse(j['occurredAt'] as String).toLocal(),
    syncState: _syncStateFrom(j['syncStatus'] as String?),
    actor: (j['actorName'] as String?) ?? 'desconhecido',
    detail: _detailFor(type, payload),
    flagged: (j['corrected'] as bool?) ?? false,
  );
}

String? _detailFor(String type, Map<String, Object?> payload) {
  switch (type) {
    case 'WEIGHING':
      final kg = _toDouble(payload['weightKg']);
      final source = payload['weightSource'] == 'SCALE'
          ? 'balança ${payload['scaleId'] ?? ''}'.trim()
          : 'digitado';
      return kg == null
          ? null
          : '${kg.toStringAsFixed(1).replaceAll('.', ',')} kg · $source';
    case 'VACCINATION':
    case 'TREATMENT':
      final product = payload['productRef'];
      final dose = payload['dosage'];
      return [product, dose].where((e) => e != null).join(' · ');
    case 'LINK_IDENTIFIER':
      return 'RFID ${payload['rfidCode'] ?? ''}'.trim();
    case 'LOT_CHANGE':
      return '${payload['fromLot'] ?? '—'} → ${payload['toLot'] ?? '—'}';
    default:
      return null;
  }
}

SyncState _syncStateFrom(String? s) => switch (s) {
      'CONFIRMED_ON_BLOCKCHAIN' => SyncState.confirmedOnBlockchain,
      'PENDING_BLOCKCHAIN' => SyncState.pendingBlockchain,
      'ACCEPTED_BY_API' => SyncState.acceptedByApi,
      _ => SyncState.acceptedByApi,
    };

LifecycleStatus _statusFrom(String? s, {required bool quarantined}) {
  if (quarantined) return LifecycleStatus.quarantined;
  return switch (s) {
    'IN_TRANSIT' => LifecycleStatus.inTransit,
    'QUARANTINED' => LifecycleStatus.quarantined,
    'SLAUGHTERED' => LifecycleStatus.slaughtered,
    'DEAD' => LifecycleStatus.dead,
    'CLOSED' => LifecycleStatus.closed,
    _ => LifecycleStatus.active,
  };
}

double? _toDouble(Object? v) => switch (v) {
      null => null,
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

/// RFID e número oficial são exibidos agrupados para leitura em campo, mas
/// armazenados sem separador — são identificadores distintos e nunca se
/// misturam (Regra Fundamental de Identificação).
String _formatRfid(String? raw) {
  if (raw == null || raw.length < 4) return raw ?? '—';
  return '${raw.substring(0, 3)} ${raw.substring(3)}';
}

String? _formatOfficial(String? raw) =>
    raw == null ? null : _formatRfid(raw);

String _breedLabel(String? code) => switch (code) {
      'NELORE' => 'Nelore',
      'ABERDEEN' => 'Aberdeen',
      'ANGUS' => 'Angus',
      null => '—',
      _ => code[0] + code.substring(1).toLowerCase(),
    };
