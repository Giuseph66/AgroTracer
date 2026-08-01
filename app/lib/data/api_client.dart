import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// Cliente HTTP da API de leitura. Escrita nunca passa por aqui: todo fato do
/// domínio entra pela fila de eventos (Doc 9 §4.3).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.tokenProvider,
    this.onUnauthorized,
    http.Client? client,
  })
    : _client = client ?? http.Client();

  final String baseUrl;
  final String? Function()? tokenProvider;
  final void Function()? onUnauthorized;
  final http.Client _client;

  Map<String, String> get _headers {
    final token = tokenProvider?.call();
    return token == null || token.isEmpty
        ? const {}
        : {'authorization': 'Bearer $token'};
  }

  Future<List<Animal>> animals(String propertyId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/animals?propertyId=$propertyId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data.cast<Map<String, Object?>>().map(_animalFromJson).toList();
  }

  Future<List<TraceEvent>> timeline(String animalId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/animals/$animalId/timeline'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data.cast<Map<String, Object?>>().map(_eventFromJson).toList();
  }

  Future<List<AnimalIdentifier>> identifiers(String animalId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/animals/$animalId/identifiers'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(
          (j) => AnimalIdentifier(
            id: j['id'] as String,
            type: j['type'] as String,
            rfidCode: j['rfidCode'] as String?,
            visualTagNumber: j['visualTagNumber'] as String?,
            officialNumber: j['officialNumber'] as String?,
            active: j['active'] as bool? ?? false,
            linkedAt: DateTime.parse(j['linkedAt'] as String).toLocal(),
            unlinkedAt: j['unlinkedAt'] == null
                ? null
                : DateTime.parse(j['unlinkedAt'] as String).toLocal(),
            unlinkReason: j['unlinkReason'] as String?,
          ),
        )
        .toList();
  }

  Future<List<AnimalRelation>> relations(String animalId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/animals/$animalId/relations'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(
          (j) => AnimalRelation(
            relation: j['relation'] as String,
            animalId: j['animalId'] as String,
            visualTagNumber: (j['visualTagNumber'] as String?) ?? '—',
            sex: (j['sex'] as String?) ?? '?',
            breed: (j['breedCode'] as String?) ?? '—',
          ),
        )
        .toList();
  }

  Future<List<VetProduct>> vetProducts() async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/catalog/vet-products'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(
          (j) => VetProduct(
            code: j['code'] as String,
            name: j['name'] as String,
            activeIngredient: j['activeIngredient'] as String?,
            withdrawalSlaughterDays:
                (j['withdrawalSlaughterDays'] as num?)?.toInt() ?? 0,
            withdrawalMilkDays: (j['withdrawalMilkDays'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<List<Paddock>> paddocks(String propertyId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/properties/$propertyId/paddocks'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(
          (j) => Paddock(
            id: j['id'] as String,
            name: j['name'] as String,
            areaHa: _toDouble(j['areaHa']) ?? 0,
            animalCount: (j['animalCount'] as num?)?.toInt() ?? 0,
            alertCount: (j['alertCount'] as num?)?.toInt() ?? 0,
            boundary: parseGeoJsonRing(j['geometry']),
            version: (j['version'] as num?)?.toInt() ?? 1,
          ),
        )
        .toList();
  }

  /// Redesenha o contorno de um piquete. O servidor arquiva a geometria
  /// anterior e devolve a nova versão.
  Future<Paddock> updatePaddockBoundary(
    String propertyId,
    String paddockId,
    List<List<double>> ring,
  ) async {
    final res = await _client
        .put(
          Uri.parse(
            '$baseUrl/v1/properties/$propertyId/paddocks/$paddockId/boundary',
          ),
          headers: {'content-type': 'application/json', ..._headers},
          body: jsonEncode({
            'points': ring.map((c) => {'x': c[0], 'y': c[1]}).toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    _checkUnauthorized(res);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, Object?>;
    // A API responde 200 com corpo de erro quando o polígono não passa na
    // validação do PostGIS; sem esta checagem o app trataria recusa como
    // sucesso e mostraria o contorno antigo como se tivesse sido salvo.
    if (body['error'] != null) {
      throw PaddockBoundaryRejected(
        body['error'] as String,
        (body['detail'] as String?) ?? 'contorno recusado pelo servidor',
      );
    }

    return Paddock(
      id: body['id'] as String,
      name: body['name'] as String,
      areaHa: _toDouble(body['areaHa']) ?? 0,
      animalCount: 0,
      alertCount: 0,
      boundary: parseGeoJsonRing(body['geometry']),
      version: (body['version'] as num?)?.toInt() ?? 1,
    );
  }

  Future<List<PaddockAnimal>> paddockAnimals(
    String propertyId,
    String paddockId,
  ) async {
    final res = await _client
        .get(
          Uri.parse(
            '$baseUrl/v1/properties/$propertyId/paddocks/$paddockId/animals',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(
          (j) => PaddockAnimal(
            animalId: j['animalId'] as String,
            sex: (j['sex'] as String?) ?? '?',
            breed: (j['breedCode'] as String?) ?? '—',
            visualTagNumber: (j['visualTagNumber'] as String?) ?? '—',
            lifecycleStatus: (j['lifecycleStatus'] as String?) ?? 'ACTIVE',
            withdrawalUntil: j['withdrawalUntil'] == null
                ? null
                : DateTime.parse(j['withdrawalUntil'] as String),
            lastWeightKg: _toDouble(j['lastWeightKg']) ?? 0,
          ),
        )
        .toList();
  }

  Future<List<Shipment>> shipments(String propertyId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/shipments?propertyId=$propertyId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .cast<Map<String, Object?>>()
        .map(
          (j) => Shipment(
            shipmentId: j['shipmentId'] as String,
            purpose: (j['purpose'] as String?) ?? 'OTHER',
            status: (j['status'] as String?) ?? 'DRAFT',
            animalCount: (j['animalCount'] as num?)?.toInt() ?? 0,
            receivedCount: (j['receivedCount'] as num?)?.toInt() ?? 0,
            discrepancyCount: (j['discrepancyCount'] as num?)?.toInt() ?? 0,
            vehiclePlate: j['vehiclePlate'] as String?,
            gtaNumber: j['gtaNumber'] as String?,
          ),
        )
        .toList();
  }

  Future<ShipmentDetail> shipmentDetail(String shipmentId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/shipments/$shipmentId'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, Object?>;
    final animals = (json['animals'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .map(
          (j) => ShipmentAnimal(
            animalId: j['animalId'] as String,
            visualTagNumber: j['visualTagNumber'] as String?,
            rfidCode: j['rfidCode'] as String?,
            received: j['received'] as bool? ?? false,
            discrepancy: j['discrepancy'] as String?,
          ),
        )
        .toList();
    return ShipmentDetail(
      shipmentId: json['shipmentId'] as String,
      status: (json['status'] as String?) ?? 'DRAFT',
      gtaNumber: json['gtaNumber'] as String?,
      gtaUf: json['gtaUf'] as String?,
      animals: animals,
    );
  }

  Future<String> inventoryCsv(String propertyId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/reports/animals.csv?propertyId=$propertyId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    return res.body;
  }

  Future<Map<String, Object?>> animalDossier(String animalId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/reports/animals/$animalId.json'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    return (jsonDecode(res.body) as Map).cast<String, Object?>();
  }

  Future<List<int>> animalDossierPdf(String animalId) async {
    final res = await _client
        .get(
          Uri.parse('$baseUrl/v1/reports/animals/$animalId.pdf'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    _checkUnauthorized(res);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  Future<void> createPaddock(
    String propertyId,
    String name,
    List<List<double>> points,
  ) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v1/properties/$propertyId/paddocks'),
          headers: {'content-type': 'application/json', ..._headers},
          body: jsonEncode({
            'name': name,
            'points': points
                .map((point) => {'x': point[0], 'y': point[1]})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    _checkUnauthorized(res);
    if (res.statusCode != 201) {
      throw http.ClientException('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<AccessRole>> adminRoles() async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/admin/roles'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _expectSuccess(res);
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data
        .whereType<Map>()
        .map(
          (role) => AccessRole(
            code: role['code'] as String,
            name: role['name'] as String,
            description: role['description'] as String,
          ),
        )
        .toList();
  }

  Future<List<ManagedUser>> adminUsers() async {
    final res = await _client
        .get(Uri.parse('$baseUrl/v1/admin/users'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _expectSuccess(res);
    final data = (jsonDecode(res.body) as Map)['data'] as List;
    return data.whereType<Map>().map(_managedUserFromJson).toList();
  }

  Future<ManagedUser> createAdminUser({
    required String name,
    required String email,
    required List<String> roles,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/v1/admin/users'),
          headers: {'content-type': 'application/json', ..._headers},
          body: jsonEncode({'name': name, 'email': email, 'roles': roles}),
        )
        .timeout(const Duration(seconds: 10));
    _expectSuccess(res);
    return _managedUserFromJson((jsonDecode(res.body) as Map)['data'] as Map);
  }

  Future<ManagedUser> updateAdminUser(
    String userId, {
    String? name,
    String? email,
    String? status,
    List<String>? roles,
  }) async {
    final res = await _client
        .patch(
          Uri.parse('$baseUrl/v1/admin/users/$userId'),
          headers: {'content-type': 'application/json', ..._headers},
          body: jsonEncode({
            'name': ?name,
            'email': ?email,
            'status': ?status,
            'roles': ?roles,
          }),
        )
        .timeout(const Duration(seconds: 10));
    _expectSuccess(res);
    return _managedUserFromJson((jsonDecode(res.body) as Map)['data'] as Map);
  }

  void _expectSuccess(http.Response response) {
    _checkUnauthorized(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Não foi possível concluir esta alteração.';
    try {
      final body = jsonDecode(response.body) as Map;
      final raw = body['message'];
      if (raw is String && raw.isNotEmpty) message = raw;
    } catch (_) {
      // Resposta sem JSON: mantém a mensagem amigável e estável.
    }
    throw AdminApiException(message, response.statusCode);
  }

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode != 401) return;
    onUnauthorized?.call();
    throw const SessionExpiredException();
  }

  void close() => _client.close();
}

class AdminApiException implements Exception {
  const AdminApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Sua sessão terminou. Entre novamente para continuar.';
}

ManagedUser _managedUserFromJson(Map raw) => ManagedUser(
  id: raw['id'] as String,
  name: raw['name'] as String,
  email: (raw['email'] as String?) ?? 'sem e-mail',
  status: raw['status'] as String,
  roles: ((raw['roles'] as List?) ?? const []).whereType<String>().toList(),
  createdAt: DateTime.parse(raw['createdAt'] as String).toLocal(),
);

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
    status: _statusFrom(
      j['lifecycleStatus'] as String?,
      quarantined:
          withdrawal != null &&
          DateTime.parse(withdrawal).isAfter(DateTime.now()),
    ),
    lastWeightKg: _toDouble(j['lastWeightKg']) ?? 0,
    gmdKgDay: _toDouble(j['gmdKgDay']) ?? 0,
    withdrawalUntil: withdrawal == null ? null : DateTime.parse(withdrawal),
    paddockId: j['paddockId'] as String?,
    damId: j['damId'] as String?,
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

String? _formatOfficial(String? raw) => raw == null ? null : _formatRfid(raw);

String _breedLabel(String? code) => switch (code) {
  'NELORE' => 'Nelore',
  'ABERDEEN' => 'Aberdeen',
  'ANGUS' => 'Angus',
  null => '—',
  _ => code[0] + code.substring(1).toLowerCase(),
};

/// Lança quando o servidor recusa um contorno. Carrega o código para o app
/// poder distinguir "polígono cruzado" de "piquete não encontrado" e dizer ao
/// operador o que fazer.
class PaddockBoundaryRejected implements Exception {
  const PaddockBoundaryRejected(this.code, this.detail);

  final String code;
  final String detail;

  /// Frase para o operador — o código técnico fica para o suporte.
  String get message => switch (code) {
    'ERR-AREA-002' => 'O contorno precisa de pelo menos três pontos.',
    'ERR-AREA-003' =>
      'O contorno se cruza. Refaça o desenho sem cruzar as linhas.',
    'ERR-AREA-004' => 'Este piquete não existe mais no servidor.',
    _ => detail,
  };

  @override
  String toString() => 'PaddockBoundaryRejected($code): $detail';
}

/// Extrai o anel externo de um Polygon GeoJSON como pares
/// `[longitude, latitude]`.
///
/// O GeoJSON fecha o polígono repetindo o primeiro ponto no fim; o app trabalha
/// com o anel aberto, então a repetição é descartada — mantê-la faria o mapa
/// desenhar um vértice fantasma em cima do primeiro.
List<List<double>> parseGeoJsonRing(Object? geometry) {
  if (geometry is! Map) return const [];
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.isEmpty) return const [];

  final outerRing = coordinates.first;
  if (outerRing is! List) return const [];

  final points = <List<double>>[];
  for (final pair in outerRing) {
    if (pair is! List || pair.length < 2) continue;
    final lon = (pair[0] as num).toDouble();
    final lat = (pair[1] as num).toDouble();
    points.add([lon, lat]);
  }

  if (points.length > 1 &&
      points.first[0] == points.last[0] &&
      points.first[1] == points.last[1]) {
    points.removeLast();
  }

  return points;
}
