import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/hardware/rfid_hardware_capture.dart';
import '../../core/services.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ear_tag.dart';
import '../../domain/models.dart';
import '../animal/animal_screen.dart';
import '../animals/animals_screen.dart' show openRegisterAnimalSheet;

/// M24/M25 — Leitura RFID. Três estados: aguardando leitura, animal
/// identificado, brinco desconhecido (caminho controlado do Doc 8 §10).
class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

enum _ReadPhase { idle, reading, found, unknown }

class _ReadScreenState extends State<ReadScreen> with RfidHardwareCapture {
  _ReadPhase phase = _ReadPhase.idle;
  Animal? animal;
  String? rawRfid;
  Timer? _timer;
  int _readCount = 12;
  bool _readerSeen = false;

  @override
  bool get rfidCapturePaused =>
      phase == _ReadPhase.found || phase == _ReadPhase.unknown;

  @override
  void dispose() {
    _timer?.cancel();
    disposeRfidCapture();
    super.dispose();
  }

  @override
  void onRfidScan(String code) {
    final herd = Services.of(context).herd;
    final match = herd.byRfid(code);
    setState(() {
      _readerSeen = true;
      if (match != null) {
        animal = match;
        rawRfid = match.rfidCode;
        phase = _ReadPhase.found;
        _readCount++;
      } else {
        animal = null;
        rawRfid = code;
        phase = _ReadPhase.unknown;
      }
    });
  }

  void _resetToIdle() {
    setState(() => phase = _ReadPhase.idle);
    requestRfidFocus();
  }

  Future<void> _openRawRegistration() async {
    final services = Services.of(context);
    await openRegisterAnimalSheet(context, services, initialRfid: rawRfid);
    if (!mounted) return;
    _resetToIdle();
  }

  void _simulateRead({required bool known}) {
    setState(() => phase = _ReadPhase.reading);
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final herd = Services.of(context).herd;
      setState(() {
        if (known && herd.animals.isNotEmpty) {
          animal = herd.animals.first;
          rawRfid = animal!.rfidCode;
          phase = _ReadPhase.found;
          _readCount++;
        } else {
          animal = null;
          rawRfid = '982 000999888777';
          phase = _ReadPhase.unknown;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: TaColors.pasture,
      appBar: AppBar(
        backgroundColor: TaColors.pasture,
        foregroundColor: TaColors.paperInk,
        title: Text('Leitura RFID',
            style: t.titleLarge!.copyWith(color: TaColors.paperInk)),
        actions: [
          if (_readerSeen)
            Padding(
              padding: const EdgeInsets.only(right: TaSpace.md),
              child: Center(
                child: Text('LEITOR CONECTADO',
                    style: t.labelSmall!.copyWith(color: TaColors.sage)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          focusNode: rfidFocusNode,
          autofocus: true,
          onKeyEvent: onRfidKeyEvent,
          child: Padding(
            padding: const EdgeInsets.all(TaSpace.md),
            child: Column(
              children: [
                Expanded(child: Center(child: _buildPhase(context))),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context) {
    final t = Theme.of(context).textTheme;
    switch (phase) {
      case _ReadPhase.idle:
      case _ReadPhase.reading:
        final reading = phase == _ReadPhase.reading;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: reading ? null : () => _simulateRead(known: true),
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reading
                      ? TaColors.tagYellow.withValues(alpha: .25)
                      : TaColors.tagYellow,
                  border: Border.all(color: TaColors.tagYellowDeep, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    reading
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                                color: TaColors.tagYellow, strokeWidth: 5),
                          )
                        : const Icon(Icons.sensors,
                            size: 64, color: TaColors.stamp),
                    const SizedBox(height: TaSpace.sm),
                    Text(
                      reading ? 'Lendo…' : 'Aproximar\ndo brinco',
                      textAlign: TextAlign.center,
                      style: t.titleMedium!.copyWith(
                          color: reading
                              ? TaColors.paperInk
                              : TaColors.stamp),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TaSpace.lg),
            TextButton(
              onPressed: reading ? null : () => _simulateRead(known: false),
              child: Text('Simular brinco desconhecido',
                  style: t.bodySmall!
                      .copyWith(color: TaColors.paperInkSoft)),
            ),
          ],
        );

      case _ReadPhase.found:
        final a = animal!;
        return SingleChildScrollView(
          child: Column(
            children: [
              Text('Brinco lido · qualidade boa',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: TaColors.paperInkSoft)),
              const SizedBox(height: TaSpace.md),
              EarTag(
                  number: a.visualTagNumber,
                  rfid: a.rfidCode,
                  size: EarTagSize.large),
              const SizedBox(height: TaSpace.md),
              Text(a.shortDescription,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(color: TaColors.paperInk)),
              const SizedBox(height: 4),
              Wrap(
                spacing: TaSpace.sm,
                children: [
                  _statChip('${a.lastWeightKg.toStringAsFixed(1).replaceAll('.', ',')} kg'),
                  _statChip('GMD ${a.gmdKgDay.toStringAsFixed(2).replaceAll('.', ',')} kg/dia'),
                  _statChip(a.status.label),
                ],
              ),
              const SizedBox(height: TaSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AnimalScreen(animal: a)));
                      },
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Abrir animal'),
                    ),
                  ),
                  const SizedBox(width: TaSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TaColors.paperInk,
                        side: const BorderSide(
                            color: TaColors.paperInkSoft, width: 1.5),
                      ),
                      onPressed: () => _resetToIdle(),
                      icon: const Icon(Icons.sensors),
                      label: const Text('Próximo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case _ReadPhase.unknown:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, size: 56, color: TaColors.tagYellow),
            const SizedBox(height: TaSpace.md),
            Text('Brinco não identificado',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(color: TaColors.paperInk)),
            const SizedBox(height: TaSpace.sm),
            Text(rawRfid!,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: TaColors.tagYellow, fontSize: 16)),
            const SizedBox(height: TaSpace.sm),
            Text(
              'Este brinco não está no banco desta propriedade.\n'
              'Registre a ocorrência: ela vira pendência de resolução\nna sincronização.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: TaColors.paperInkSoft),
            ),
            const SizedBox(height: TaSpace.lg),
            FilledButton.icon(
              onPressed: () => _openRawRegistration(),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Registrar com brinco bruto'),
            ),
            TextButton(
              onPressed: () => _resetToIdle(),
              child: Text('Descartar leitura',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: TaColors.paperInkSoft)),
            ),
          ],
        );
    }
  }

  Widget _statChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: TaColors.paperInk, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(TaSpace.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: const BorderRadius.all(TaRadius.rLg),
      ),
      child: Row(
        children: [
          Text('$_readCount',
              style: t.headlineMedium!.copyWith(color: TaColors.tagYellow)),
          const SizedBox(width: TaSpace.sm),
          Expanded(
            child: Text('lidos agora · Lote Recria 12',
                style: t.bodyMedium!.copyWith(color: TaColors.paperInkSoft)),
          ),
          const SyncBadge(SyncState.pendingSync, compact: true),
        ],
      ),
    );
  }
}
