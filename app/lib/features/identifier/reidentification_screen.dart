import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';

class ReidentificationScreen extends StatefulWidget {
  const ReidentificationScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<ReidentificationScreen> createState() => _ReidentificationScreenState();
}

class _ReidentificationScreenState extends State<ReidentificationScreen> {
  late Future<List<AnimalIdentifier>> identifiers;
  AnimalIdentifier? oldIdentifier;
  String reason = 'DAMAGED';
  final rfidController = TextEditingController();
  final visualController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    identifiers = Services.of(context).api.identifiers(widget.animal.animalId);
  }

  @override
  void dispose() {
    rfidController.dispose();
    visualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Trocar brinco'), backgroundColor: TaColors.pasture, foregroundColor: TaColors.paperInk),
      body: ListView(padding: const EdgeInsets.all(TaSpace.md), children: [
        Text('Nova identificação', style: t.displayMedium),
        Text('O vínculo anterior permanece no histórico com o motivo da troca.', style: t.bodySmall),
        const SizedBox(height: TaSpace.lg),
        const SectionLabel('Identificador anterior'),
        const SizedBox(height: TaSpace.sm),
        FutureBuilder<List<AnimalIdentifier>>(
          future: identifiers,
          builder: (context, snapshot) {
            final values = snapshot.data?.where((item) => item.active).toList() ?? const <AnimalIdentifier>[];
            return DropdownButtonFormField<AnimalIdentifier>(
              initialValue: oldIdentifier,
              decoration: const InputDecoration(labelText: 'Brinco ativo'),
              items: values.map((item) => DropdownMenuItem(value: item, child: Text('${item.type} · ${item.label}'))).toList(),
              onChanged: (value) => setState(() => oldIdentifier = value),
            );
          },
        ),
        const SizedBox(height: TaSpace.md),
        Row(children: [
          Expanded(child: TextField(controller: rfidController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Novo RFID', hintText: '15 dígitos'))),
          const SizedBox(width: TaSpace.sm),
          Expanded(child: TextField(controller: visualController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Novo visual'))),
        ]),
        const SizedBox(height: TaSpace.md),
        DropdownButtonFormField<String>(initialValue: reason, decoration: const InputDecoration(labelText: 'Motivo obrigatório'), items: const ['LOST', 'DAMAGED', 'RECALL', 'UPGRADE', 'ERROR'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => reason = value ?? reason)),
        const SizedBox(height: TaSpace.lg),
        TaCard(child: Text('Animal: brinco ${widget.animal.visualTagNumber} · ${widget.animal.shortDescription}', style: t.bodyMedium)),
        const SizedBox(height: TaSpace.md),
        FilledButton.icon(onPressed: oldIdentifier == null || (rfidController.text.trim().isEmpty && visualController.text.trim().isEmpty) ? null : () => _enqueue(services), icon: const Icon(Icons.sync_alt), label: const Text('Carimbar nova identificação')),
      ]),
    );
  }

  void _enqueue(AppServices services) {
    final rfid = rfidController.text.trim().replaceAll(' ', '');
    final visual = visualController.text.trim();
    services.outbox.enqueue(
      kind: EventKind.reidentification,
      subjectId: widget.animal.animalId,
      animalId: widget.animal.animalId,
      subjectLabel: 'Brinco ${widget.animal.visualTagNumber}',
      payload: {
        'oldIdentifierId': oldIdentifier!.id,
        'newIdentifier': {
          'type': rfid.isNotEmpty ? 'RFID' : 'VISUAL',
          if (rfid.isNotEmpty) 'rfidCode': rfid,
          if (visual.isNotEmpty) 'visualTagNumber': visual,
        },
        'reason': reason,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Troca de brinco na fila de envio')));
    Navigator.of(context).pop();
  }
}
