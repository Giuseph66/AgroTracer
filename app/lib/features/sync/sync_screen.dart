import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';

/// Central de sincronização — a fila de saída (Doc 8 §3) visível ao operador:
/// o que espera, o que subiu, o que precisa de decisão humana.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: StreamBuilder<void>(
        stream: services.outbox.changes,
        builder: (context, _) {
          final entries = services.outbox.entries;
          final conflicts = entries.where((e) => e.needsAttention).toList();
          final queue = entries.where((e) => !e.needsAttention).toList();

          return ListView(
            padding: const EdgeInsets.all(TaSpace.md),
            children: [
              Text('Sincronização', style: t.displayMedium),
              const SizedBox(height: TaSpace.md),
              ListenableBuilder(
                listenable: services.sync,
                builder: (context, _) =>
                    _ConnectionCard(sync: services.sync, pending: services.outbox.pendingCount),
              ),
              if (conflicts.isNotEmpty) ...[
                const SizedBox(height: TaSpace.lg),
                const SectionLabel('Precisam de você'),
                const SizedBox(height: TaSpace.sm),
                for (final item in conflicts) _ConflictCard(entry: item),
              ],
              const SizedBox(height: TaSpace.lg),
              const SectionLabel('Fila de envio'),
              const SizedBox(height: TaSpace.sm),
              if (queue.isEmpty)
                TaCard(
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                        color: TaColors.sage),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: Text('Nada pendente. Tudo o que foi registrado '
                          'neste aparelho já subiu.',
                          style: t.bodyMedium),
                    ),
                  ]),
                )
              else
                TaCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: TaSpace.md),
                  child: Column(
                    children: [
                      for (var i = 0; i < queue.length; i++) ...[
                        _QueueTile(entry: queue[i]),
                        if (i != queue.length - 1) const Divider(),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.sync, required this.pending});
  final SyncService sync;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, title, body) = switch (sync.connectivity) {
      ConnectivityState.online => (
          Icons.cloud_done_outlined,
          'Conectado',
          sync.lastSyncAt == null
              ? 'Pronto para enviar.'
              : 'Última sincronização às ${hourFmt.format(sync.lastSyncAt!)}.',
        ),
      ConnectivityState.syncing => (
          Icons.sync,
          'Enviando registros',
          '$pending na fila.',
        ),
      ConnectivityState.offline => (
          Icons.cloud_off_outlined,
          'Sem conexão agora',
          'Os registros estão seguros no aparelho e sobem sozinhos quando a '
              'rede voltar.',
        ),
    };

    return TaCard(
      child: Row(
        children: [
          Icon(icon, size: 28, color: TaColors.inkSoft),
          const SizedBox(width: TaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                Text(body, style: t.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: sync.sync,
            icon: const Icon(Icons.refresh),
            tooltip: 'Enviar agora',
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.entry});
  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.kind.label, style: t.titleMedium),
                Text(entry.subjectLabel, style: t.bodySmall),
                Text(
                  entry.blockchainTxId != null
                      ? 'prova ${entry.blockchainTxId!.substring(0, 12)}…'
                      : dayHourFmt.format(entry.recordedAt),
                  style: t.labelSmall,
                ),
              ],
            ),
          ),
          SyncBadge(entry.state),
        ],
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.entry});
  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rejected = entry.state == SyncState.rejectedByApi;

    return Container(
      margin: const EdgeInsets.only(bottom: TaSpace.sm),
      padding: const EdgeInsets.all(TaSpace.md),
      decoration: const BoxDecoration(
        color: TaColors.clayBg,
        borderRadius: BorderRadius.all(TaRadius.rLg),
        border: Border.fromBorderSide(BorderSide(color: TaColors.clay)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${entry.kind.label} · ${entry.subjectLabel}',
              style: t.titleMedium!.copyWith(color: TaColors.clay)),
          if (entry.errorCode != null)
            Text(entry.errorCode!,
                style: t.labelSmall!.copyWith(color: TaColors.clay)),
          const SizedBox(height: 4),
          Text(
            entry.errorDetail ??
                (rejected
                    ? 'O servidor recusou este registro. Refaça a operação.'
                    : 'Este registro conflita com o estado atual. Escolha '
                        'manter, corrigir ou descartar.'),
            style: t.bodyMedium,
          ),
          const SizedBox(height: TaSpace.sm),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: TaColors.clay,
                    foregroundColor: Colors.white),
                onPressed: () => _openResolve(context, entry),
                child: Text(rejected ? 'Refazer' : 'Resolver'),
              ),
              const SizedBox(width: TaSpace.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: const BorderSide(color: TaColors.clay),
                    foregroundColor: TaColors.clay),
                onPressed: () => _openDetails(context, entry),
                child: const Text('Ver detalhes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// O que o servidor respondeu, inteiro. Sem isso o operador vê só o código do
/// erro e não tem como saber qual registro do campo está travado.
Future<void> _openDetails(BuildContext context, OutboxEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = Theme.of(sheetContext).textTheme;
      final e = entry.envelope;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TaSpace.md),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('${entry.kind.label} · ${entry.subjectLabel}',
                  style: t.headlineMedium),
              const SizedBox(height: TaSpace.md),
              if (entry.errorCode != null) ...[
                Text(entry.errorCode!,
                    style: t.labelMedium!.copyWith(color: TaColors.clay)),
                const SizedBox(height: 4),
              ],
              if (entry.errorDetail != null)
                Text(entry.errorDetail!, style: t.bodyMedium),
              const SizedBox(height: TaSpace.lg),
              const SectionLabel('Registro'),
              const SizedBox(height: TaSpace.sm),
              _DetailRow(label: 'Evento', value: e.eventId),
              _DetailRow(label: 'Tipo', value: e.eventType),
              _DetailRow(label: 'Sequência', value: '${e.deviceSequence}'),
              _DetailRow(
                  label: 'Registrado em',
                  value: dayHourFmt.format(entry.recordedAt)),
              _DetailRow(label: 'Tentativas', value: '${entry.attempts}'),
              _DetailRow(label: 'Hash', value: e.payloadHash),
              const SizedBox(height: TaSpace.lg),
              const SectionLabel('Conteúdo enviado'),
              const SizedBox(height: TaSpace.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(TaSpace.sm),
                decoration: BoxDecoration(
                  color: TaColors.paperDim,
                  borderRadius: BorderRadius.circular(TaRadius.sm),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(e.payload),
                  style: t.labelSmall,
                ),
              ),
              const SizedBox(height: TaSpace.md),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Conflito é veredicto definitivo do servidor, não falha de rede: reenviar
/// sozinho nunca resolve. Aqui o operador decide — e as duas saídas dizem o
/// que acontece antes de acontecer.
Future<void> _openResolve(BuildContext context, OutboxEntry entry) async {
  final services = Services.of(context);
  final rejected = entry.state == SyncState.rejectedByApi;

  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TaSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(rejected ? 'Registro recusado' : 'Registro em conflito',
                  style: t.headlineMedium),
              const SizedBox(height: TaSpace.sm),
              Text(
                entry.errorDetail ??
                    'O servidor não aceitou este registro do jeito que ele '
                        'está.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: TaSpace.lg),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop('retry'),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Tentar enviar de novo'),
              ),
              const SizedBox(height: TaSpace.xs),
              Text(
                'Serve quando a causa já foi resolvida de outro jeito. '
                'Reenviar o mesmo registro é seguro: o servidor reconhece '
                'que é o mesmo e não duplica.',
                style: t.bodySmall,
              ),
              const SizedBox(height: TaSpace.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: TaColors.clay),
                  foregroundColor: TaColors.clay,
                ),
                onPressed: () => Navigator.of(sheetContext).pop('discard'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Descartar este registro'),
              ),
              const SizedBox(height: TaSpace.xs),
              Text(
                'Tira da fila deste aparelho. O que foi digitado no campo se '
                'perde; o conflito continua registrado no servidor.',
                style: t.bodySmall,
              ),
              const SizedBox(height: TaSpace.md),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Deixar como está'),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  if (action == 'retry') {
    services.outbox.retry(entry.eventId);
    unawaited(services.sync.sync());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro devolvido para a fila')),
    );
  } else if (action == 'discard') {
    services.outbox.discard(entry.eventId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro descartado deste aparelho')),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: t.bodySmall),
          ),
          Expanded(child: Text(value, style: t.labelSmall)),
        ],
      ),
    );
  }
}
