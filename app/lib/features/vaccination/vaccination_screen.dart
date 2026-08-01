import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';

const _uuid = Uuid();

/// Vacinação de campo: seleciona produto + animais e cria um evento por
/// animal. O lote comum permite auditar uma aplicação coletiva sem transformar
/// o lote em um falso sujeito do histórico individual.
class VaccinationScreen extends StatefulWidget {
  const VaccinationScreen({super.key, this.initialAnimal});

  final Animal? initialAnimal;

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  VetProduct? product;
  final doseController = TextEditingController(text: '5 ml');
  final batchController = TextEditingController();
  String route = 'SC';
  final selected = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialAnimal != null) selected.add(widget.initialAnimal!.animalId);
  }

  @override
  void dispose() {
    doseController.dispose();
    batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Vacinação'), backgroundColor: TaColors.pasture,
          foregroundColor: TaColors.paperInk),
      body: ListenableBuilder(
        listenable: services.herd,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(TaSpace.md),
          children: [
            Text('Registrar aplicação', style: t.displayMedium),
            Text('Um evento rastreável para cada animal selecionado.', style: t.bodySmall),
            const SizedBox(height: TaSpace.lg),
            const SectionLabel('Produto do catálogo'),
            const SizedBox(height: TaSpace.sm),
            if (services.herd.vetProducts.isEmpty)
              TaCard(child: Row(children: [
                const Icon(Icons.cloud_off_outlined, color: TaColors.inkSoft),
                const SizedBox(width: TaSpace.sm),
                Expanded(child: Text('Catálogo indisponível. Sincronize quando houver conexão.', style: t.bodyMedium)),
              ]))
            else
              DropdownButtonFormField<VetProduct>(
                initialValue: product,
                decoration: const InputDecoration(labelText: 'Vacina ou medicamento'),
                items: services.herd.vetProducts.map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.name),
                )).toList(),
                onChanged: (value) => setState(() => product = value),
              ),
            if (product != null)
              Padding(
                padding: const EdgeInsets.only(top: TaSpace.sm),
                child: Text(product!.withdrawalLabel, style: t.bodySmall!.copyWith(color: product!.withdrawalSlaughterDays > 0 ? TaColors.clay : TaColors.sage)),
              ),
            const SizedBox(height: TaSpace.md),
            Row(children: [
              Expanded(child: TextField(controller: doseController, decoration: const InputDecoration(labelText: 'Dose'))),
              const SizedBox(width: TaSpace.sm),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: route,
                decoration: const InputDecoration(labelText: 'Via'),
                items: const ['SC', 'IM', 'IV', 'ORAL', 'POUR_ON'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) => setState(() => route = value ?? route),
              )),
            ]),
            const SizedBox(height: TaSpace.md),
            TextField(controller: batchController, decoration: const InputDecoration(labelText: 'Lote do frasco (opcional)')),
            const SizedBox(height: TaSpace.lg),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SectionLabel('Animais presentes'),
              Text('${selected.length} selecionado(s)', style: t.labelMedium),
            ]),
            const SizedBox(height: TaSpace.sm),
            if (services.herd.animals.isEmpty)
              const TaCard(child: Text('Nenhum animal no aparelho. Faça uma sincronização inicial.'))
            else
              for (final animal in services.herd.animals) _AnimalChoice(
                animal: animal,
                selected: selected.contains(animal.animalId),
                onTap: () => setState(() {
                  if (!selected.add(animal.animalId)) selected.remove(animal.animalId);
                }),
              ),
            const SizedBox(height: TaSpace.lg),
            FilledButton.icon(
              onPressed: product == null || selected.isEmpty ? null : () => _enqueue(services),
              icon: const Icon(Icons.vaccines_outlined),
              label: Text(selected.length > 1 ? 'Registrar ${selected.length} aplicações' : 'Registrar aplicação'),
            ),
            const SizedBox(height: TaSpace.sm),
            Text('Sem conexão? O registro fica seguro na fila local e sobe depois.', style: t.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _enqueue(AppServices services) {
    final batchId = _uuid.v7();
    for (final animalId in selected) {
      final animal = services.herd.byId(animalId);
      if (animal == null || product == null) continue;
      services.outbox.enqueue(
        kind: EventKind.vaccination,
        subjectId: animal.animalId,
        animalId: animal.animalId,
        subjectLabel: 'Brinco ${animal.visualTagNumber}',
        payload: {
          'productRef': product!.code,
          'dosage': doseController.text.trim(),
          'route': route,
          'batchNumber': batchController.text.trim().isEmpty ? null : batchController.text.trim(),
          'batchId': batchId,
        },
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${selected.length} aplicação(ões) na fila de envio')));
    Navigator.of(context).pop();
  }
}

class _AnimalChoice extends StatelessWidget {
  const _AnimalChoice({required this.animal, required this.selected, required this.onTap});
  final Animal animal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TaSpace.sm),
    child: TaCard(onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: TaSpace.sm, vertical: 4), child: Row(children: [
      Checkbox(value: selected, onChanged: (_) => onTap()),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Brinco ${animal.visualTagNumber}', style: Theme.of(context).textTheme.titleMedium),
        Text(animal.shortDescription, style: Theme.of(context).textTheme.bodySmall),
      ])),
      if (animal.status == LifecycleStatus.quarantined) const Icon(Icons.warning_amber_rounded, color: TaColors.clay),
    ])),
  );
}
