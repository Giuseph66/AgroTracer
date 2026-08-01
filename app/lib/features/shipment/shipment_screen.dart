import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../domain/models.dart';

const _uuid = Uuid();

class ShipmentScreen extends StatefulWidget {
  const ShipmentScreen({super.key});

  @override
  State<ShipmentScreen> createState() => _ShipmentScreenState();
}

class _ShipmentScreenState extends State<ShipmentScreen> {
  String purpose = 'MANEJO';
  final destinationController = TextEditingController();
  final plateController = TextEditingController();
  final selected = <String>{};

  @override
  void dispose() {
    destinationController.dispose();
    plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Embarques'),
        backgroundColor: TaColors.pasture,
        foregroundColor: TaColors.paperInk,
      ),
      body: ListenableBuilder(
        listenable: services.herd,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(TaSpace.md),
          children: [
            Text('Movimentar rebanho', style: t.displayMedium),
            Text(
              'A expedição registra a saída e leva os animais ao estado em trânsito.',
              style: t.bodySmall,
            ),
            const SizedBox(height: TaSpace.lg),
            const SectionLabel('Embarques recentes'),
            const SizedBox(height: TaSpace.sm),
            if (services.herd.shipments.isEmpty)
              const TaCard(
                child: Text('Nenhum embarque registrado nesta propriedade.'),
              )
            else
              for (final shipment in services.herd.shipments)
                _ShipmentCard(
                  shipment: shipment,
                  onTap: () => _openShipmentDetail(context, services, shipment),
                ),
            const SizedBox(height: TaSpace.lg),
            const SectionLabel('Nova expedição'),
            const SizedBox(height: TaSpace.sm),
            TextField(
              controller: destinationController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ID da propriedade destino',
                hintText: 'UUID da propriedade',
              ),
            ),
            const SizedBox(height: TaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: purpose,
                    decoration: const InputDecoration(labelText: 'Finalidade'),
                    items: const ['MANEJO', 'ABATE', 'VENDA', 'TRANSFERENCIA']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => purpose = value ?? purpose),
                  ),
                ),
                const SizedBox(width: TaSpace.sm),
                Expanded(
                  child: TextField(
                    controller: plateController,
                    decoration: const InputDecoration(
                      labelText: 'Placa (opcional)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TaSpace.md),
            Text(
              '${selected.length} animal(is) selecionado(s)',
              style: t.labelMedium,
            ),
            const SizedBox(height: TaSpace.sm),
            for (final animal in services.herd.animals)
              _AnimalChoice(
                animal: animal,
                selected: selected.contains(animal.animalId),
                onTap: () => setState(
                  () => selected.contains(animal.animalId)
                      ? selected.remove(animal.animalId)
                      : selected.add(animal.animalId),
                ),
              ),
            const SizedBox(height: TaSpace.md),
            FilledButton.icon(
              onPressed:
                  selected.isEmpty || destinationController.text.trim().isEmpty
                  ? null
                  : () => _dispatch(services),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Expedir embarque'),
            ),
          ],
        ),
      ),
    );
  }

  void _dispatch(AppServices services) {
    final shipmentId = _uuid.v7();
    services.outbox.enqueue(
      kind: EventKind.shipmentDispatched,
      subjectId: shipmentId,
      subjectType: 'SHIPMENT',
      subjectLabel: 'Embarque ${shipmentId.substring(0, 8)}',
      payload: {
        'shipmentId': shipmentId,
        'animalIds': selected.toList(),
        'destinationPropertyId': destinationController.text.trim(),
        'purpose': purpose,
        'vehiclePlate': plateController.text.trim().isEmpty
            ? null
            : plateController.text.trim(),
      },
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Embarque na fila de envio')));
    Navigator.of(context).pop();
  }

  Future<void> _openShipmentDetail(
    BuildContext context,
    AppServices services,
    Shipment shipment,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _ShipmentDetailSheet(services: services, shipment: shipment),
    );
    if (changed == true && context.mounted) {
      await services.herd.refreshShipments();
    }
  }
}

class _AnimalChoice extends StatelessWidget {
  const _AnimalChoice({
    required this.animal,
    required this.selected,
    required this.onTap,
  });
  final Animal animal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TaSpace.sm),
    child: TaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: TaSpace.sm, vertical: 3),
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: (_) => onTap()),
          Expanded(
            child: Text(
              'Brinco ${animal.visualTagNumber} · ${animal.lot}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (animal.withdrawalUntil != null)
            const Icon(Icons.warning_amber_rounded, color: TaColors.clay),
        ],
      ),
    ),
  );
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment, required this.onTap});
  final Shipment shipment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: TaSpace.sm),
    child: TaCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            shipment.status == 'RECEIVED'
                ? Icons.inventory_2_outlined
                : Icons.local_shipping_outlined,
            color: shipment.discrepancyCount > 0 ? TaColors.clay : TaColors.sky,
          ),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shipment.purpose,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${shipment.receivedCount}/${shipment.animalCount} conferidos · ${shipment.status}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (shipment.discrepancyCount > 0)
            Text(
              '${shipment.discrepancyCount} divergência(s)',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: TaColors.clay,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Icon(Icons.chevron_right, color: TaColors.inkSoft),
        ],
      ),
    ),
  );
}

class _ShipmentDetailSheet extends StatefulWidget {
  const _ShipmentDetailSheet({required this.services, required this.shipment});

  final AppServices services;
  final Shipment shipment;

  @override
  State<_ShipmentDetailSheet> createState() => _ShipmentDetailSheetState();
}

class _ShipmentDetailSheetState extends State<_ShipmentDetailSheet> {
  late final Future<ShipmentDetail> _detail;
  final received = <String>{};
  final gtaNumber = TextEditingController();
  final gtaUf = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.services.api.shipmentDetail(widget.shipment.shipmentId);
  }

  @override
  void dispose() {
    gtaNumber.dispose();
    gtaUf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      TaSpace.md,
      TaSpace.md,
      TaSpace.md,
      MediaQuery.viewInsetsOf(context).bottom + TaSpace.md,
    ),
    child: FutureBuilder<ShipmentDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final detail = snapshot.data!;
        final canReceive = detail.status == 'DISPATCHED';
        return ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Conferir embarque',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${detail.animals.length} animal(is) · ${detail.status}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: TaSpace.md),
            const SectionLabel('Leitura de chegada'),
            const SizedBox(height: TaSpace.sm),
            for (final animal in detail.animals)
              CheckboxListTile(
                value: received.contains(animal.animalId) || animal.received,
                onChanged: canReceive
                    ? (value) => setState(() {
                        if (value == true) {
                          received.add(animal.animalId);
                        } else {
                          received.remove(animal.animalId);
                        }
                      })
                    : null,
                title: Text('Brinco ${animal.label}'),
                subtitle: animal.discrepancy == null
                    ? null
                    : Text(animal.discrepancy!),
                secondary: Icon(
                  animal.discrepancy == null
                      ? Icons.pets_outlined
                      : Icons.warning_amber_rounded,
                  color: animal.discrepancy == null
                      ? TaColors.sage
                      : TaColors.clay,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            if (canReceive)
              FilledButton.icon(
                onPressed: sending ? null : () => _receive(detail),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Fechar conferência (${received.length})'),
              ),
            const SizedBox(height: TaSpace.md),
            const SectionLabel('GTA manual'),
            const SizedBox(height: TaSpace.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: gtaNumber,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Número'),
                  ),
                ),
                const SizedBox(width: TaSpace.sm),
                SizedBox(
                  width: 78,
                  child: TextField(
                    controller: gtaUf,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'UF',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TaSpace.sm),
            OutlinedButton.icon(
              onPressed:
                  sending ||
                      gtaNumber.text.trim().isEmpty ||
                      gtaUf.text.trim().length != 2
                  ? null
                  : () => _registerGta(detail),
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(
                detail.gtaNumber == null ? 'Registrar GTA' : 'Atualizar GTA',
              ),
            ),
          ],
        );
      },
    ),
  );

  void _receive(ShipmentDetail detail) {
    setState(() => sending = true);
    widget.services.outbox.enqueue(
      kind: EventKind.shipmentReceived,
      subjectId: detail.shipmentId,
      subjectType: 'SHIPMENT',
      subjectLabel: 'Recebimento ${detail.shipmentId.substring(0, 8)}',
      payload: {
        'shipmentId': detail.shipmentId,
        'readAnimalIds': received.toList(),
      },
    );
    Navigator.of(context).pop(true);
  }

  void _registerGta(ShipmentDetail detail) {
    setState(() => sending = true);
    widget.services.outbox.enqueue(
      kind: EventKind.gtaRegistered,
      subjectId: detail.shipmentId,
      subjectType: 'SHIPMENT',
      subjectLabel: 'GTA ${gtaNumber.text.trim()}',
      payload: {
        'shipmentId': detail.shipmentId,
        'gtaNumber': gtaNumber.text.trim(),
        'gtaUf': gtaUf.text.trim().toUpperCase(),
      },
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('GTA na fila de envio')));
    Navigator.of(context).pop(true);
  }
}
