import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../drawing/area_draw_controller.dart';
import '../geo/geodesy.dart';
import '../models/geo_point.dart';
import '../models/map_area.dart';
import '../theme/map_theme.dart';
import '../tiles/tile_source.dart';

/// Editor de área: o operador toca no mapa para marcar cada canto do piquete e
/// vê a medida crescer a cada ponto.
///
/// Duas decisões de campo mandam no desenho desta tela:
/// a medida fica sempre visível, porque o número é o motivo de estar
/// desenhando; e desfazer é uma ação grande e permanente, porque errar o toque
/// com luva é o caso comum, não a exceção.
class AreaDrawMap extends StatefulWidget {
  const AreaDrawMap({
    super.key,
    required this.controller,
    this.referenceAreas = const [],
    this.tileSource = TileSource.satellite,
    this.initialCenter,
    this.initialZoom = 15,
    this.onSave,
    this.onCancel,
    this.title = 'Desenhar piquete',
    this.saveLabel = 'Salvar piquete',
  });

  final AreaDrawController controller;

  /// Áreas já existentes, desenhadas ao fundo para o operador não sobrepor.
  final List<MapArea> referenceAreas;

  final TileSource tileSource;
  final GeoPoint? initialCenter;
  final double initialZoom;

  /// Recebe o contorno válido. Nulo esconde o botão de salvar.
  final ValueChanged<List<GeoPoint>>? onSave;
  final VoidCallback? onCancel;

  final String title;
  final String saveLabel;

  @override
  State<AreaDrawMap> createState() => _AreaDrawMapState();
}

class _AreaDrawMapState extends State<AreaDrawMap> {
  final MapController _map = MapController();

  AreaDrawController get controller => widget.controller;

  GeoPoint get _center {
    if (widget.initialCenter != null) return widget.initialCenter!;
    if (controller.vertices.isNotEmpty) {
      return Geodesy.center(controller.vertices);
    }
    final refPoints = widget.referenceAreas.expand((a) => a.ring).toList();
    if (refPoints.isNotEmpty) return Geodesy.center(refPoints);
    return const GeoPoint(-15.78, -47.93);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MapTheme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final vertices = controller.vertices;
        final validation = controller.validation;
        final invalid = validation != null && !validation.isValid;

        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center.toLatLng(),
                  initialZoom: widget.initialZoom,
                  minZoom: widget.tileSource.minZoom,
                  maxZoom: widget.tileSource.maxZoom,
                  backgroundColor: theme.pasture,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) =>
                      controller.addVertex(GeoPoint.fromLatLng(point)),
                ),
                children: [
                  widget.tileSource.buildLayer(),

                  // Áreas já existentes, discretas: servem de referência para
                  // não desenhar em cima do piquete do vizinho.
                  PolygonLayer(
                    polygons: [
                      for (final area in widget.referenceAreas)
                        Polygon(
                          points:
                              area.ring.map((p) => p.toLatLng()).toList(),
                          color: theme.inkSoft.withValues(alpha: 0.12),
                          borderColor: theme.paperInk.withValues(alpha: 0.45),
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),

                  // Contorno em desenho.
                  if (vertices.length >= 3)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: vertices.map((p) => p.toLatLng()).toList(),
                          color: (invalid ? theme.clay : theme.tagYellow)
                              .withValues(alpha: 0.25),
                          borderColor: invalid ? theme.clay : theme.tagYellow,
                          borderStrokeWidth: 3,
                        ),
                      ],
                    )
                  else if (vertices.length == 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: vertices.map((p) => p.toLatLng()).toList(),
                          color: theme.tagYellow,
                          strokeWidth: 3,
                        ),
                      ],
                    ),

                  // Vértices: alvos grandes, arrastáveis para ajustar o canto.
                  DragMarkers(
                    markers: [
                      for (var i = 0; i < vertices.length; i++)
                        DragMarker(
                          key: ValueKey('vertex-$i-${vertices[i]}'),
                          point: vertices[i].toLatLng(),
                          size: const Size(40, 40),
                          index: i,
                          selected: controller.selectedIndex == i,
                          theme: theme,
                          onDragEnd: (p) =>
                              controller.moveVertex(i, GeoPoint.fromLatLng(p)),
                          onTap: () => controller.select(i),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            _TopBar(
              title: widget.title,
              theme: theme,
              onCancel: widget.onCancel,
            ),

            _MeasurementPanel(
              controller: controller,
              theme: theme,
              onSave: widget.onSave,
              saveLabel: widget.saveLabel,
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.theme, this.onCancel});

  final String title;
  final MapTheme theme;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 8,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.pasture,
              theme.pasture.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            if (onCancel != null)
              IconButton(
                onPressed: onCancel,
                icon: Icon(Icons.arrow_back, color: theme.paperInk),
                tooltip: 'Sair sem salvar',
              )
            else
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.paperInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painel inferior: medida, aviso e ações. É o que o operador olha; o mapa é
/// só o meio de chegar no número.
class _MeasurementPanel extends StatelessWidget {
  const _MeasurementPanel({
    required this.controller,
    required this.theme,
    required this.saveLabel,
    this.onSave,
  });

  final AreaDrawController controller;
  final MapTheme theme;
  final String saveLabel;
  final ValueChanged<List<GeoPoint>>? onSave;

  @override
  Widget build(BuildContext context) {
    final validation = controller.validation;
    final issue = validation?.firstIssue;
    final stage = controller.stage;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: BoxDecoration(
          color: theme.pasture,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ÁREA MEDIDA',
                        style: TextStyle(
                          color: theme.paperInk.withValues(alpha: 0.6),
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Contorno cruzado tem área matematicamente nula: as
                        // metades se cancelam. Mostrar "0 m²" faria o operador
                        // achar que mediu algo; o traço diz que não há medida.
                        stage == DrawStage.closable && issue == null
                            ? controller.formattedArea
                            : '—',
                        style: TextStyle(
                          color: theme.tagYellow,
                          fontSize: 38,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${controller.vertices.length} pontos',
                      style: TextStyle(
                        color: theme.paperInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      controller.formattedPerimeter,
                      style: TextStyle(
                        color: theme.paperInk.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (issue != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.clay.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.clay),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: theme.clay),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        issue.message,
                        style: TextStyle(color: theme.paperInk, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (stage == DrawStage.idle) ...[
              const SizedBox(height: 8),
              Text(
                'Toque em cada canto do piquete. A medida aparece a partir do '
                'terceiro ponto.',
                style: TextStyle(
                  color: theme.paperInk.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 14),

            Row(
              children: [
                _ActionButton(
                  icon: Icons.undo,
                  label: 'Desfazer',
                  theme: theme,
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Limpar',
                  theme: theme,
                  onPressed: controller.isEmpty ? null : controller.clear,
                ),
                const Spacer(),
                if (onSave != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.tagYellow,
                      foregroundColor: theme.stamp,
                      disabledBackgroundColor:
                          theme.paperInk.withValues(alpha: 0.15),
                      disabledForegroundColor:
                          theme.paperInk.withValues(alpha: 0.4),
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: controller.canSave
                        ? () => onSave!(controller.build()!)
                        : null,
                    icon: const Icon(Icons.check),
                    label: Text(saveLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.theme,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final MapTheme theme;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? theme.paperInk
        : theme.paperInk.withValues(alpha: 0.35);

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Marcadores de vértice arrastáveis.
///
/// O flutter_map não traz marcador arrastável, então o comportamento é montado
/// aqui: converte a posição da tela em coordenada usando a câmera corrente.
class DragMarkers extends StatelessWidget {
  const DragMarkers({super.key, required this.markers});

  final List<DragMarker> markers;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final m in markers)
          Marker(
            key: m.key,
            point: m.point,
            width: m.size.width,
            height: m.size.height,
            child: _DragMarkerWidget(marker: m),
          ),
      ],
    );
  }
}

class DragMarker {
  const DragMarker({
    required this.key,
    required this.point,
    required this.size,
    required this.index,
    required this.selected,
    required this.theme,
    required this.onDragEnd,
    required this.onTap,
  });

  final Key key;
  final LatLng point;
  final Size size;
  final int index;
  final bool selected;
  final MapTheme theme;
  final ValueChanged<LatLng> onDragEnd;
  final VoidCallback onTap;
}

class _DragMarkerWidget extends StatelessWidget {
  const _DragMarkerWidget({required this.marker});

  final DragMarker marker;

  @override
  Widget build(BuildContext context) {
    final theme = marker.theme;
    final camera = MapCamera.maybeOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: marker.onTap,
      onPanUpdate: camera == null
          ? null
          : (details) {
              // Converte o arraste em coordenada: pega o ponto de tela do
              // vértice, soma o deslocamento e volta para lat/lon.
              final screen = camera.latLngToScreenPoint(marker.point);
              final moved = math.Point<double>(
                screen.x + details.delta.dx,
                screen.y + details.delta.dy,
              );
              marker.onDragEnd(camera.pointToLatLng(moved));
            },
      child: Center(
        child: Container(
          width: marker.selected ? 24 : 18,
          height: marker.selected ? 24 : 18,
          decoration: BoxDecoration(
            color: theme.tagYellow,
            shape: BoxShape.circle,
            border: Border.all(color: theme.stamp, width: 2),
          ),
          alignment: Alignment.center,
          child: marker.selected
              ? Text(
                  '${marker.index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: theme.stamp,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
