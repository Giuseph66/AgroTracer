import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: ListenableBuilder(
        listenable: services.herd,
        builder: (context, _) {
          final q = query.replaceAll(' ', '').toLowerCase();
          final animals = services.herd.animals.where((a) {
            if (q.isEmpty) return true;
            return a.visualTagNumber.contains(q) ||
                a.rfidCode.replaceAll(' ', '').contains(q) ||
                (a.officialAnimalId ?? '').replaceAll(' ', '').contains(q) ||
                a.lot.toLowerCase().contains(q);
          }).toList();

          return RefreshIndicator(
            onRefresh: services.herd.refresh,
            child: ListView(
              padding: const EdgeInsets.all(TaSpace.md),
              children: [
                Text('Animais', style: t.displayMedium),
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
      return Column(children: [
        const Icon(Icons.search_off, size: 40, color: TaColors.inkSoft),
        const SizedBox(height: TaSpace.sm),
        Text('Nenhum animal com esse identificador aqui.',
            style: t.bodyMedium),
        Text('Confira o número ou leia o brinco no curral.',
            style: t.bodySmall),
      ]);
    }

    if (unreachable) {
      return Column(children: [
        const Icon(Icons.cloud_off_outlined,
            size: 40, color: TaColors.inkSoft),
        const SizedBox(height: TaSpace.sm),
        Text('O rebanho ainda não foi baixado para este aparelho.',
            style: t.bodyMedium, textAlign: TextAlign.center),
        Text('Conecte-se uma vez para trabalhar offline depois.',
            style: t.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: TaSpace.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
      ]);
    }

    return Column(children: [
      const Icon(Icons.inbox_outlined, size: 40, color: TaColors.inkSoft),
      const SizedBox(height: TaSpace.sm),
      Text('Nenhum animal cadastrado nesta propriedade.',
          style: t.bodyMedium),
      Text('Registre o primeiro pela leitura de brinco.', style: t.bodySmall),
    ]);
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
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AnimalScreen(animal: animal))),
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
                    BorderSide(color: TaColors.tagYellowDeep)),
              ),
              alignment: Alignment.center,
              child: Text(animal.visualTagNumber,
                  style: t.titleMedium!.copyWith(color: TaColors.stamp)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: TaColors.clayBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Carência',
                    style: t.bodySmall!.copyWith(
                        color: TaColors.clay, fontWeight: FontWeight.w700)),
              )
            else
              const Icon(Icons.chevron_right, color: TaColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
