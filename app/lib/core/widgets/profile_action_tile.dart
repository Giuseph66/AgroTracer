import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bloco de ação do Início: ícone grande + palavra, área inteira tocável.
/// Reconhecível pela figura e pelo texto juntos — nunca só pela cor.
class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.minHeight = 104,
    this.iconSize = 36,
    this.largeLabel = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Amarelo-brinco: a ação mais frequente do perfil.
  final bool primary;
  final double minHeight;
  final double iconSize;
  final bool largeLabel;

  /// Itens que pedem atenção (ex.: registros com conflito).
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = primary ? TaColors.stamp : TaColors.ink;
    const radius = BorderRadius.all(TaRadius.rLg);
    final style = (largeLabel ? t.titleLarge! : t.titleMedium!).copyWith(
      color: fg,
      height: 1.15,
    );

    return Semantics(
      button: true,
      label: badgeCount > 0 ? '$label, $badgeCount para resolver' : label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: primary ? TaColors.tagYellow : TaColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: primary ? TaColors.tagYellowDeep : TaColors.line,
            width: primary ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TaSpace.sm,
                vertical: TaSpace.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: badgeCount > 0,
                    backgroundColor: TaColors.clay,
                    label: Text('$badgeCount'),
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: primary ? TaColors.stamp : TaColors.pasture,
                    ),
                  ),
                  const SizedBox(height: TaSpace.sm),
                  Text(label, textAlign: TextAlign.center, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
