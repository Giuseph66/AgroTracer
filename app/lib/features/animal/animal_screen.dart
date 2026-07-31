import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ear_tag.dart';
import '../../data/herd_repository.dart';
import '../../domain/models.dart';

/// Ficha do animal: identidade (brinco), derivados (peso, GMD, status — R9/R11)
/// e linha do tempo de eventos com estado de sincronização e prova.
class AnimalScreen extends StatefulWidget {
  const AnimalScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<AnimalScreen> createState() => _AnimalScreenState();
}

class _AnimalScreenState extends State<AnimalScreen> {
  late Future<TimelineResult> _timeline;

  Animal get animal => widget.animal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timeline = Services.of(context).herd.timeline(animal.animalId);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: TaColors.pasture,
            foregroundColor: TaColors.paperInk,
            pinned: true,
            expandedHeight: 320,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: kToolbarHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EarTag(
                          number: animal.visualTagNumber,
                          rfid: animal.rfidCode,
                          size: EarTagSize.large),
                      const SizedBox(height: TaSpace.sm),
                      Text(animal.shortDescription,
                          style: t.titleMedium!
                              .copyWith(color: TaColors.paperInk)),
                      if (animal.officialAnimalId != null)
                        Text('SISBOV ${animal.officialAnimalId}',
                            style: t.labelSmall!
                                .copyWith(color: TaColors.paperInkSoft)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(TaSpace.md),
            sliver: SliverList.list(children: [
              _DerivedStats(animal: animal),
              if (animal.withdrawalUntil != null) ...[
                const SizedBox(height: TaSpace.md),
                _WithdrawalBanner(until: animal.withdrawalUntil!),
              ],
              const SizedBox(height: TaSpace.lg),
              const SectionLabel('Linha do tempo'),
              const SizedBox(height: TaSpace.sm),
              FutureBuilder<TimelineResult>(
                future: _timeline,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const TaCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(TaSpace.md),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }
                  final result = snapshot.data!;
                  final timeline = result.events;
                  if (result.unreachable) {
                    return TaCard(
                      child: Row(children: [
                        const Icon(Icons.cloud_off_outlined,
                            color: TaColors.inkSoft),
                        const SizedBox(width: TaSpace.sm),
                        Expanded(
                          child: Text(
                            'Sem conexão: o histórico deste animal não foi '
                            'carregado. Os registros feitos aqui continuam '
                            'na fila de envio.',
                            style: t.bodyMedium,
                          ),
                        ),
                      ]),
                    );
                  }
                  if (timeline.isEmpty) {
                    return TaCard(
                      child: Text(
                        'Nenhum evento registrado para este animal ainda.',
                        style: t.bodyMedium,
                      ),
                    );
                  }
                  return TaCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TaSpace.md, vertical: TaSpace.sm),
                    child: Column(
                      children: [
                        for (var i = 0; i < timeline.length; i++)
                          _TimelineTile(
                              event: timeline[i],
                              last: i == timeline.length - 1),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: TaSpace.lg),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DerivedStats extends StatelessWidget {
  const _DerivedStats({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget stat(String value, String unit, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value,
                      style:
                          t.headlineMedium!.copyWith(color: TaColors.pasture)),
                  const SizedBox(width: 3),
                  Text(unit, style: t.bodySmall),
                ],
              ),
              Text(label, style: t.bodySmall),
            ],
          ),
        );

    return TaCard(
      child: Row(children: [
        stat(animal.lastWeightKg.toStringAsFixed(0), 'kg', 'último peso'),
        stat(
            animal.gmdKgDay.toStringAsFixed(2).replaceAll('.', ','),
            'kg/dia',
            'GMD 30d'),
        stat('${animal.ageMonths}', 'meses', 'idade'),
      ]),
    );
  }
}

class _WithdrawalBanner extends StatelessWidget {
  const _WithdrawalBanner({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final days = until.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(TaSpace.md),
      decoration: const BoxDecoration(
        color: TaColors.clayBg,
        borderRadius: BorderRadius.all(TaRadius.rLg),
        border: Border.fromBorderSide(BorderSide(color: TaColors.clay)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: TaColors.clay),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Text(
              'Carência ativa: abate bloqueado por mais $days dias '
              '(até ${dayFmt.format(until)})',
              style: t.bodyMedium!.copyWith(
                  color: TaColors.clay, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, required this.last});
  final TraceEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trilho vertical com nó.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.syncState == SyncState.confirmedOnBlockchain
                        ? TaColors.sage
                        : TaColors.tagYellow,
                    border: Border.all(color: TaColors.pasture, width: 1.5),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1.5, color: TaColors.line),
                  ),
              ],
            ),
          ),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child:
                              Text(event.kind.label, style: t.titleMedium)),
                      SyncBadge(event.syncState, compact: true),
                    ],
                  ),
                  if (event.detail != null)
                    Text(event.detail!, style: t.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${dayHourFmt.format(event.occurredAt)} · ${event.actor}',
                    style: t.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
