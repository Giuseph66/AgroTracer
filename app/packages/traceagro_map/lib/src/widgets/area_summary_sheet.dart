import 'package:flutter/material.dart';

import '../models/map_area.dart';
import '../theme/map_theme.dart';

/// Ficha da área selecionada: o que ela mede, quantos animais tem e qual a
/// restrição vigente.
///
/// É o segundo passo do fluxo do mapa — a cor diz *onde* olhar, esta ficha diz
/// *o que* está acontecendo e oferece a ação (ver os animais dali).
class AreaSummarySheet extends StatelessWidget {
  const AreaSummarySheet({
    super.key,
    required this.area,
    this.onShowAnimals,
    this.onEditBoundary,
    this.onClose,
  });

  final MapArea area;

  /// "Quais animais estão nesta área" — a pergunta que motiva abrir a ficha.
  final VoidCallback? onShowAnimals;
  final VoidCallback? onEditBoundary;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = MapTheme.of(context);
    final stroke = theme.strokeFor(area.healthStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: theme.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.kind.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: theme.inkSoft,
                      ),
                    ),
                    Text(
                      area.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: theme.inkSoft),
                  tooltip: 'Fechar',
                ),
            ],
          ),

          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.fillFor(area.healthStatus),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: stroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(theme.iconFor(area.healthStatus), size: 14, color: stroke),
                const SizedBox(width: 6),
                Text(
                  area.healthStatus.label,
                  style: TextStyle(
                    color: stroke,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _Stat(
                value: area.formattedArea,
                label: 'área medida',
                theme: theme,
              ),
              _Stat(
                value: '${area.animalCount}',
                label: area.animalCount == 1 ? 'animal' : 'animais',
                theme: theme,
              ),
              _Stat(
                value: area.stockingRate == null
                    ? '—'
                    : area.stockingRate!.toStringAsFixed(1).replaceAll('.', ','),
                label: 'cab/ha',
                theme: theme,
              ),
            ],
          ),

          if (area.herdLotName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 18, color: theme.inkSoft),
                const SizedBox(width: 8),
                Text(
                  'Lote ${area.herdLotName}',
                  style: TextStyle(color: theme.ink, fontSize: 14),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              if (onShowAnimals != null)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.tagYellow,
                      foregroundColor: theme.stamp,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onShowAnimals,
                    icon: const Icon(Icons.pets),
                    label: const Text('Ver animais'),
                  ),
                ),
              if (onShowAnimals != null && onEditBoundary != null)
                const SizedBox(width: 8),
              if (onEditBoundary != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.ink,
                      side: BorderSide(color: theme.ink, width: 1.5),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onEditBoundary,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar contorno'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.theme});

  final String value;
  final String label;
  final MapTheme theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.pasture,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: theme.inkSoft)),
        ],
      ),
    );
  }
}
