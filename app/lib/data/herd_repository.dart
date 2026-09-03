import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/sync/event_envelope.dart';
import '../domain/models.dart';
import 'api_client.dart';

/// Resultado de uma consulta de histórico. Distingue "não há eventos" de
/// "não deu para saber" — na rastreabilidade, essas duas coisas não podem
/// aparecer iguais para quem lê a ficha.
class TimelineResult {
  const TimelineResult({required this.events, this.unreachable = false});

  final List<TraceEvent> events;
  final bool unreachable;
}

/// Fonte de dados do rebanho para as telas.
///
/// Offline-first de verdade significa que a tela nunca fica em branco por falta
/// de rede: o cache local responde primeiro e o pull da API atualiza depois.
/// Enquanto o banco local (Drift) não entra, o "cache" é a base de demonstração
/// — o contrato visto pelas telas já é o definitivo.
class HerdRepository extends ChangeNotifier {
  HerdRepository({required this.api, this.propertyIdProvider});

  String get _storageKey => 'traceagro.herd-cache.v2.$propertyId';

  final ApiClient api;
  final String Function()? propertyIdProvider;

  String get propertyId => propertyIdProvider?.call() ?? DevIdentity.propertyId;

  /// Começa vazio de propósito. O rebanho que aparece na tela é o que veio do
  /// servidor (ou, na Fase 2, o que está no banco local do aparelho) — nunca
  /// um conjunto de exemplo, que daria ao operador a impressão de ter dados
  /// que ele não tem.
  List<Animal> _animals = const [];
  List<Animal> get animals => _animals;

  List<VetProduct> _vetProducts = const [];
  List<VetProduct> get vetProducts => _vetProducts;

  List<Paddock> _paddocks = const [];
  List<Paddock> get paddocks => _paddocks;

  List<Shipment> _shipments = const [];
  List<Shipment> get shipments => _shipments;

  bool _loadedFromServer = false;
  bool get loadedFromServer => _loadedFromServer;

  bool _loading = false;
  bool get loading => _loading;

  String? _lastError;
  String? get lastError => _lastError;

  void resetSession() {
    _animals = const [];
    _vetProducts = const [];
    _paddocks = const [];
    _shipments = const [];
    _loadedFromServer = false;
    _loading = false;
    _lastError = null;
    notifyListeners();
  }

  Future<void> restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final cache = jsonDecode(raw) as Map;
      _animals = ((cache['animals'] as List?) ?? const [])
          .whereType<Map>()
          .map((j) => _animalFromCache(j.cast<String, Object?>()))
          .toList();
      _vetProducts = ((cache['vetProducts'] as List?) ?? const [])
          .whereType<Map>()
          .map((j) => _productFromCache(j.cast<String, Object?>()))
          .toList();
      _paddocks = ((cache['paddocks'] as List?) ?? const [])
          .whereType<Map>()
          .map((j) => _paddockFromCache(j.cast<String, Object?>()))
          .toList();
      _shipments = ((cache['shipments'] as List?) ?? const [])
          .whereType<Map>()
          .map((j) => _shipmentFromCache(j.cast<String, Object?>()))
          .toList();
      if (_animals.isNotEmpty) _loadedFromServer = false;
      notifyListeners();
    } catch (_) {
      // Cache corrompido não impede uma nova leitura do servidor.
    }
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _animals = await api.animals(propertyId);
      // Catálogo e áreas são dados de apoio; uma falha neles não deve esconder
      // o rebanho já baixado.
      try {
        _vetProducts = await api.vetProducts();
        _paddocks = await api.paddocks(propertyId);
        _shipments = await api.shipments(propertyId);
      } catch (_) {
        // Mantém o último cache conhecido.
      }
      _loadedFromServer = true;
      _lastError = null;
      await _persistCache();
    } catch (err) {
      // Sem rede, o que já está carregado continua valendo — isso não é um
      // estado de erro para o operador, é o modo normal de trabalho no curral.
      _lastError = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCatalog() async {
    _vetProducts = await api.vetProducts();
    await _persistCache();
    notifyListeners();
  }

  Future<void> refreshAreas() async {
    _paddocks = await api.paddocks(propertyId);
    await _persistCache();
    notifyListeners();
  }

  Future<void> refreshShipments() async {
    _shipments = await api.shipments(propertyId);
    await _persistCache();
    notifyListeners();
  }

  /// Histórico do animal.
  ///
  /// Nunca completa com dados de exemplo quando o servidor não responde: uma
  /// ficha de rastreabilidade que exibe evento inventado é pior do que uma
  /// ficha vazia. Sem rede, a tela diz que não conseguiu carregar; quando o
  /// banco local entrar (Fase 2), o cache do próprio aparelho é que responde.
  Future<TimelineResult> timeline(String animalId) async {
    try {
      return TimelineResult(events: await api.timeline(animalId));
    } catch (err) {
      return TimelineResult(events: const [], unreachable: true);
    }
  }

  Animal? byRfid(String rfid) {
    final normalized = rfid.replaceAll(' ', '');
    for (final a in _animals) {
      if (a.rfidCode.replaceAll(' ', '') == normalized) return a;
    }
    return null;
  }

  Animal? byId(String animalId) {
    for (final a in _animals) {
      if (a.animalId == animalId) return a;
    }
    return null;
  }

  /// Aplica localmente o efeito de uma pesagem recém-registrada, para que a
  /// tela reflita o fato imediatamente — o servidor recalcula o oficial (R9).
  void applyLocalWeighing(String animalId, double weightKg) {
    final index = _animals.indexWhere((a) => a.animalId == animalId);
    if (index < 0) return;
    final a = _animals[index];
    _animals = [..._animals];
    _animals[index] = Animal(
      animalId: a.animalId,
      visualTagNumber: a.visualTagNumber,
      rfidCode: a.rfidCode,
      officialAnimalId: a.officialAnimalId,
      sex: a.sex,
      breed: a.breed,
      ageMonths: a.ageMonths,
      lot: a.lot,
      status: a.status,
      lastWeightKg: weightKg,
      gmdKgDay: a.gmdKgDay,
      withdrawalUntil: a.withdrawalUntil,
      paddockId: a.paddockId,
      damId: a.damId,
    );
    _persistCache();
    notifyListeners();
  }

  /// Aplica localmente um animal recém-cadastrado, ainda pendente na fila —
  /// sem isso, o rebanho offline não sabe que ele existe até o evento
  /// sincronizar: nem a leitura por RFID nem a lista o encontram enquanto o
  /// aparelho estiver sem rede, e o operador acaba cadastrando o mesmo
  /// brinco de novo a cada leitura (visto com hardware real: 3 cadastros
  /// duplicados do mesmo RFID na fila, porque cada bip continuava "desconhecido").
  void applyLocalRegistration({
    required String animalId,
    required String visualTagNumber,
    String? rfidCode,
    String? officialAnimalId,
    required String sex,
    required String breed,
    required DateTime birthDate,
    String? lot,
  }) {
    if (_animals.any((a) => a.animalId == animalId)) return;
    final ageMonths = DateTime.now().difference(birthDate).inDays ~/ 30;
    _animals = [
      ..._animals,
      Animal(
        animalId: animalId,
        visualTagNumber: visualTagNumber,
        rfidCode: rfidCode ?? '',
        officialAnimalId: officialAnimalId,
        sex: sex,
        breed: breed,
        ageMonths: ageMonths < 0 ? 0 : ageMonths,
        lot: lot ?? '',
        status: LifecycleStatus.active,
        lastWeightKg: 0,
        gmdKgDay: 0,
      ),
    ];
    _persistCache();
    notifyListeners();
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'animals': _animals.map(_animalToCache).toList(),
          'vetProducts': _vetProducts.map(_productToCache).toList(),
          'paddocks': _paddocks.map(_paddockToCache).toList(),
          'shipments': _shipments.map(_shipmentToCache).toList(),
        }),
      );
    } catch (_) {
      // O cache é uma otimização; a sessão em memória continua funcionando.
    }
  }
}

Map<String, Object?> _animalToCache(Animal a) => {
  'animalId': a.animalId,
  'visualTagNumber': a.visualTagNumber,
  'rfidCode': a.rfidCode,
  'officialAnimalId': a.officialAnimalId,
  'sex': a.sex,
  'breed': a.breed,
  'ageMonths': a.ageMonths,
  'lot': a.lot,
  'status': a.status.name,
  'lastWeightKg': a.lastWeightKg,
  'gmdKgDay': a.gmdKgDay,
  'withdrawalUntil': a.withdrawalUntil?.toIso8601String(),
  'paddockId': a.paddockId,
  'damId': a.damId,
};

Animal _animalFromCache(Map<String, Object?> j) => Animal(
  animalId: j['animalId'] as String,
  visualTagNumber: j['visualTagNumber'] as String,
  rfidCode: j['rfidCode'] as String,
  officialAnimalId: j['officialAnimalId'] as String?,
  sex: j['sex'] as String,
  breed: j['breed'] as String,
  ageMonths: (j['ageMonths'] as num?)?.toInt() ?? 0,
  lot: j['lot'] as String,
  status: LifecycleStatus.values.firstWhere(
    (s) => s.name == j['status'],
    orElse: () => LifecycleStatus.active,
  ),
  lastWeightKg: (j['lastWeightKg'] as num?)?.toDouble() ?? 0,
  gmdKgDay: (j['gmdKgDay'] as num?)?.toDouble() ?? 0,
  withdrawalUntil: j['withdrawalUntil'] == null
      ? null
      : DateTime.parse(j['withdrawalUntil'] as String),
  paddockId: j['paddockId'] as String?,
  damId: j['damId'] as String?,
);

Map<String, Object?> _productToCache(VetProduct p) => {
  'code': p.code,
  'name': p.name,
  'activeIngredient': p.activeIngredient,
  'withdrawalSlaughterDays': p.withdrawalSlaughterDays,
  'withdrawalMilkDays': p.withdrawalMilkDays,
};

VetProduct _productFromCache(Map<String, Object?> j) => VetProduct(
  code: j['code'] as String,
  name: j['name'] as String,
  activeIngredient: j['activeIngredient'] as String?,
  withdrawalSlaughterDays: (j['withdrawalSlaughterDays'] as num?)?.toInt() ?? 0,
  withdrawalMilkDays: (j['withdrawalMilkDays'] as num?)?.toInt() ?? 0,
);

Map<String, Object?> _paddockToCache(Paddock p) => {
  'id': p.id,
  'name': p.name,
  'areaHa': p.areaHa,
  'animalCount': p.animalCount,
  'alertCount': p.alertCount,
  // O contorno vai para o cache: sem ele o mapa da propriedade ficaria
  // vazio justamente quando não há rede, que é quando o operador está no
  // campo precisando dele.
  'boundary': p.boundary,
  'version': p.version,
};

Paddock _paddockFromCache(Map<String, Object?> j) => Paddock(
  id: j['id'] as String,
  name: j['name'] as String,
  areaHa: (j['areaHa'] as num?)?.toDouble() ?? 0,
  animalCount: (j['animalCount'] as num?)?.toInt() ?? 0,
  alertCount: (j['alertCount'] as num?)?.toInt() ?? 0,
  boundary: ((j['boundary'] as List?) ?? const [])
      .map((pair) => (pair as List).map((v) => (v as num).toDouble()).toList())
      .toList(),
  version: (j['version'] as num?)?.toInt() ?? 1,
);

Map<String, Object?> _shipmentToCache(Shipment s) => {
  'shipmentId': s.shipmentId,
  'purpose': s.purpose,
  'status': s.status,
  'animalCount': s.animalCount,
  'receivedCount': s.receivedCount,
  'discrepancyCount': s.discrepancyCount,
  'vehiclePlate': s.vehiclePlate,
  'gtaNumber': s.gtaNumber,
};

Shipment _shipmentFromCache(Map<String, Object?> j) => Shipment(
  shipmentId: j['shipmentId'] as String,
  purpose: j['purpose'] as String,
  status: j['status'] as String,
  animalCount: (j['animalCount'] as num?)?.toInt() ?? 0,
  receivedCount: (j['receivedCount'] as num?)?.toInt() ?? 0,
  discrepancyCount: (j['discrepancyCount'] as num?)?.toInt() ?? 0,
  vehiclePlate: j['vehiclePlate'] as String?,
  gtaNumber: j['gtaNumber'] as String?,
);
