import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/platform/download.dart';
import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';
import '../animal/animal_screen.dart';

/// Lista de animais da propriedade, com busca por qualquer identificador —
/// visual, RFID ou oficial. São informações distintas e a busca aceita as três
/// (Regra Fundamental de Identificação).
class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key});

  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> {
  String query = '';
  LifecycleStatus? statusFilter;
  String? sexFilter;
  String? paddockFilter;
  String ageFilter = 'Todas';
  String sort = 'Brinco';

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: ListenableBuilder(
        listenable: services.herd,
        builder: (context, _) {
          final q = query.replaceAll(' ', '').toLowerCase();
          final animals =
              services.herd.animals
                  .where((a) {
                    if (q.isEmpty) return true;
                    return a.visualTagNumber.contains(q) ||
                        a.rfidCode.replaceAll(' ', '').contains(q) ||
                        (a.officialAnimalId ?? '')
                            .replaceAll(' ', '')
                            .contains(q) ||
                        a.lot.toLowerCase().contains(q);
                  })
                  .where((a) {
                    if (statusFilter != null && a.status != statusFilter) {
                      return false;
                    }
                    if (sexFilter != null && a.sex != sexFilter) {
                      return false;
                    }
                    if (paddockFilter != null && a.paddockId != paddockFilter) {
                      return false;
                    }
                    return switch (ageFilter) {
                      '0–12 m' => a.ageMonths <= 12,
                      '13–24 m' => a.ageMonths >= 13 && a.ageMonths <= 24,
                      '25+ m' => a.ageMonths >= 25,
                      _ => true,
                    };
                  })
                  .toList()
                ..sort((a, b) {
                  switch (sort) {
                    case 'Peso':
                      return b.lastWeightKg.compareTo(a.lastWeightKg);
                    case 'GMD':
                      return b.gmdKgDay.compareTo(a.gmdKgDay);
                    default:
                      return a.visualTagNumber.compareTo(b.visualTagNumber);
                  }
                });

          return RefreshIndicator(
            onRefresh: services.herd.refresh,
            child: ListView(
              padding: const EdgeInsets.all(TaSpace.md),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Animais', style: t.displayMedium)),
                    IconButton(
                      tooltip: 'Cadastrar animal',
                      onPressed: () => _openRegister(context, services),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Exportar inventário CSV',
                      onPressed: () => _exportInventory(context, services),
                      icon: const Icon(Icons.file_download_outlined),
                    ),
                  ],
                ),
                Text(
                  services.herd.loadedFromServer
                      ? 'sincronizado com o servidor'
                      : 'dados locais deste aparelho',
                  style: t.bodySmall,
                ),
                const SizedBox(height: TaSpace.md),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Brinco, RFID, SISBOV ou lote',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: TaColors.paper,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(TaRadius.rMd),
                      borderSide: BorderSide(color: TaColors.line),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(TaRadius.rMd),
                      borderSide: BorderSide(color: TaColors.line),
                    ),
                  ),
                ),
                const SizedBox(height: TaSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<LifecycleStatus?>(
                        initialValue: statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<LifecycleStatus?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...LifecycleStatus.values.map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => statusFilter = value),
                      ),
                    ),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sort,
                        decoration: const InputDecoration(
                          labelText: 'Ordenar',
                          isDense: true,
                        ),
                        items: const ['Brinco', 'Peso', 'GMD']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => sort = value ?? sort),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TaSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: sexFilter,
                        decoration: const InputDecoration(
                          labelText: 'Sexo',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'F',
                            child: Text('Fêmeas'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'M',
                            child: Text('Machos'),
                          ),
                        ],
                        onChanged: (value) => setState(() => sexFilter = value),
                      ),
                    ),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: ageFilter,
                        decoration: const InputDecoration(
                          labelText: 'Idade',
                          isDense: true,
                        ),
                        items: const ['Todas', '0–12 m', '13–24 m', '25+ m']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => ageFilter = value ?? ageFilter),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TaSpace.sm),
                DropdownButtonFormField<String?>(
                  initialValue: paddockFilter,
                  decoration: const InputDecoration(
                    labelText: 'Piquete',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos os piquetes'),
                    ),
                    ...services.herd.paddocks.map(
                      (paddock) => DropdownMenuItem<String?>(
                        value: paddock.id,
                        child: Text(paddock.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => paddockFilter = value),
                ),
                const SizedBox(height: TaSpace.md),
                Text(
                  '${animals.length} animal(is) neste recorte',
                  style: t.labelMedium,
                ),
                const SizedBox(height: TaSpace.sm),
                for (final a in animals) _AnimalRow(animal: a),
                if (animals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TaSpace.xl),
                    child: _EmptyState(
                      loading: services.herd.loading,
                      searching: q.isNotEmpty,
                      unreachable: !services.herd.loadedFromServer,
                      onRetry: services.herd.refresh,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRegister(BuildContext context, AppServices services) async {
    final visual = TextEditingController();
    final official = TextEditingController();
    final breed = TextEditingController();
    final birth = TextEditingController(text: '2024-01-01');
    final lot = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var sex = 'F';
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            TaSpace.md,
            TaSpace.md,
            TaSpace.md,
            MediaQuery.viewInsetsOf(sheetContext).bottom + TaSpace.md,
          ),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Cadastrar animal',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Registro manual para rebanho pré-existente; o brinco pode ser vinculado depois.',
                ),
                const SizedBox(height: TaSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: visual,
                        decoration: const InputDecoration(
                          labelText: 'Número visual',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sex,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: const [
                          DropdownMenuItem(value: 'F', child: Text('Fêmea')),
                          DropdownMenuItem(value: 'M', child: Text('Macho')),
                        ],
                        onChanged: (v) => setModalState(() => sex = v ?? sex),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TaSpace.sm),
                TextFormField(
                  controller: official,
                  decoration: const InputDecoration(
                    labelText: 'SISBOV/PNIB (opcional)',
                  ),
                ),
                const SizedBox(height: TaSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: breed,
                        decoration: const InputDecoration(labelText: 'Raça'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: TaSpace.sm),
                    Expanded(
                      child: TextFormField(
                        controller: lot,
                        decoration: const InputDecoration(
                          labelText: 'Lote (opcional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TaSpace.sm),
                TextFormField(
                  controller: birth,
                  decoration: const InputDecoration(
                    labelText: 'Nascimento (AAAA-MM-DD)',
                  ),
                  validator: (v) => DateTime.tryParse(v ?? '') == null
                      ? 'Data inválida'
                      : null,
                ),
                const SizedBox(height: TaSpace.md),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final animalId = const Uuid().v7();
                    services.outbox.enqueue(
                      kind: EventKind.registerAnimal,
                      subjectId: animalId,
                      animalId: animalId,
                      subjectLabel: 'Brinco ${visual.text.trim()}',
                      payload: {
                        'speciesCode': 'BOVINE',
                        'sex': sex,
                        'birthType': 'IMPORTED_RECORD',
                        'birthDate': birth.text.trim(),
                        'breedCode': breed.text.trim().toUpperCase(),
                        'officialAnimalId': official.text.trim().isEmpty
                            ? null
                            : official.text.trim(),
                        'herdLot': lot.text.trim().isEmpty
                            ? null
                            : lot.text.trim(),
                        'initialIdentifiers': [
                          {
                            'type': 'VISUAL',
                            'visualTagNumber': visual.text.trim(),
                          },
                        ],
                      },
                    );
                    Navigator.of(sheetContext).pop(true);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Colocar na fila'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    visual.dispose();
    official.dispose();
    breed.dispose();
    birth.dispose();
    lot.dispose();
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro na fila de envio')),
      );
    }
  }

  Future<void> _exportInventory(
    BuildContext context,
    AppServices services,
  ) async {
    try {
      final csv = await services.api.inventoryCsv(
        services.auth.identity.propertyId,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Inventário CSV'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(child: SelectableText(csv)),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final downloaded = await downloadBytes(
                  'traceagro-inventario.csv',
                  utf8.encode(csv),
                  'text/csv;charset=utf-8',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      downloaded
                          ? 'Inventário CSV baixado.'
                          : 'CSV gerado; o compartilhamento nativo será habilitado no aparelho.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Baixar CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventário indisponível sem conexão.')),
        );
      }
    }
  }
}

/// Vazio tem três causas diferentes e cada uma pede uma ação diferente:
/// ainda carregando, busca sem resultado, ou rebanho não carregado por falta
/// de rede. Um texto único para os três casos deixaria o operador sem saber
/// se o animal não existe ou se o aparelho é que não sabe.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.loading,
    required this.searching,
    required this.unreachable,
    required this.onRetry,
  });

  final bool loading;
  final bool searching;
  final bool unreachable;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searching) {
      return Column(
        children: [
          const Icon(Icons.search_off, size: 40, color: TaColors.inkSoft),
          const SizedBox(height: TaSpace.sm),
          Text(
            'Nenhum animal com esse identificador aqui.',
            style: t.bodyMedium,
          ),
          Text(
            'Confira o número ou leia o brinco no curral.',
            style: t.bodySmall,
          ),
        ],
      );
    }

    if (unreachable) {
      return Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: TaColors.inkSoft,
          ),
          const SizedBox(height: TaSpace.sm),
          Text(
            'O rebanho ainda não foi baixado para este aparelho.',
            style: t.bodyMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            'Conecte-se uma vez para trabalhar offline depois.',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: TaSpace.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 40, color: TaColors.inkSoft),
        const SizedBox(height: TaSpace.sm),
        Text(
          'Nenhum animal cadastrado nesta propriedade.',
          style: t.bodyMedium,
        ),
        Text('Registre o primeiro pela leitura de brinco.', style: t.bodySmall),
      ],
    );
  }
}

class _AnimalRow extends StatelessWidget {
  const _AnimalRow({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final quarantined = animal.status == LifecycleStatus.quarantined;

    return Padding(
      padding: const EdgeInsets.only(bottom: TaSpace.sm),
      child: TaCard(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => AnimalScreen(animal: animal))),
        padding: const EdgeInsets.all(TaSpace.sm),
        child: Row(
          children: [
            // Miniatura do brinco: o número estampado é como o operador
            // reconhece o animal a três metros de distância.
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: TaColors.tagYellow,
                borderRadius: BorderRadius.all(TaRadius.rSm),
                border: Border.fromBorderSide(
                  BorderSide(color: TaColors.tagYellowDeep),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                animal.visualTagNumber,
                style: t.titleMedium!.copyWith(color: TaColors.stamp),
              ),
            ),
            const SizedBox(width: TaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(animal.shortDescription, style: t.titleMedium),
                  Text(animal.rfidCode, style: t.labelSmall),
                ],
              ),
            ),
            if (quarantined)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: TaColors.clayBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Carência',
                  style: t.bodySmall!.copyWith(
                    color: TaColors.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: TaColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
