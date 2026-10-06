import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// O que falta enviar, dito como trabalho e não como sistema: "esperando
/// internet", "precisa da sua atenção", "tudo enviado". Sem internet não é
/// erro — é o modo normal do campo, então o tom fica neutro.
class TaskStatusCard extends StatelessWidget {
  const TaskStatusCard({
    super.key,
    required this.pending,
    required this.conflicts,
    required this.online,
    required this.onSend,
    required this.onResolve,
  });

  final int pending;
  final int conflicts;
  final bool online;
  final VoidCallback onSend;
  final VoidCallback onResolve;

  static String _records(int n) => n == 1 ? '1 registro' : '$n registros';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final (IconData icon, Color fg, Color bg, String title, String? body) =
        conflicts > 0
        ? (
            Icons.priority_high,
            TaColors.clay,
            TaColors.clayBg,
            conflicts == 1
                ? '1 registro precisa da sua atenção'
                : '${_records(conflicts)} precisam da sua atenção',
            pending > 0
                ? '${_records(pending)} esperando envio'
                : 'O resto já foi enviado.',
          )
        : pending > 0
        ? (
            online ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
            online ? TaColors.sky : TaColors.inkSoft,
            online ? TaColors.skyBg : TaColors.paper,
            online
                ? 'Enviando ${_records(pending)}'
                : '${_records(pending)} esperando internet',
            online
                ? null
                : 'Ficam salvos neste aparelho e sobem sozinhos quando a '
                      'internet voltar.',
          )
        : (
            Icons.check_circle_outline,
            TaColors.sage,
            TaColors.sageBg,
            'Tudo enviado',
            null,
          );

    final Widget? action = conflicts > 0
        ? FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TaColors.clay,
              foregroundColor: Colors.white,
            ),
            onPressed: onResolve,
            child: const Text('Resolver'),
          )
        : pending > 0
        ? OutlinedButton(onPressed: onSend, child: const Text('Tentar enviar'))
        : null;

    return Container(
      padding: const EdgeInsets.all(TaSpace.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(TaRadius.rLg),
        border: Border.all(color: conflicts > 0 ? TaColors.clay : TaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 30, color: fg),
              const SizedBox(width: TaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.titleMedium!.copyWith(
                        color: conflicts > 0 ? TaColors.clay : TaColors.ink,
                      ),
                    ),
                    if (body != null) Text(body, style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: TaSpace.sm), action],
        ],
      ),
    );
  }
}
