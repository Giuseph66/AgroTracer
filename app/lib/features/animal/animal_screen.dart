import 'package:flutter/material.dart';
import 'dart:convert';

import '../../core/services.dart';
import '../../core/platform/download.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ear_tag.dart';
import '../../data/herd_repository.dart';
import '../../domain/models.dart';
import '../identifier/reidentification_screen.dart';
import '../vaccination/vaccination_screen.dart';

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
                        size: EarTagSize.large,
                      ),
                      const SizedBox(height: TaSpace.sm),
                      Text(
                        animal.shortDescription,
                        style: t.titleMedium!.copyWith(
                          color: TaColors.paperInk,
                        ),
                      ),
                      if (animal.officialAnimalId != null)
                        Text(
                          'SISBOV ${animal.officialAnimalId}',
                          style: t.labelSmall!.copyWith(
                            color: TaColors.paperInkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(TaSpace.md),
            sliver: SliverList.list(
              children: [
                _DerivedStats(animal: animal),
                const SizedBox(height: TaSpace.md),
                FutureBuilder<List<AnimalRelation>>(
                  future: Services.of(context).api.relations(animal.animalId),
                  builder: (context, snapshot) {
                    final relations = snapshot.data ?? const <AnimalRelation>[];
                    if (relations.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: TaSpace.md),
                      child: _RelationsCard(relations: relations),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                VaccinationScreen(initialAnimal: animal),
                          ),
                        ),
                        icon: const Icon(Icons.vaccines_outlined),
                        label: const Text('Vacinar'),
                      ),
                    ),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VaccinationScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Novo registro'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TaSpace.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReidentificationScreen(animal: animal),
                    ),
                  ),
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('Trocar brinco / carimbar'),
                ),
                const SizedBox(height: TaSpace.sm),
                OutlinedButton.icon(
                  onPressed: () => _showDossier(context),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Exportar dossiê verificável'),
                ),
                if (animal.withdrawalUntil != null) ...[
                  const SizedBox(height: TaSpace.md),
                  _WithdrawalBanner(until: animal.withdrawalUntil!),
                ],
                if (animal.paddockId != null) ...[
                  const SizedBox(height: TaSpace.md),
                  TaCard(
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, color: TaColors.pasture),
                        const SizedBox(width: TaSpace.sm),
                        Text(
                          'Piquete ${animal.paddockId}',
                          style: t.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: TaSpace.lg),
                const SectionLabel('Identificadores'),
                const SizedBox(height: TaSpace.sm),
                FutureBuilder<List<AnimalIdentifier>>(
                  future: Services.of(context).api.identifiers(animal.animalId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const TaCard(child: LinearProgressIndicator());
                    }
                    final identifiers = snapshot.data!;
                    return TaCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < identifiers.length; i++) ...[
                            if (i > 0) const Divider(),
                            Row(
                              children: [
                                Icon(
                                  identifiers[i].active
                                      ? Icons.verified_outlined
                                      : Icons.history,
                                  color: identifiers[i].active
                                      ? TaColors.sage
                                      : TaColors.inkSoft,
                                ),
                                const SizedBox(width: TaSpace.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${identifiers[i].type} · ${identifiers[i].label}',
                                        style: t.bodyMedium!.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        identifiers[i].active
                                            ? 'ativo desde ${dayFmt.format(identifiers[i].linkedAt)}'
                                            : 'inativo · ${identifiers[i].unlinkReason ?? 'sem motivo'}',
                                        style: t.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
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
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              color: TaColors.inkSoft,
                            ),
                            const SizedBox(width: TaSpace.sm),
                            Expanded(
                              child: Text(
                                'Sem conexão: o histórico deste animal não foi '
                                'carregado. Os registros feitos aqui continuam '
                                'na fila de envio.',
                                style: t.bodyMedium,
                              ),
                            ),
                          ],
                        ),
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
                        horizontal: TaSpace.md,
                        vertical: TaSpace.sm,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < timeline.length; i++)
                            _TimelineTile(
                              event: timeline[i],
                              last: i == timeline.length - 1,
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: TaSpace.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDossier(BuildContext context) async {
    try {
      final dossier = await Services.of(
        context,
      ).api.animalDossier(animal.animalId);
      if (!context.mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(dossier);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dossiê verificável'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(child: SelectableText(pretty)),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _downloadPdf(context),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Baixar PDF'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o dossiê: $err')),
      );
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await Services.of(
        context,
      ).api.animalDossierPdf(animal.animalId);
      final downloaded = await downloadBytes(
        'traceagro-${animal.visualTagNumber}-dossie.pdf',
        bytes,
        'application/pdf',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'PDF do dossiê baixado.'
                : 'PDF gerado; o compartilhamento nativo será habilitado no aparelho.',
          ),
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível baixar o PDF: $err')),
      );
    }
  }
}

class _RelationsCard extends StatelessWidget {
  const _RelationsCard({required this.relations});
  final List<AnimalRelation> relations;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return TaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Reprodução'),
          const SizedBox(height: TaSpace.sm),
          for (final relation in relations)
            Padding(
              padding: const EdgeInsets.only(bottom: TaSpace.xs),
              child: Row(
                children: [
                  Icon(
                    relation.relation == 'DAM'
                        ? Icons.female
                        : Icons.child_friendly_outlined,
                    color: TaColors.pasture,
                  ),
                  const SizedBox(width: TaSpace.sm),
                  Expanded(
                    child: Text(
                      '${relation.relation == 'DAM' ? 'Mãe' : 'Cria'} · brinco ${relation.visualTagNumber} · ${relation.sex} · ${relation.breed}',
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
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
              Text(
                value,
                style: t.headlineMedium!.copyWith(color: TaColors.pasture),
              ),
              const SizedBox(width: 3),
              Text(unit, style: t.bodySmall),
            ],
          ),
          Text(label, style: t.bodySmall),
        ],
      ),
    );

    return TaCard(
      child: Row(
        children: [
          stat(animal.lastWeightKg.toStringAsFixed(0), 'kg', 'último peso'),
          stat(
            animal.gmdKgDay.toStringAsFixed(2).replaceAll('.', ','),
            'kg/dia',
            'GMD 30d',
          ),
          stat('${animal.ageMonths}', 'meses', 'idade'),
        ],
      ),
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
                color: TaColors.clay,
                fontWeight: FontWeight.w700,
              ),
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
                  Expanded(child: Container(width: 1.5, color: TaColors.line)),
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
                        child: Text(event.kind.label, style: t.titleMedium),
                      ),
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
