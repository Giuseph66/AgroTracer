import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/map_area.dart';
import '../theme/map_theme.dart';

/// Camada de rótulos das áreas, com resolução de colisão.
///
/// Um `MarkerLayer` comum empilha rótulos uns sobre os outros: num curral
/// dentro de um piquete, o nome do piquete simplesmente some. Aqui os rótulos
/// são projetados na tela, ordenados por relevância (área maior primeiro) e o
/// que não couber sem sobrepor é omitido — melhor faltar um nome do que exibir
/// dois textos embaralhados que ninguém consegue ler.
///
/// Áreas pequenas demais na tela também não recebem rótulo: escrever "Curral"
/// sobre 8 pixels não informa nada e só suja o mapa.
class AreaLabelsLayer extends StatelessWidget {
  const AreaLabelsLayer({
    super.key,
    required this.areas,
    this.selectedAreaId,
    this.obstacles = const [],
    this.obstacleSize = 26,
    this.minimumScreenSize = 48,
  });

  final List<MapArea> areas;
  final String? selectedAreaId;

  /// Pontos que já ocupam espaço na tela — tipicamente os marcadores de
  /// animal. Entram na conta de colisão para que um rótulo não apague o
  /// marcador que o operador está procurando.
  final List<MapMarker> obstacles;
  final double obstacleSize;

  /// Lado mínimo, em pixels, que a área precisa ocupar para merecer rótulo.
  final double minimumScreenSize;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final theme = MapTheme.of(context);

    // Mais relevante primeiro: a seleção sempre aparece, depois as maiores.
    final ordered = [...areas]..sort((a, b) {
        if (a.id == selectedAreaId) return -1;
        if (b.id == selectedAreaId) return 1;
        return b.areaHectares.compareTo(a.areaHectares);
      });

    // Marcadores já estão na tela e não saem do lugar: reservam espaço antes
    // de qualquer rótulo disputar posição.
    final placed = <Rect>[
      for (final marker in obstacles)
        Rect.fromCenter(
          center: _offsetOf(camera, marker.position.toLatLng()),
          width: obstacleSize,
          height: obstacleSize,
        ),
    ];
    final labels = <Widget>[];

    for (final area in ordered) {
      final screenSize = _screenExtent(camera, area);
      final selected = area.id == selectedAreaId;

      if (!selected &&
          (screenSize.width < minimumScreenSize ||
              screenSize.height < minimumScreenSize)) {
        continue;
      }

      final center = camera.latLngToScreenPoint(area.center.toLatLng());
      final size = _labelSize(area);
      final rect = Rect.fromCenter(
        center: Offset(center.x, center.y),
        width: size.width,
        height: size.height,
      );

      // Fora da tela não precisa ser desenhado nem disputa espaço.
      final viewport = Rect.fromLTWH(0, 0, camera.size.x, camera.size.y);
      if (!rect.overlaps(viewport)) continue;

      final collides = placed.any((other) => other.overlaps(rect.inflate(2)));
      if (collides && !selected) continue;

      placed.add(rect);
      labels.add(
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: _AreaLabel(area: area, selected: selected, theme: theme),
        ),
      );
    }

    return IgnorePointer(child: Stack(children: labels));
  }

  Offset _offsetOf(MapCamera camera, LatLng latLng) {
    final p = camera.latLngToScreenPoint(latLng);
    return Offset(p.x, p.y);
  }

  /// Quanto a área ocupa na tela, em pixels, no zoom corrente.
  Size _screenExtent(MapCamera camera, MapArea area) {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;

    for (final point in area.ring) {
      final p = camera.latLngToScreenPoint(point.toLatLng());
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    return Size(maxX - minX, maxY - minY);
  }

  Size _labelSize(MapArea area) {
    // Largura estimada pela maior das duas linhas — nome e medida. Medir texto
    // de verdade exigiria layout por rótulo, e a estimativa basta para decidir
    // colisão nesta escala; o texto ainda encolhe se a conta ficar curta.
    final measure = area.animalCount > 0
        ? '${area.formattedArea} · ${area.animalCount}'
        : area.formattedArea;
    final characters =
        area.name.length > measure.length ? area.name.length : measure.length;
    final width = (characters * 7.5 + 40).clamp(80.0, 160.0);
    return Size(width, 42);
  }
}

class _AreaLabel extends StatelessWidget {
  const _AreaLabel({
    required this.area,
    required this.selected,
    required this.theme,
  });

  final MapArea area;
  final bool selected;
  final MapTheme theme;

  @override
  Widget build(BuildContext context) {
    final stroke = theme.strokeFor(area.healthStatus);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.paper.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? theme.tagYellow : stroke,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.stamp.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              area.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.ink,
                height: 1.1,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(theme.iconFor(area.healthStatus), size: 11, color: stroke),
                const SizedBox(width: 3),
                // A largura do rótulo é estimada pelo nome; quando a medida
                // sai maior que a estimativa, o texto encolhe em vez de
                // estourar a caixa com a faixa de overflow.
                Flexible(
                  child: Text(
                    area.animalCount > 0
                        ? '${area.formattedArea} · ${area.animalCount}'
                        : area.formattedArea,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.inkSoft,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
