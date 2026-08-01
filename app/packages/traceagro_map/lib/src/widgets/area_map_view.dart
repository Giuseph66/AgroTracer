import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../geo/geodesy.dart';
import '../models/geo_point.dart';
import '../models/map_area.dart';
import '../theme/map_theme.dart';
import '../tiles/tile_source.dart';
import 'area_labels_layer.dart';

/// Mapa da propriedade: mostra as áreas com a cor da situação sanitária e
/// deixa selecionar uma delas.
///
/// Responde de olhada à pergunta que o operador faz antes de qualquer manejo:
/// onde tem restrição hoje. A resposta detalhada vem do toque na área.
class AreaMapView extends StatefulWidget {
  const AreaMapView({
    super.key,
    required this.areas,
    this.markers = const [],
    this.selectedAreaId,
    this.onAreaSelected,
    this.onAreaLongPress,
    this.tileSource = TileSource.satellite,
    this.initialCenter,
    this.initialZoom = 14,
    this.showLabels = true,
    this.interactive = true,
  });

  final List<MapArea> areas;
  final List<MapMarker> markers;
  final String? selectedAreaId;

  /// Toque numa área. Nulo torna o mapa apenas de leitura.
  final ValueChanged<MapArea>? onAreaSelected;

  /// Toque longo: usado pelo app para abrir a lista de animais da área.
  final ValueChanged<MapArea>? onAreaLongPress;

  final TileSource tileSource;
  final GeoPoint? initialCenter;
  final double initialZoom;
  final bool showLabels;
  final bool interactive;

  @override
  State<AreaMapView> createState() => AreaMapViewState();
}

class AreaMapViewState extends State<AreaMapView> {
  final MapController _controller = MapController();

  /// Enquadra todas as áreas. Público para o app poder chamar depois de
  /// carregar dados novos.
  void fitAllAreas() {
    final points = widget.areas.expand((a) => a.ring).toList();
    if (points.isEmpty) return;
    final (sw, ne) = Geodesy.bounds(points);
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw.toLatLng(), ne.toLatLng()),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void focusArea(MapArea area) {
    final (sw, ne) = Geodesy.bounds(area.ring);
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw.toLatLng(), ne.toLatLng()),
        padding: const EdgeInsets.all(64),
      ),
    );
  }

  GeoPoint get _center {
    if (widget.initialCenter != null) return widget.initialCenter!;
    final points = widget.areas.expand((a) => a.ring).toList();
    if (points.isEmpty) return const GeoPoint(-15.78, -47.93);
    return Geodesy.center(points);
  }

  /// Descobre qual área foi tocada. Percorre da menor para a maior, senão um
  /// piquete dentro do perímetro da propriedade nunca seria selecionável.
  MapArea? _areaAt(GeoPoint point) {
    final hits = widget.areas.where((a) => a.containsPoint(point)).toList()
      ..sort((a, b) => a.areaHectares.compareTo(b.areaHectares));
    return hits.isEmpty ? null : hits.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = MapTheme.of(context);

    return MapOptionsScope(
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: _center.toLatLng(),
          initialZoom: widget.initialZoom,
          minZoom: widget.tileSource.minZoom,
          maxZoom: widget.tileSource.maxZoom,
          backgroundColor: theme.pasture,
          interactionOptions: InteractionOptions(
            flags: widget.interactive
                ? InteractiveFlag.all & ~InteractiveFlag.rotate
                : InteractiveFlag.none,
          ),
          onTap: widget.onAreaSelected == null
              ? null
              : (_, point) {
                  final area = _areaAt(GeoPoint.fromLatLng(point));
                  if (area != null) widget.onAreaSelected!(area);
                },
          onLongPress: widget.onAreaLongPress == null
              ? null
              : (_, point) {
                  final area = _areaAt(GeoPoint.fromLatLng(point));
                  if (area != null) widget.onAreaLongPress!(area);
                },
        ),
        children: [
          widget.tileSource.buildLayer(),
          PolygonLayer(
            polygons: [
              for (final area in widget.areas)
                Polygon(
                  points: area.ring.map((p) => p.toLatLng()).toList(),
                  color: theme.fillFor(area.healthStatus),
                  borderColor: area.id == widget.selectedAreaId
                      ? theme.tagYellow
                      : theme.strokeFor(area.healthStatus),
                  borderStrokeWidth: area.id == widget.selectedAreaId ? 4 : 2,
                ),
            ],
          ),
          // Marcadores pontuais entram antes dos rótulos: quando os dois
          // caem no mesmo lugar, o nome da área é a informação que o operador
          // procura primeiro.
          if (widget.markers.isNotEmpty)
            MarkerLayer(
              markers: [
                for (final marker in widget.markers)
                  Marker(
                    point: marker.position.toLatLng(),
                    width: 26,
                    height: 26,
                    child: _PointMarker(marker: marker, theme: theme),
                  ),
              ],
            ),
          if (widget.showLabels)
            AreaLabelsLayer(
              areas: widget.areas,
              selectedAreaId: widget.selectedAreaId,
              obstacles: widget.markers,
            ),
        ],
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({required this.marker, required this.theme});

  final MapMarker marker;
  final MapTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.strokeFor(marker.status);
    return Tooltip(
      message: marker.label,
      child: Container(
        decoration: BoxDecoration(
          color: theme.tagYellow,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
        ),
        child: Icon(Icons.pets, size: 16, color: theme.stamp),
      ),
    );
  }
}

/// Garante um tamanho definido para o mapa mesmo dentro de listas — sem isso o
/// FlutterMap estoura por restrição infinita.
class MapOptionsScope extends StatelessWidget {
  const MapOptionsScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      );
}
