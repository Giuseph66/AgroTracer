import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models.dart';
import 'event_envelope.dart';

/// Item da fila de saída: o evento e tudo o que o app sabe sobre o destino dele.
class OutboxEntry {
  OutboxEntry({
    required this.envelope,
    required this.kind,
    required this.subjectLabel,
    this.state = SyncState.pendingSync,
    this.errorCode,
    this.errorDetail,
    this.attempts = 0,
    this.blockchainTxId,
  });

  final EventEnvelope envelope;
  final EventKind kind;

  /// Como o operador reconhece o alvo: "Brinco 4127", "Lote Recria 12".
  final String subjectLabel;

  SyncState state;
  String? errorCode;
  String? errorDetail;
  int attempts;
  String? blockchainTxId;

  String get eventId => envelope.eventId;
  DateTime get recordedAt => envelope.recordedAt.toLocal();
  bool get isPending =>
      state == SyncState.pendingSync || state == SyncState.syncing;
  bool get needsAttention =>
      state == SyncState.conflict || state == SyncState.rejectedByApi;
}

/// Fila de eventos pendentes (Doc 8 §3).
///
/// A ordem de saída é a da sequência do dispositivo, que é monotônica e nunca
/// reutilizada — é ela, não o relógio, que define a ordem de processamento no
/// servidor (R27).
///
/// PERSISTÊNCIA: a fila é restaurada e gravada localmente via
/// SharedPreferences. O alvo de produção é Drift sobre SQLite com SQLCipher
/// (Doc 8 §2); a interface abaixo permanece estável para telas e sincronização.
class Outbox {
  Outbox({int initialSequence = 0}) : _sequence = initialSequence;

  final List<OutboxEntry> _entries = [];
  int _sequence;
  EventIdentity _identity = DevIdentity.defaultIdentity;

  final _controller = StreamController<void>.broadcast();
  static const _storageKey = 'traceagro.outbox.v1';

  /// Restaura fila e contador antes do serviço de sync iniciar.
  Future<void> restore() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final saved = jsonDecode(raw) as Map;
      _sequence = _max(_sequence, (saved['sequence'] as num?)?.toInt() ?? 0);
      final rawEntries = saved['entries'];
      if (rawEntries is! List) return;
      _entries
        ..clear()
        ..addAll(rawEntries.whereType<Map>().map(_entryFromJson));
      _controller.add(null);
    } catch (_) {
      // Captura nova continua possível se um dado local antigo corrompeu.
      await prefs?.remove(_storageKey);
    }
  }

  /// Emite a cada mudança para que as telas reajam sem polling.
  Stream<void> get changes => _controller.stream;

  List<OutboxEntry> get entries => List.unmodifiable(_entries);

  List<OutboxEntry> get pending =>
      _entries.where((e) => e.state == SyncState.pendingSync).toList()
        ..sort((a, b) =>
            a.envelope.deviceSequence.compareTo(b.envelope.deviceSequence));

  int get pendingCount => _entries.where((e) => e.isPending).length;
  int get conflictCount =>
      _entries.where((e) => e.state == SyncState.conflict).length;

  /// Próximo número de sequência do dispositivo. Persistido junto com o evento
  /// na mesma transação para não haver lacuna nem repetição após reinício.
  int nextSequence() => ++_sequence;

  int get currentSequence => _sequence;
  EventIdentity get identity => _identity;

  /// A sessão nova vale para eventos futuros; o histórico local mantém a
  /// identidade original com que cada evento foi criado.
  void setIdentity(EventIdentity identity) {
    _identity = identity;
    _controller.add(null);
  }

  /// Retoma a contagem a partir da última sequência que o servidor aceitou
  /// deste aparelho. Sem isso, um app reinstalado (ou apenas reaberto, com a
  /// fila em memória) recomeçaria do zero e todo evento seria recusado com
  /// ORDER_VIOLATION por colidir com números já usados (Doc 8 §3).
  ///
  /// Só avança: um valor menor que o local seria retrocesso e reabriria a
  /// possibilidade de reutilizar número.
  void adoptServerSequence(int lastAcceptedSequence) {
    if (lastAcceptedSequence > _sequence) {
      _sequence = lastAcceptedSequence;
      unawaited(_persist());
      _controller.add(null);
    }
  }

  OutboxEntry enqueue({
    required EventKind kind,
    required String subjectId,
    required String subjectLabel,
    required Map<String, Object?> payload,
    String? animalId,
    DateTime? occurredAt,
    String subjectType = 'ANIMAL',
  }) {
    final entry = OutboxEntry(
      envelope: EventEnvelope.create(
        kind: kind,
        subjectId: subjectId,
        animalId: animalId,
        deviceSequence: nextSequence(),
        payload: payload,
        occurredAt: occurredAt,
        subjectType: subjectType,
        identity: _identity,
      ),
      kind: kind,
      subjectLabel: subjectLabel,
    );
    _entries.insert(0, entry);
    unawaited(_persist());
    _controller.add(null);
    return entry;
  }

  void markSyncing(Iterable<OutboxEntry> batch) {
    for (final e in batch) {
      e.state = SyncState.syncing;
      e.attempts++;
    }
    unawaited(_persist());
    _controller.add(null);
  }

  void applyVerdict(
    String eventId, {
    required SyncState state,
    String? code,
    String? detail,
  }) {
    final entry = _byId(eventId);
    if (entry == null) return;
    entry.state = state;
    entry.errorCode = code;
    entry.errorDetail = detail;
    unawaited(_persist());
    _controller.add(null);
  }

  /// Falha de rede não é veredicto: o evento volta para a fila (Doc 8 §4).
  void requeue(Iterable<OutboxEntry> batch) {
    for (final e in batch) {
      if (e.state == SyncState.syncing) e.state = SyncState.pendingSync;
    }
    unawaited(_persist());
    _controller.add(null);
  }

  void updateAnchor(String eventId, String txId) {
    final entry = _byId(eventId);
    if (entry == null) return;
    entry.blockchainTxId = txId;
    entry.state = SyncState.confirmedOnBlockchain;
    unawaited(_persist());
    _controller.add(null);
  }

  OutboxEntry? _byId(String eventId) {
    for (final e in _entries) {
      if (e.eventId == eventId) return e;
    }
    return null;
  }

  void dispose() => _controller.close();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'sequence': _sequence,
          'entries': _entries.map(_entryToJson).toList(),
        }),
      );
    } catch (_) {
      // WidgetsBinding ainda não inicializado em testes puros, ou storage
      // indisponível: a fila em memória continua válida nesta sessão.
    }
  }

  /// Sincroniza o snapshot em testes e no ciclo de fechamento do app.
  Future<void> flush() => _persist();
}

Map<String, Object?> _entryToJson(OutboxEntry entry) => {
      'envelope': entry.envelope.toJson(),
      'kind': entry.kind.wireName,
      'subjectLabel': entry.subjectLabel,
      'state': entry.state.name,
      'errorCode': entry.errorCode,
      'errorDetail': entry.errorDetail,
      'attempts': entry.attempts,
      'blockchainTxId': entry.blockchainTxId,
    };

OutboxEntry _entryFromJson(Map raw) {
  final envelope = EventEnvelope.fromJson(
      (raw['envelope'] as Map).cast<String, Object?>());
  final savedState = _syncStateFromName(raw['state'] as String?);
  return OutboxEntry(
    envelope: envelope,
    kind: EventKind.fromWire(raw['kind'] as String) ?? EventKind.corrected,
    subjectLabel: raw['subjectLabel'] as String,
    // Encerrar o processo durante HTTP não pode deixar o evento preso em
    // SYNCING para sempre; na reabertura ele volta ao FIFO.
    state: savedState == SyncState.syncing ? SyncState.pendingSync : savedState,
    errorCode: raw['errorCode'] as String?,
    errorDetail: raw['errorDetail'] as String?,
    attempts: (raw['attempts'] as num?)?.toInt() ?? 0,
    blockchainTxId: raw['blockchainTxId'] as String?,
  );
}

SyncState _syncStateFromName(String? name) => SyncState.values.firstWhere(
      (state) => state.name == name,
      orElse: () => SyncState.pendingSync,
    );

int _max(int a, int b) => a > b ? a : b;
