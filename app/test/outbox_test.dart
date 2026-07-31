import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_app/core/sync/outbox.dart';
import 'package:traceagro_app/domain/models.dart';

void main() {
  group('Outbox', () {
    test('sequência do dispositivo é monotônica e nunca se repete', () {
      final outbox = Outbox();
      final a = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 300.0},
      );
      final b = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-2',
        subjectLabel: 'Brinco 4088',
        payload: {'weightKg': 310.0},
      );

      expect(b.envelope.deviceSequence, a.envelope.deviceSequence + 1);
      expect(a.envelope.eventId, isNot(b.envelope.eventId));
    });

    test('retoma a sequência após reinício, sem lacuna nem repetição', () {
      final outbox = Outbox(initialSequence: 4811);
      final entry = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 300.0},
      );
      expect(entry.envelope.deviceSequence, 4812);
    });

    test('adota a sequência do servidor ao reabrir, sem reusar número', () {
      // Cenário real: o app foi reaberto e a fila em memória zerou, mas o
      // servidor já aceitou eventos com sequência até 42 deste aparelho.
      // Sem adotar esse número, os próximos eventos colidiriam e voltariam
      // todos como ORDER_VIOLATION.
      final outbox = Outbox();
      outbox.adoptServerSequence(42);

      final entry = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 300.0},
      );

      expect(entry.envelope.deviceSequence, 43);
    });

    test('sequência do servidor nunca faz a contagem retroceder', () {
      final outbox = Outbox(initialSequence: 100);
      outbox.adoptServerSequence(42);
      expect(outbox.currentSequence, 100);
    });

    test('evento nasce pendente e com hash calculado', () {
      final outbox = Outbox();
      final entry = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 301.5, 'weightSource': 'SCALE', 'scaleId': 'AT-2'},
      );

      expect(entry.state, SyncState.pendingSync);
      // Mesmo vetor de api/test/vectors.json — o servidor recalcula e compara.
      expect(entry.envelope.payloadHash,
          '24d31140332a105308b38d9dfe4e927fcd6e53e3f7c7c71a415dc01a74a84aea');
    });

    test('occurredAt e recordedAt são campos distintos (R24)', () {
      final outbox = Outbox();
      final ocorrencia = DateTime.now().subtract(const Duration(hours: 6));
      final entry = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 300.0},
        occurredAt: ocorrencia,
      );

      expect(entry.envelope.occurredAt.isBefore(entry.envelope.recordedAt),
          isTrue);
    });

    test('falha de rede devolve o lote à fila, sem perder nada', () {
      final outbox = Outbox();
      final entry = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 300.0},
      );

      outbox.markSyncing([entry]);
      expect(entry.state, SyncState.syncing);
      expect(entry.attempts, 1);

      outbox.requeue([entry]);
      expect(entry.state, SyncState.pendingSync);
      expect(outbox.pending, hasLength(1));
    });

    test('veredicto de conflito tira o evento da fila e pede atenção', () {
      final outbox = Outbox();
      final entry = outbox.enqueue(
        kind: EventKind.linkIdentifier,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4310',
        payload: {'rfidCode': '982000123456789'},
      );

      outbox.markSyncing([entry]);
      outbox.applyVerdict(entry.eventId,
          state: SyncState.conflict, code: 'IDENTIFIER_TAKEN');

      expect(entry.needsAttention, isTrue);
      expect(outbox.conflictCount, 1);
      expect(outbox.pending, isEmpty);
    });

    test('confirmação de âncora registra o TxID no evento', () {
      final outbox = Outbox();
      final entry = outbox.enqueue(
        kind: EventKind.weighing,
        subjectId: 'animal-1',
        subjectLabel: 'Brinco 4127',
        payload: {'weightKg': 300.0},
      );

      outbox.applyVerdict(entry.eventId, state: SyncState.acceptedByApi);
      outbox.updateAnchor(entry.eventId, 'abc123');

      expect(entry.state, SyncState.confirmedOnBlockchain);
      expect(entry.blockchainTxId, 'abc123');
    });

    test('fila sai ordenada por sequência do dispositivo (R27)', () {
      final outbox = Outbox();
      for (var i = 0; i < 5; i++) {
        outbox.enqueue(
          kind: EventKind.weighing,
          subjectId: 'animal-$i',
          subjectLabel: 'Brinco $i',
          payload: {'weightKg': 300.0 + i},
        );
      }

      final sequences =
          outbox.pending.map((e) => e.envelope.deviceSequence).toList();
      expect(sequences, [1, 2, 3, 4, 5]);
    });
  });
}
