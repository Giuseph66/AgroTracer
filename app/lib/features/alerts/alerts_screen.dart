import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../animal/animal_screen.dart';
import '../shipment/shipment_screen.dart';

/// Alertas: só o que o aparelho já sabe de fato — carência ativa, registros
/// que precisam de decisão e embarques esperando recebimento. Nada estimado
/// nem de exemplo (D3, AGENTS §2.5-4).
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({
    super.key,
    this.onOpenPending,
    this.canOpenShipments = false,
  });

  /// Leva à aba de pendências do shell (fecha esta tela antes).
  final VoidCallback? onOpenPending;

  /// Só quem pode abrir embarques ganha o atalho.
  final bool canOpenShipments;

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        backgroundColor: TaColors.pasture,
        foregroundColor: TaColors.paperInk,
      ),
      body: StreamBuilder<void>(
        stream: services.outbox.changes,
        builder: (context, _) => ListenableBuilder(
          listenable: services.herd,
          builder: (context, _) {
            final now = DateTime.now();
            final withdrawals =
                services.herd.animals
                    .where((a) => a.withdrawalUntil?.isAfter(now) ?? false)
                    .toList()
                  ..sort(
                    (a, b) => a.withdrawalUntil!.compareTo(b.withdrawalUntil!),
                  );
            final conflicts = services.outbox.conflictCount;
            final awaiting = services.herd.shipments
                .where((s) => s.status == 'DISPATCHED')
                .length;
            final nothing =
                withdrawals.isEmpty && conflicts == 0 && awaiting == 0;

            return ListView(
              padding: const EdgeInsets.all(TaSpace.md),
              children: [
                if (conflicts > 0) ...[
                  const SectionLabel('Precisam de você'),
                  const SizedBox(height: TaSpace.sm),
                  _AlertRow(
                    icon: Icons.priority_high,
                    color: TaColors.clay,
                    title: conflicts == 1
                        ? '1 registro não foi aceito'
                        : '$conflicts registros não foram aceitos',
                    subtitle: 'Abra as pendências para resolver.',
                    onTap: onOpenPending == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onOpenPending!();
                          },
                  ),
                  const SizedBox(height: TaSpace.lg),
                ],
                if (withdrawals.isNotEmpty) ...[
                  SectionLabel('Carência ativa · ${withdrawals.length}'),
                  const SizedBox(height: TaSpace.sm),
                  for (final animal in withdrawals)
                    _AlertRow(
                      icon: Icons.timer_outlined,
                      color: TaColors.clay,
                      title: 'Brinco ${animal.visualTagNumber}',
                      subtitle: _withdrawalText(animal.withdrawalUntil!, now),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnimalScreen(animal: animal),
                        ),
                      ),
                    ),
                  const SizedBox(height: TaSpace.lg),
                ],
                if (awaiting > 0) ...[
                  const SectionLabel('Embarques'),
                  const SizedBox(height: TaSpace.sm),
                  _AlertRow(
                    icon: Icons.local_shipping_outlined,
                    color: TaColors.sky,
                    title: awaiting == 1
                        ? '1 embarque esperando recebimento'
                        : '$awaiting embarques esperando recebimento',
                    subtitle: 'Confira os animais na chegada.',
                    onTap: canOpenShipments
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShipmentScreen(),
                            ),
                          )
                        : null,
                  ),
                ],
                if (nothing) _Empty(services: services, textTheme: t),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _withdrawalText(DateTime until, DateTime now) {
    final days = until.difference(now).inDays;
    final left = days <= 0
        ? 'termina hoje'
        : (days == 1 ? 'falta 1 dia' : 'faltam $days dias');
    return 'Não pode ir para abate até ${dayFmt.format(until)} · $left';
  }
}

/// Sem alerta tem duas leituras diferentes: está tudo bem, ou o aparelho ainda
/// não tem o rebanho para saber.
class _Empty extends StatelessWidget {
  const _Empty({required this.services, required this.textTheme});
  final AppServices services;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (services.herd.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: TaSpace.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final unknown =
        !services.herd.loadedFromServer && services.herd.animals.isEmpty;
    return TaCard(
      child: Row(
        children: [
          Icon(
            unknown ? Icons.cloud_off_outlined : Icons.check_circle_outline,
            color: unknown ? TaColors.inkSoft : TaColors.sage,
          ),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Text(
              unknown
                  ? 'O rebanho ainda não foi baixado para este aparelho. '
                        'Conecte-se uma vez para ver os alertas.'
                  : 'Nenhum alerta agora.',
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: TaSpace.sm),
      child: TaCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: TaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  Text(subtitle, style: t.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: TaColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
