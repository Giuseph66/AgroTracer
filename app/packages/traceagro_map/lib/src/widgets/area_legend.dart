import 'package:flutter/material.dart';

import '../models/map_area.dart';
import '../theme/map_theme.dart';

/// Legenda das cores do mapa.
///
/// Cor sozinha não é interface: quem chega no aplicativo pela primeira vez
/// precisa saber o que o contorno barro significa antes de decidir qualquer
/// coisa por ele.
class AreaLegend extends StatelessWidget {
  const AreaLegend({
    super.key,
    this.statuses = const [
      AreaHealthStatus.clear,
      AreaHealthStatus.withdrawal,
      AreaHealthStatus.blocked,
      AreaHealthStatus.empty,
    ],
    this.compact = false,
    this.onDark = true,
  });

  final List<AreaHealthStatus> statuses;
  final bool compact;

  /// A legenda costuma ficar sobre o mapa, que é escuro.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = MapTheme.of(context);
    final textColor = onDark ? theme.paperInk : theme.ink;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: (onDark ? theme.pasture : theme.paper).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (onDark ? theme.paperInk : theme.line).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in statuses)
            Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 12 : 14,
                    height: compact ? 12 : 14,
                    decoration: BoxDecoration(
                      color: theme.fillFor(status),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: theme.strokeFor(status), width: 2),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: compact ? 11 : 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
