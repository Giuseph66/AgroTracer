import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/hardware/rfid_hardware_capture.dart';
import '../../core/services.dart';
import '../../core/sync/outbox.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ear_tag.dart';
import '../../domain/models.dart';

/// UC-02 — pesagem em brete. O ciclo é sempre o mesmo: o brinco entra, o peso
/// aparece, o operador confirma. Nada além disso pode estar no caminho, porque
/// o animal já está na balança e a fila não espera.
class WeighingScreen extends StatefulWidget {
  const WeighingScreen({super.key});

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

enum _Step { waitingTag, waitingScale, ready }

class _WeighingScreenState extends State<WeighingScreen>
    with RfidHardwareCapture {
  final _random = Random();
  final _manualController = TextEditingController();

  _Step step = _Step.waitingTag;
  Animal? animal;
  double? weightKg;
  bool scaleStable = false;
  bool manualEntry = false;
  Timer? _timer;

  /// Registradas nesta sessão de brete, mais recente primeiro.
  final List<OutboxEntry> session = [];

  @override
  bool get rfidCapturePaused => step != _Step.waitingTag;

  @override
  void dispose() {
    _timer?.cancel();
    _manualController.dispose();
    disposeRfidCapture();
    super.dispose();
  }

  /// Leitor USB físico: só reage enquanto aguarda brinco (Doc 8 §10);
  /// brinco desconhecido no brete não interrompe a fila — só avisa, porque
  /// o animal já está na balança.
  @override
  void onRfidScan(String code) {
    final match = Services.of(context).herd.byRfid(code);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brinco não encontrado: $code')),
      );
      return;
    }
    _startWeighing(match);
  }

  void _readTag() {
    final pool = Services.of(context).herd.animals;
    if (pool.isEmpty) return;
    _startWeighing(pool[_random.nextInt(pool.length)]);
  }

  void _startWeighing(Animal a) {
    setState(() {
      animal = a;
      step = _Step.waitingScale;
      weightKg = null;
      scaleStable = false;
      manualEntry = false;
    });

    // A balança leva um instante para estabilizar; o app não aceita valor
    // instável, porque peso oscilando vira pesagem errada no histórico.
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        weightKg = (a.lastWeightKg + _random.nextDouble() * 12 - 2)
            .clamp(15, 1500)
            .toDouble();
        scaleStable = true;
        step = _Step.ready;
      });
    });
  }

  void _useManualWeight() {
    final parsed =
        double.tryParse(_manualController.text.replaceAll(',', '.'));
    if (parsed == null) return;
    setState(() {
      weightKg = parsed;
      scaleStable = true;
      manualEntry = true;
      step = _Step.ready;
    });
  }

  void _confirm() {
    final services = Services.of(context);
    final a = animal!;
    final kg = double.parse(weightKg!.toStringAsFixed(1));

    // O evento nasce aqui: hash calculado no aparelho, sequência do dispositivo
    // atribuída, estado PENDING_SYNC. A partir deste ponto ele é imutável.
    final entry = services.outbox.enqueue(
      kind: EventKind.weighing,
      subjectId: a.animalId,
      animalId: a.animalId,
      subjectLabel: 'Brinco ${a.visualTagNumber}',
      payload: {
        'weightKg': kg,
        'weightSource': manualEntry ? 'MANUAL' : 'SCALE',
        if (!manualEntry) 'scaleId': 'AT-2',
        'stabilityFlag': scaleStable,
      },
    );

    services.herd.applyLocalWeighing(a.animalId, kg);
    unawaited(services.sync.sync());

    HapticFeedback.mediumImpact();
    setState(() {
      session.insert(0, entry);
      step = _Step.waitingTag;
      animal = null;
      weightKg = null;
      _manualController.clear();
    });
    requestRfidFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: TaColors.pasture,
      appBar: AppBar(
        backgroundColor: TaColors.pasture,
        foregroundColor: TaColors.paperInk,
        title: Text('Pesagem no brete',
            style: t.titleLarge!.copyWith(color: TaColors.paperInk)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TaSpace.md),
            child: Center(
              child: Text('Balança AT-2',
                  style: t.labelSmall!.copyWith(color: TaColors.paperInkSoft)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          focusNode: rfidFocusNode,
          autofocus: true,
          onKeyEvent: onRfidKeyEvent,
          child: Column(
            children: [
              Expanded(child: _buildStage(context)),
              _SessionStrip(entries: session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (step == _Step.waitingTag) {
      return Padding(
        padding: const EdgeInsets.all(TaSpace.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: _readTag,
              customBorder: const CircleBorder(),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TaColors.tagYellow,
                  border:
                      Border.all(color: TaColors.tagYellowDeep, width: 3),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors, size: 56, color: TaColors.stamp),
                    SizedBox(height: 6),
                    Text('Passar animal',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: TaColors.stamp)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TaSpace.lg),
            Text('O brinco entra e o peso vem sozinho.',
                style: t.bodyMedium!.copyWith(color: TaColors.paperInkSoft)),
          ],
        ),
      );
    }

    final a = animal!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TaSpace.md),
      child: Column(
        children: [
          EarTag(number: a.visualTagNumber, size: EarTagSize.medium),
          const SizedBox(height: TaSpace.sm),
          Text(a.shortDescription,
              style: t.titleMedium!.copyWith(color: TaColors.paperInk)),
          Text(
            'último peso ${a.lastWeightKg.toStringAsFixed(1).replaceAll('.', ',')} kg',
            style: t.bodySmall!.copyWith(color: TaColors.paperInkSoft),
          ),
          const SizedBox(height: TaSpace.lg),
          _WeightDisplay(
            weightKg: weightKg,
            stable: scaleStable,
            manual: manualEntry,
          ),
          const SizedBox(height: TaSpace.md),
          if (step == _Step.ready) ...[
            _variationHint(context, a),
            const SizedBox(height: TaSpace.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Confirmar e liberar'),
              ),
            ),
          ],
          const SizedBox(height: TaSpace.sm),
          _manualRow(context),
          TextButton(
            onPressed: () {
              setState(() {
                step = _Step.waitingTag;
                animal = null;
                weightKg = null;
              });
              requestRfidFocus();
            },
            child: Text('Descartar animal',
                style: t.bodySmall!.copyWith(color: TaColors.paperInkSoft)),
          ),
        ],
      ),
    );
  }

  /// Variação grande não bloqueia — alerta. Peso é fato observado; travar a
  /// fila do brete por suspeita custa mais do que revisar depois (Doc 5 §4.3).
  Widget _variationHint(BuildContext context, Animal a) {
    if (weightKg == null || a.lastWeightKg <= 0) return const SizedBox.shrink();
    final delta = (weightKg! - a.lastWeightKg) / a.lastWeightKg;
    if (delta.abs() < 0.30) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(TaSpace.sm),
      decoration: BoxDecoration(
        color: TaColors.clayBg,
        borderRadius: BorderRadius.circular(TaRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: TaColors.clay, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Variação de ${(delta * 100).abs().toStringAsFixed(0)}% desde a última '
              'pesagem. Registra assim mesmo e marca para revisão.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: TaColors.clay),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _manualController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: TaColors.paperInk),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Digitar peso (kg)',
              hintStyle: const TextStyle(color: TaColors.paperInkSoft),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TaRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: TaSpace.sm),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: TaColors.paperInk,
            side: const BorderSide(color: TaColors.paperInkSoft),
          ),
          onPressed: _useManualWeight,
          child: const Text('Usar'),
        ),
      ],
    );
  }
}

class _WeightDisplay extends StatelessWidget {
  const _WeightDisplay({
    required this.weightKg,
    required this.stable,
    required this.manual,
  });

  final double? weightKg;
  final bool stable;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final waiting = weightKg == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: TaSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: const BorderRadius.all(TaRadius.rLg),
        border: Border.all(
          color: waiting ? TaColors.paperInkSoft : TaColors.tagYellow,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (waiting) ...[
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  color: TaColors.tagYellow, strokeWidth: 3),
            ),
            const SizedBox(height: TaSpace.sm),
            Text('Estabilizando…',
                style: t.bodyMedium!.copyWith(color: TaColors.paperInkSoft)),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  weightKg!.toStringAsFixed(1).replaceAll('.', ','),
                  style: t.displayLarge!
                      .copyWith(color: TaColors.tagYellow, fontSize: 64),
                ),
                const SizedBox(width: 6),
                Text('kg',
                    style:
                        t.titleLarge!.copyWith(color: TaColors.paperInkSoft)),
              ],
            ),
            Text(
              manual ? 'digitado pelo operador' : 'balança estável',
              style: t.bodySmall!.copyWith(color: TaColors.paperInkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fita da sessão: o operador precisa ver que o registro anterior entrou, sem
/// sair da tela nem esperar sincronização.
class _SessionStrip extends StatelessWidget {
  const _SessionStrip({required this.entries});
  final List<OutboxEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(TaSpace.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: const BorderRadius.vertical(top: TaRadius.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${entries.length}',
                  style: t.headlineMedium!.copyWith(color: TaColors.tagYellow)),
              const SizedBox(width: TaSpace.sm),
              Expanded(
                child: Text('pesagens nesta sessão',
                    style:
                        t.bodyMedium!.copyWith(color: TaColors.paperInkSoft)),
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: TaSpace.sm),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final kg = e.envelope.payload['weightKg'];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Text('${e.subjectLabel} · $kg kg',
                            style: t.bodySmall!
                                .copyWith(color: TaColors.paperInk)),
                        const SizedBox(width: 6),
                        SyncBadge(e.state, compact: true),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
