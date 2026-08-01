import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';

const _uuid = Uuid();

/// Parto offline: CALVING → REGISTER_ANIMAL → OFFSPRING_LINK.
class BirthScreen extends StatefulWidget {
  const BirthScreen({super.key});

  @override
  State<BirthScreen> createState() => _BirthScreenState();
}

class _BirthScreenState extends State<BirthScreen> {
  Animal? dam;
  String sex = 'F';
  final breedController = TextEditingController(text: 'NELORE');
  final visualController = TextEditingController();
  DateTime birthDate = DateTime.now();

  @override
  void dispose() {
    breedController.dispose();
    visualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final females = services.herd.animals.where((animal) => animal.sex == 'F').toList();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nascimento'), backgroundColor: TaColors.pasture, foregroundColor: TaColors.paperInk),
      body: ListView(padding: const EdgeInsets.all(TaSpace.md), children: [
        Text('Registrar parto', style: t.displayMedium),
        Text('A cria nasce sem depender de brinco. O vínculo fica na trilha.', style: t.bodySmall),
        const SizedBox(height: TaSpace.lg),
        const SectionLabel('Mãe'),
        const SizedBox(height: TaSpace.sm),
        DropdownButtonFormField<Animal>(
          initialValue: dam,
          decoration: const InputDecoration(labelText: 'Selecione a matriz'),
          items: females.map((animal) => DropdownMenuItem(value: animal, child: Text('Brinco ${animal.visualTagNumber} · ${animal.lot}'))).toList(),
          onChanged: (value) => setState(() => dam = value),
        ),
        const SizedBox(height: TaSpace.md),
        Row(children: [
          Expanded(child: TextFormField(controller: breedController, decoration: const InputDecoration(labelText: 'Raça da cria'))),
          const SizedBox(width: TaSpace.sm),
          Expanded(child: DropdownButtonFormField<String>(initialValue: sex, decoration: const InputDecoration(labelText: 'Sexo'), items: const [DropdownMenuItem(value: 'F', child: Text('Fêmea')), DropdownMenuItem(value: 'M', child: Text('Macho'))], onChanged: (value) => setState(() => sex = value ?? sex))),
        ]),
        const SizedBox(height: TaSpace.md),
        TextFormField(controller: visualController, decoration: const InputDecoration(labelText: 'Número visual (opcional)', hintText: 'Brinco poderá ser vinculado depois')),
        const SizedBox(height: TaSpace.md),
        OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event_outlined), label: Text('Data do nascimento · ${DateFormat('dd/MM/yyyy').format(birthDate)}')),
        const SizedBox(height: TaSpace.lg),
        TaCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.link, color: TaColors.sky),
          const SizedBox(width: TaSpace.sm),
          Expanded(child: Text('Serão criados 3 eventos ordenados no mesmo lote: parto, identidade da cria e vínculo com a mãe.', style: t.bodyMedium)),
        ])),
        const SizedBox(height: TaSpace.lg),
        FilledButton.icon(onPressed: dam == null ? null : () => _enqueue(services), icon: const Icon(Icons.child_friendly_outlined), label: const Text('Registrar nascimento')),
      ]),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: birthDate);
    if (picked != null) setState(() => birthDate = picked);
  }

  void _enqueue(AppServices services) {
    final mother = dam!;
    final calfId = _uuid.v7();
    final visual = visualController.text.trim();
    final initialIdentifiers = visual.isEmpty ? <Object?>[] : [
      {'type': 'VISUAL', 'visualTagNumber': visual},
    ];
    services.outbox.enqueue(
      kind: EventKind.calving,
      subjectId: mother.animalId,
      animalId: mother.animalId,
      subjectLabel: 'Brinco ${mother.visualTagNumber}',
      payload: {'calfId': calfId, 'birthDate': birthDate.toIso8601String()},
    );
    services.outbox.enqueue(
      kind: EventKind.registerAnimal,
      subjectId: calfId,
      animalId: calfId,
      subjectLabel: visual.isEmpty ? 'Cria sem brinco' : 'Brinco $visual',
      payload: {
        'speciesCode': 'BOVINE',
        'sex': sex,
        'birthType': 'BORN_ON_PROPERTY',
        'birthDate': birthDate.toIso8601String(),
        'breedCode': breedController.text.trim().toUpperCase(),
        'damId': mother.animalId,
        'initialIdentifiers': initialIdentifiers,
      },
    );
    services.outbox.enqueue(
      kind: EventKind.offspringLink,
      subjectId: calfId,
      animalId: calfId,
      subjectLabel: visual.isEmpty ? 'Cria sem brinco' : 'Brinco $visual',
      payload: {'damId': mother.animalId},
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parto e vínculo da cria estão na fila')));
    Navigator.of(context).pop();
  }
}
