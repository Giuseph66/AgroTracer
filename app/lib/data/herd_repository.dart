import 'package:flutter/foundation.dart';

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
  HerdRepository({required this.api});

  final ApiClient api;

  /// Começa vazio de propósito. O rebanho que aparece na tela é o que veio do
  /// servidor (ou, na Fase 2, o que está no banco local do aparelho) — nunca
  /// um conjunto de exemplo, que daria ao operador a impressão de ter dados
  /// que ele não tem.
  List<Animal> _animals = const [];
  List<Animal> get animals => _animals;

  bool _loadedFromServer = false;
  bool get loadedFromServer => _loadedFromServer;

  bool _loading = false;
  bool get loading => _loading;

  String? _lastError;
  String? get lastError => _lastError;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _animals = await api.animals(DevIdentity.propertyId);
      _loadedFromServer = true;
      _lastError = null;
    } catch (err) {
      // Sem rede, o que já está carregado continua valendo — isso não é um
      // estado de erro para o operador, é o modo normal de trabalho no curral.
      _lastError = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
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
    );
    notifyListeners();
  }
}
