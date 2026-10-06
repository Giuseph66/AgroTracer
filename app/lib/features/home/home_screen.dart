import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui_profile/shell_tabs.dart';
import '../../core/ui_profile/ui_action.dart';
import '../../core/ui_profile/ui_profile.dart';
import '../../core/ui_profile/ui_profile_config.dart';
import '../../core/ui_profile/ui_profile_scope.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/equal_height_grid.dart';
import '../../core/widgets/profile_action_tile.dart';
import '../../core/widgets/task_status_card.dart';
import '../../domain/models.dart';
import '../animal/animal_screen.dart';
import '../animals/animals_screen.dart';
import '../settings/settings_screen.dart';
import '../shipment/shipment_screen.dart';
import '../sync/sync_screen.dart';
import 'home_actions.dart';

/// Início. Contexto da propriedade, o que está pendente e as ações de campo —
/// nessa ordem, porque é a ordem em que o operador decide o que fazer.
///
/// Uma tela só para todos os perfis: o perfil escolhe quais blocos aparecem,
/// em que ordem e de que tamanho; a sessão decide quais são permitidos
/// (Doc 20 §7–§9). Nada de rolagem horizontal escondendo função.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final profile = UiProfileScope.profileOf(context);
    final config = profile.config;

    return StreamBuilder<void>(
      stream: services.outbox.changes,
      builder: (context, _) => ListenableBuilder(
        listenable: Listenable.merge([services.herd, services.sync]),
        builder: (context, _) {
          final pending = services.outbox.pendingCount;
          final conflicts = services.outbox.conflictCount;
          final actions = homeActionsFor(
            homeActionCatalog,
            profile,
            services.auth,
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(services: services)),
              SliverPadding(
                padding: const EdgeInsets.all(TaSpace.md),
                sliver: SliverList.list(
                  children: [
                    if (config.statusAlwaysVisible ||
                        pending + conflicts > 0) ...[
                      TaskStatusCard(
                        pending: pending,
                        conflicts: conflicts,
                        online:
                            services.sync.connectivity !=
                            ConnectivityState.offline,
                        onSend: services.sync.sync,
                        onResolve: () => _openTab(context, ShellTab.pending),
                      ),
                      const SizedBox(height: TaSpace.lg),
                    ],
                    SectionLabel(config.actionsTitle),
                    const SizedBox(height: TaSpace.sm),
                    if (actions.isEmpty)
                      const _NoActions()
                    else
                      EqualHeightGrid(
                        columnsFor: EqualHeightGrid.responsiveColumns,
                        children: [
                          for (final action in actions)
                            ProfileActionTile(
                              key: ValueKey('home-action-${action.id}'),
                              icon: action.icon,
                              label: action.labelFor(profile),
                              primary: action.primaryIn.contains(profile),
                              minHeight: config.tileMinHeight,
                              iconSize: config.tileIconSize,
                              largeLabel: config.largeTileLabels,
                              badgeCount: action.tab == ShellTab.pending
                                  ? conflicts
                                  : 0,
                              onTap: () => _open(context, action, profile),
                            ),
                        ],
                      ),
                    if (config.showTodayCard) ...[
                      const SizedBox(height: TaSpace.lg),
                      SectionLabel(
                        'Hoje na ${services.auth.identity.propertyName}',
                      ),
                      const SizedBox(height: TaSpace.sm),
                      _TodayCard(services: services),
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

  void _open(BuildContext context, UiAction action, UiProfile profile) {
    if (action.tab != null) {
      _openTab(context, action.tab!);
      return;
    }
    final page = action.screen!(context, profile);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _openTab(BuildContext context, ShellTab tab) {
    final tabs = ShellTabs.maybeOf(context);
    if (tabs != null) {
      tabs.select(tab);
      return;
    }
    // Fora do shell (teste, tela isolada): abre a aba como página.
    final page = switch (tab) {
      ShellTab.animals => const AnimalsScreen(),
      ShellTab.pending => const SyncScreen(),
      ShellTab.settings => const SettingsScreen(),
      ShellTab.home => const HomeScreen(),
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(appBar: AppBar(), body: page),
      ),
    );
  }
}

/// Conta sem nenhuma ação de campo (ex.: só administração) — diz isso em vez
/// de deixar a grade vazia sem explicação.
class _NoActions extends StatelessWidget {
  const _NoActions();

  @override
  Widget build(BuildContext context) => TaCard(
    child: Text(
      'Sua conta não tem ações de campo liberadas. Se precisar registrar '
      'algo, peça acesso ao administrador da fazenda.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.services});
  final AppServices services;

  static String _greeting(DateTime now) =>
      now.hour < 12 ? 'Bom dia' : (now.hour < 18 ? 'Boa tarde' : 'Boa noite');

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
          // Wrap, não Row: com o texto do aparelho ampliado, a pílula desce
          // para a linha de baixo em vez de estourar a tela.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TaSpace.sm,
              runSpacing: TaSpace.sm,
              children: [
                const SectionLabel('Soberano', onDark: true),
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
          ),
          const SizedBox(height: TaSpace.md),
          Text(
            '${_greeting(DateTime.now())}, ${services.auth.identity.actorName}',
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

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final animals = services.herd.animals;
    final now = DateTime.now();
    // Só as de hoje: a fila guarda pesagens de dias anteriores até subirem.
    final weighedToday = services.outbox.entries
        .where(
          (e) =>
              e.kind == EventKind.weighing &&
              DateUtils.isSameDay(e.recordedAt, now),
        )
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
        ],
      ),
    );
  }
}
