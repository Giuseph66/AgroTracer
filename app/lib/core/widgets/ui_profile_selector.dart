import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../ui_profile/ui_profile.dart';
import '../ui_profile/ui_profile_scope.dart';
import 'common.dart';
import 'equal_height_grid.dart';

/// "Modo da interface": cartões grandes, um por modo, com Automático primeiro.
/// A troca vale no toque — sem sair da conta nem reiniciar o app.
class UiProfileSelector extends StatelessWidget {
  const UiProfileSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = UiProfileScope.of(context);
    final t = Theme.of(context).textTheme;

    void choose(UiProfile? profile) {
      HapticFeedback.selectionClick();
      prefs.setPreference(profile);
    }

    final cards = <Widget>[
      _ModeCard(
        icon: Icons.auto_mode_outlined,
        title: 'Automático',
        description: 'Escolhe o modo recomendado para seu perfil.',
        // Diz o que o automático escolheu; sem isso a pessoa não sabe o que
        // vai ver ao deixar nesta opção.
        detail: 'Agora: ${prefs.automatic.label}',
        selected: prefs.isAutomatic,
        onTap: () => choose(null),
      ),
      for (final profile in UiProfile.values)
        _ModeCard(
          icon: profile.icon,
          title: profile.label,
          description: profile.description,
          selected: prefs.preference == profile,
          onTap: () => choose(profile),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Modo da interface'),
        const SizedBox(height: TaSpace.sm),
        // Tablet/web: duas colunas. Telefone: uma, cartão inteiro tocável.
        EqualHeightGrid(
          columnsFor: (width) => width >= 640 ? 2 : 1,
          children: cards,
        ),
        const SizedBox(height: TaSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 16, color: TaColors.inkSoft),
            const SizedBox(width: TaSpace.xs),
            Expanded(
              child: Text(
                'O modo muda apenas a organização das telas. Suas permissões '
                'continuam as mesmas.',
                style: t.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = const BorderRadius.all(TaRadius.rLg);

    // Seleção não depende só de cor: borda mais grossa, ícone de marcado e a
    // palavra "Em uso" dizem a mesma coisa.
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      // Excluir a semântica dos filhos (rótulo único, legível) também tira o
      // toque do InkWell; sem repassá-lo, o leitor de tela não ativa o cartão.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: TaColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? TaColors.tagYellowDeep : TaColors.line,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(TaSpace.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? TaColors.tagYellow : TaColors.paperDim,
                      borderRadius: const BorderRadius.all(TaRadius.rSm),
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: selected ? TaColors.stamp : TaColors.pasture,
                    ),
                  ),
                  const SizedBox(width: TaSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleMedium),
                        Text(description, style: t.bodySmall),
                        if (detail != null)
                          Text(
                            detail!,
                            style: t.bodySmall!.copyWith(
                              color: TaColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TaSpace.sm),
                  if (selected)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: TaColors.pasture),
                        Text(
                          'Em uso',
                          style: t.bodySmall!.copyWith(
                            color: TaColors.pasture,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    const Icon(
                      Icons.radio_button_unchecked,
                      color: TaColors.inkSoft,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
