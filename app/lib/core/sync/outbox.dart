import 'dart:async';

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
/// PERSISTÊNCIA: esta implementação guarda em memória. O alvo da Fase 2 é
/// Drift sobre SQLite com SQLCipher (Doc 8 §2); a interface abaixo é o que o
/// restante do app enxerga, então trocar o armazenamento não toca em telas
/// nem no serviço de sincronização.
class Outbox {
  Outbox({int initialSequence = 0}) : _sequence = initialSequence;

  final List<OutboxEntry> _entries = [];
  int _sequence;

  final _controller = StreamController<void>.broadcast();

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
      ),
      kind: kind,
      subjectLabel: subjectLabel,
    );
    _entries.insert(0, entry);
    _controller.add(null);
    return entry;
  }

  void markSyncing(Iterable<OutboxEntry> batch) {
    for (final e in batch) {
      e.state = SyncState.syncing;
      e.attempts++;
    }
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
    _controller.add(null);
  }

  /// Falha de rede não é veredicto: o evento volta para a fila (Doc 8 §4).
  void requeue(Iterable<OutboxEntry> batch) {
    for (final e in batch) {
      if (e.state == SyncState.syncing) e.state = SyncState.pendingSync;
    }
    _controller.add(null);
  }

  void updateAnchor(String eventId, String txId) {
    final entry = _byId(eventId);
    if (entry == null) return;
    entry.blockchainTxId = txId;
    entry.state = SyncState.confirmedOnBlockchain;
    _controller.add(null);
  }

  OutboxEntry? _byId(String eventId) {
    for (final e in _entries) {
      if (e.eventId == eventId) return e;
    }
    return null;
  }

  void dispose() => _controller.close();
}
