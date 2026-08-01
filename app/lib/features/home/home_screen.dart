import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../animal/animal_screen.dart';
import '../areas/areas_screen.dart';
import '../birth/birth_screen.dart';
import '../read/read_screen.dart';
import '../shipment/shipment_screen.dart';
import '../sync/sync_screen.dart';
import '../vaccination/vaccination_screen.dart';
import '../weighing/weighing_screen.dart';

/// Início. Contexto da propriedade, o que está pendente e as ações de campo —
/// nessa ordem, porque é a ordem em que o operador decide o que fazer.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);

    return StreamBuilder<void>(
      stream: services.outbox.changes,
      builder: (context, _) => ListenableBuilder(
        listenable: services.herd,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(services: services)),
            SliverPadding(
              padding: const EdgeInsets.all(TaSpace.md),
              sliver: SliverList.list(
                children: [
                  if (services.outbox.pendingCount +
                          services.outbox.conflictCount >
                      0) ...[
                    _SyncSummaryCard(services: services),
                    const SizedBox(height: TaSpace.md),
                  ],
                  const SectionLabel('Trabalho de campo'),
                  const SizedBox(height: TaSpace.sm),
                  const _ActionGrid(),
                  const SizedBox(height: TaSpace.lg),
                  const SectionLabel('Hoje na Santa Rita'),
                  const SizedBox(height: TaSpace.sm),
                  _TodayCard(services: services),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: TaColors.pasture,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + TaSpace.md,
        left: TaSpace.md,
        right: TaSpace.md,
        bottom: TaSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('TraceAgro', onDark: true),
              ListenableBuilder(
                listenable: services.sync,
                builder: (context, _) => ConnectivityPill(
                  online:
                      services.sync.connectivity == ConnectivityState.online,
                  pending: services.outbox.pendingCount,
                ),
              ),
            ],
          ),
          const SizedBox(height: TaSpace.md),
          Text(
            'Bom dia, ${services.auth.identity.actorName}',
            style: t.displayMedium!.copyWith(color: TaColors.paperInk),
          ),
          const SizedBox(height: 4),
          Text(
            '${services.auth.identity.propertyName} · ${services.herd.animals.length} animais no aparelho',
            style: t.bodyMedium!.copyWith(color: TaColors.paperInkSoft),
          ),
        ],
      ),
    );
  }
}

class _SyncSummaryCard extends StatelessWidget {
  const _SyncSummaryCard({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pending = services.outbox.pendingCount;
    final conflicts = services.outbox.conflictCount;
    final hasConflict = conflicts > 0;

    return TaCard(
      onTap: services.sync.sync,
      child: Row(
        children: [
          Icon(
            hasConflict ? Icons.priority_high : Icons.cloud_upload_outlined,
            size: 28,
            color: hasConflict ? TaColors.clay : TaColors.inkSoft,
          ),
          const SizedBox(width: TaSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending == 0
                      ? 'Fila vazia'
                      : '$pending ${pending == 1 ? "evento aguardando" : "eventos aguardando"} envio',
                  style: t.titleMedium,
                ),
                if (hasConflict)
                  Text(
                    '$conflicts ${conflicts == 1 ? "conflito" : "conflitos"} para resolver',
                    style: t.bodySmall!.copyWith(
                      color: TaColors.clay,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: TaColors.inkSoft),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    Widget heroAction(
      IconData icon,
      String label,
      String hint,
      VoidCallback onTap,
    ) {
      final t = Theme.of(context).textTheme;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(TaRadius.rLg),
          child: Container(
            height: 118,
            padding: const EdgeInsets.all(TaSpace.md),
            decoration: const BoxDecoration(
              color: TaColors.tagYellow,
              borderRadius: BorderRadius.all(TaRadius.rLg),
              border: Border.fromBorderSide(
                BorderSide(color: TaColors.tagYellowDeep),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 34, color: TaColors.stamp),
                const SizedBox(width: TaSpace.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: t.titleMedium!.copyWith(color: TaColors.stamp),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hint,
                        style: t.bodySmall!.copyWith(color: TaColors.stamp),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: TaColors.stamp),
              ],
            ),
          ),
        ),
      );
    }

    Widget compact(IconData icon, String label, VoidCallback? onTap) {
      final enabled = onTap != null;
      return Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(TaRadius.rMd),
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(
              horizontal: TaSpace.sm,
              vertical: TaSpace.md,
            ),
            decoration: BoxDecoration(
              color: enabled ? TaColors.paper : TaColors.paperDim,
              borderRadius: const BorderRadius.all(TaRadius.rMd),
              border: Border.all(
                color: enabled
                    ? TaColors.line
                    : TaColors.line.withValues(alpha: .65),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: enabled ? TaColors.pasture : TaColors.inkSoft,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: enabled ? TaColors.ink : TaColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    void go(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            heroAction(
              Icons.sensors,
              'Ler animal',
              'identificar e abrir ficha',
              () => go(const ReadScreen()),
            ),
            const SizedBox(width: TaSpace.sm),
            heroAction(
              Icons.monitor_weight_outlined,
              'Pesagem',
              'registrar no brete',
              () => go(const WeighingScreen()),
            ),
          ],
        ),
        const SizedBox(height: TaSpace.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              compact(
                Icons.vaccines_outlined,
                'Vacinação',
                () => go(const VaccinationScreen()),
              ),
              const SizedBox(width: TaSpace.sm),
              compact(
                Icons.local_shipping_outlined,
                'Embarque',
                () => go(const ShipmentScreen()),
              ),
              const SizedBox(width: TaSpace.sm),
              compact(
                Icons.child_friendly_outlined,
                'Nascimento',
                () => go(const BirthScreen()),
              ),
              const SizedBox(width: TaSpace.sm),
              compact(
                Icons.map_outlined,
                'Áreas',
                () => go(const AreasScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final animals = services.herd.animals;
    final weighedToday = services.outbox.entries
        .where((e) => e.kind == EventKind.weighing)
        .length;
    final inWithdrawal = animals
        .where((a) => a.status == LifecycleStatus.quarantined)
        .toList();
    final waitingShipments = services.herd.shipments
        .where((shipment) => shipment.status == 'DISPATCHED')
        .length;

    Widget row(String value, String label, {VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                value,
                style: t.headlineMedium!.copyWith(color: TaColors.pasture),
              ),
            ),
            const SizedBox(width: TaSpace.sm),
            Expanded(child: Text(label, style: t.bodyMedium)),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: TaColors.inkSoft,
              ),
          ],
        ),
      ),
    );

    return TaCard(
      padding: const EdgeInsets.symmetric(horizontal: TaSpace.md),
      child: Column(
        children: [
          row('${animals.length}', 'animais no rebanho desta propriedade'),
          const Divider(),
          row(
            '$weighedToday',
            weighedToday == 1
                ? 'pesagem registrada hoje'
                : 'pesagens registradas hoje',
          ),
          const Divider(),
          row(
            '${inWithdrawal.length}',
            inWithdrawal.isEmpty
                ? 'animais em carência'
                : 'em carência — brinco ${inWithdrawal.first.visualTagNumber}',
            onTap: inWithdrawal.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnimalScreen(animal: inWithdrawal.first),
                    ),
                  ),
          ),
          if (waitingShipments > 0) ...[
            const Divider(),
            row(
              '$waitingShipments',
              waitingShipments == 1
                  ? 'embarque aguardando recebimento'
                  : 'embarques aguardando recebimento',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ShipmentScreen())),
            ),
          ],
          if (services.outbox.conflictCount > 0) ...[
            const Divider(),
            row(
              '${services.outbox.conflictCount}',
              'conflitos de sincronização para resolver',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SyncScreen())),
            ),
          ],
        ],
      ),
    );
  }
}
