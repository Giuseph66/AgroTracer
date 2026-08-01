import 'package:flutter/material.dart';
import 'package:traceagro_map/traceagro_map.dart';
import 'package:uuid/uuid.dart';

import '../../core/services.dart';
import '../../core/sync/event_envelope.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../animal/animal_screen.dart';
import 'area_mapping.dart';

/// Ficha da área selecionada.
///
/// Responde, nesta ordem, o que o operador precisa saber ao tocar num piquete:
/// quanto mede e quantos animais tem, quem está com restrição, e o que dá para
/// fazer daqui. Os animais com problema aparecem primeiro — são eles que
/// motivam abrir a ficha.
class AreaDetailSheet extends StatefulWidget {
  const AreaDetailSheet({
    super.key,
    required this.paddock,
    required this.services,
    this.onClose,
    this.onEditBoundary,
    this.onChanged,
  });

  final Paddock paddock;
  final AppServices services;
  final VoidCallback? onClose;
  final VoidCallback? onEditBoundary;
  final VoidCallback? onChanged;

  @override
  State<AreaDetailSheet> createState() => _AreaDetailSheetState();
}

class _AreaDetailSheetState extends State<AreaDetailSheet> {
  late Future<List<PaddockAnimal>> _animals;
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AreaDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paddock.id != widget.paddock.id) _load();
  }

  void _load() {
    _animals = widget.services.api
        .paddockAnimals(DevIdentity.propertyId, widget.paddock.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MapTheme.of(context);
    final t = Theme.of(context).textTheme;
    final paddock = widget.paddock;
    final status = paddock.animalCount == 0
        ? AreaHealthStatus.empty
        : paddock.hasAlert
            ? AreaHealthStatus.withdrawal
            : AreaHealthStatus.clear;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * (expanded ? 0.85 : 0.6),
      ),
      decoration: const BoxDecoration(
        color: TaColors.paper,
        borderRadius: BorderRadius.vertical(top: TaRadius.rLg),
        border: Border(top: BorderSide(color: TaColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(onTap: () => setState(() => expanded = !expanded)),
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                TaSpace.md,
                0,
                TaSpace.md,
                MediaQuery.paddingOf(context).bottom + TaSpace.md,
              ),
              shrinkWrap: true,
              children: [
                _title(t, paddock, status, theme),
                const SizedBox(height: TaSpace.md),
                _stats(t, paddock),
                const SizedBox(height: TaSpace.lg),
                const SectionLabel('Animais nesta área'),
                const SizedBox(height: TaSpace.sm),
                _animalList(t),
                const SizedBox(height: TaSpace.md),
                _actions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(
    TextTheme t,
    Paddock paddock,
    AreaHealthStatus status,
    MapTheme theme,
  ) {
    final stroke = theme.strokeFor(status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PIQUETE · VERSÃO ${paddock.version}',
                  style: t.titleSmall),
              Text(paddock.name, style: t.displayMedium),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.fillFor(status),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(theme.iconFor(status), size: 14, color: stroke),
                    const SizedBox(width: 6),
                    Text(
                      status.label,
                      style: t.bodySmall!.copyWith(
                        color: stroke,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.onClose != null)
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: TaColors.inkSoft),
            tooltip: 'Fechar',
          ),
      ],
    );
  }

  Widget _stats(TextTheme t, Paddock paddock) {
    final stocking =
        paddock.areaHa > 0 ? paddock.animalCount / paddock.areaHa : null;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: t.headlineMedium!.copyWith(color: TaColors.pasture)),
              Text(label, style: t.bodySmall),
            ],
          ),
        );

    return Row(
      children: [
        stat(
          paddock.areaHa.toStringAsFixed(1).replaceAll('.', ','),
          'hectares',
        ),
        stat('${paddock.animalCount}',
            paddock.animalCount == 1 ? 'animal' : 'animais'),
        stat(
          stocking == null
              ? '—'
              : stocking.toStringAsFixed(1).replaceAll('.', ','),
          'cab/ha',
        ),
      ],
    );
  }

  Widget _animalList(TextTheme t) {
    return FutureBuilder<List<PaddockAnimal>>(
      future: _animals,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TaCard(child: LinearProgressIndicator());
        }

        if (snapshot.hasError) {
          return TaCard(
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined, color: TaColors.inkSoft),
                const SizedBox(width: TaSpace.sm),
                Expanded(
                  child: Text(
                    'Sem conexão: a lista de animais desta área não foi '
                    'carregada.',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        final animals = snapshot.data ?? const <PaddockAnimal>[];
        if (animals.isEmpty) {
          return TaCard(
            child: Row(
              children: [
                const Icon(Icons.grass, color: TaColors.inkSoft),
                const SizedBox(width: TaSpace.sm),
                Expanded(
                  child: Text(
                    'Piquete vazio. Mova um lote para cá pela ficha do animal '
                    'ou pelo botão abaixo.',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        // Quem tem restrição vem primeiro: é a informação que muda a decisão.
        final sorted = [...animals]..sort((a, b) {
            if (a.hasAlert != b.hasAlert) return a.hasAlert ? -1 : 1;
            return a.visualTagNumber.compareTo(b.visualTagNumber);
          });

        final visible = expanded ? sorted : sorted.take(4).toList();
        final hidden = sorted.length - visible.length;

        return TaCard(
          padding: const EdgeInsets.symmetric(horizontal: TaSpace.md),
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _AnimalRow(
                  animal: visible[i],
                  onTap: () => _openAnimal(visible[i]),
                ),
              ],
              if (hidden > 0)
                TextButton(
                  onPressed: () => setState(() => expanded = true),
                  child: Text('Ver os outros $hidden'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _moveAnimals,
                icon: const Icon(Icons.drive_file_move_outlined),
                label: const Text('Mover animais'),
              ),
            ),
            if (widget.onEditBoundary != null) ...[
              const SizedBox(width: TaSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEditBoundary,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(widget.paddock.hasBoundary
                      ? 'Editar contorno'
                      : 'Desenhar'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _openAnimal(PaddockAnimal paddockAnimal) {
    final animal = widget.services.herd.byId(paddockAnimal.animalId);
    if (animal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este animal ainda não foi baixado para o aparelho. '
            'Sincronize para abrir a ficha.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimalScreen(animal: animal)),
    );
  }

  /// Move animais para este piquete. A seleção é múltipla porque manejo se faz
  /// por lote: mover 40 animais um a um não é operação de campo.
  Future<void> _moveAnimals() async {
    final candidates = widget.services.herd.animals
        .where((a) => a.paddockId != widget.paddock.id)
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos os animais já estão neste piquete.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<List<Animal>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoveAnimalsSheet(
        target: widget.paddock,
        candidates: candidates,
      ),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    // Um evento por animal, com o mesmo batchId: é uma passagem de manejo só,
    // e a trilha precisa mostrar isso (Doc 5 §4.4).
    final batchId = const Uuid().v7();
    for (final animal in selected) {
      widget.services.outbox.enqueue(
        kind: EventKind.paddockChange,
        subjectId: animal.animalId,
        animalId: animal.animalId,
        subjectLabel: 'Brinco ${animal.visualTagNumber} → ${widget.paddock.name}',
        payload: {
          'paddockId': widget.paddock.id,
          'batchId': batchId,
        },
      );
    }

    widget.services.sync.sync();
    widget.onChanged?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? '1 animal movido para ${widget.paddock.name}.'
                : '${selected.length} animais movidos para ${widget.paddock.name}.',
          ),
        ),
      );
      setState(_load);
    }
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: TaSpace.sm),
          alignment: Alignment.center,
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: TaColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
}

class _AnimalRow extends StatelessWidget {
  const _AnimalRow({required this.animal, required this.onTap});

  final PaddockAnimal animal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final theme = MapTheme.of(context);
    final stroke = theme.strokeFor(animal.mapStatus);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TaSpace.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TaColors.tagYellow,
                borderRadius: const BorderRadius.all(TaRadius.rSm),
                border: Border.all(color: TaColors.tagYellowDeep),
              ),
              alignment: Alignment.center,
              child: Text(
                animal.visualTagNumber,
                style: t.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: TaColors.stamp,
                ),
              ),
            ),
            const SizedBox(width: TaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_description(animal), style: t.bodyMedium),
                  if (animal.hasAlert)
                    Text(
                      _alertLabel(animal),
                      style: t.bodySmall!.copyWith(
                        color: stroke,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              animal.hasAlert ? theme.iconFor(animal.mapStatus) : Icons.chevron_right,
              size: 20,
              color: animal.hasAlert ? stroke : TaColors.inkSoft,
            ),
          ],
        ),
      ),
    );
  }

  /// Sexo, raça e peso. Animal sem pesagem registrada aparece como tal: "0 kg"
  /// seria um número inventado, e no campo alguém agiria em cima dele.
  String _description(PaddockAnimal animal) {
    final breed = _breedLabel(animal.breed);
    final base = '${animal.sex} · $breed';
    if (animal.lastWeightKg <= 0) return '$base · sem pesagem';
    return '$base · ${animal.lastWeightKg.toStringAsFixed(0)} kg';
  }

  String _breedLabel(String code) {
    if (code.isEmpty || code == '—') return '—';
    return code[0].toUpperCase() + code.substring(1).toLowerCase();
  }

  String _alertLabel(PaddockAnimal animal) {
    if (animal.lifecycleStatus == 'QUARANTINED') return 'Em quarentena';
    final until = animal.withdrawalUntil;
    if (until == null) return 'Com restrição';
    final days = until.difference(DateTime.now()).inDays;
    if (days <= 0) return 'Carência termina hoje';
    return 'Carência por mais $days ${days == 1 ? "dia" : "dias"}';
  }
}

/// Seleção múltipla de animais para mover.
class _MoveAnimalsSheet extends StatefulWidget {
  const _MoveAnimalsSheet({required this.target, required this.candidates});

  final Paddock target;
  final List<Animal> candidates;

  @override
  State<_MoveAnimalsSheet> createState() => _MoveAnimalsSheetState();
}

class _MoveAnimalsSheetState extends State<_MoveAnimalsSheet> {
  final Set<String> selected = {};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = query.trim().toLowerCase();
    final list = widget.candidates.where((a) {
      if (q.isEmpty) return true;
      return a.visualTagNumber.contains(q) || a.lot.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        TaSpace.md,
        TaSpace.md,
        TaSpace.md,
        MediaQuery.viewInsetsOf(context).bottom + TaSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mover para ${widget.target.name}', style: t.headlineMedium),
          Text(
            'Marque os animais. O registro vai para a fila e sobe na próxima '
            'sincronização.',
            style: t.bodySmall,
          ),
          const SizedBox(height: TaSpace.md),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Brinco ou lote',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: TaSpace.sm),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  selected
                    ..clear()
                    ..addAll(list.map((a) => a.animalId));
                }),
                child: Text('Marcar ${list.length}'),
              ),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: () => setState(selected.clear),
                  child: const Text('Limpar'),
                ),
            ],
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final animal = list[i];
                return CheckboxListTile(
                  value: selected.contains(animal.animalId),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      selected.add(animal.animalId);
                    } else {
                      selected.remove(animal.animalId);
                    }
                  }),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Brinco ${animal.visualTagNumber}'),
                  // shortDescription já traz sexo, raça, idade e lote de
                  // manejo; repetir o lote deixava "Recria 12 · Recria 12".
                  subtitle: Text(animal.shortDescription),
                );
              },
            ),
          ),
          const SizedBox(height: TaSpace.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                        widget.candidates
                            .where((a) => selected.contains(a.animalId))
                            .toList(),
                      ),
              icon: const Icon(Icons.check),
              label: Text(
                selected.isEmpty
                    ? 'Marque ao menos um animal'
                    : 'Mover ${selected.length} '
                        '${selected.length == 1 ? "animal" : "animais"}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
