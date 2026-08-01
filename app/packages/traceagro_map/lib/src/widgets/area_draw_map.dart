import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../drawing/area_draw_controller.dart';
import '../geo/geodesy.dart';
import '../location/user_location.dart';
import '../models/geo_point.dart';
import '../models/map_area.dart';
import '../theme/map_theme.dart';
import '../tiles/tile_source.dart';
import 'user_location_layer.dart';

/// Zoom usado ao centralizar na localização do operador durante o desenho —
/// igual ao de [AreaMapView], para o comportamento ser previsível nas duas
/// telas.
const double _locateZoom = 17;

/// Ponto médio de cada aresta do contorno em desenho, com o índice depois do
/// qual o novo vértice entra.
///
/// Função pura, sem widget: testável isoladamente. Cobre dois casos —
/// contorno fechado (3+ pontos, inclui a aresta de fechamento entre o
/// último e o primeiro) e linha aberta (2 pontos, uma aresta só, sem
/// fechamento porque ainda não há área).
List<({int afterIndex, GeoPoint point})> edgeMidpoints(
  List<GeoPoint> vertices,
) {
  if (vertices.length < 2) return const [];

  final closed = vertices.length >= 3;
  final edgeCount = closed ? vertices.length : vertices.length - 1;

  return [
    for (var i = 0; i < edgeCount; i++)
      (
        afterIndex: i,
        point: Geodesy.midpoint(vertices[i], vertices[(i + 1) % vertices.length]),
      ),
  ];
}

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

  GeoPoint? _userLocation;
  double? _userAccuracyMeters;
  bool _locating = false;

  AreaDrawController get controller => widget.controller;

  /// Centraliza o mapa na posição do operador — o mesmo comportamento de
  /// [AreaMapView.locateUser], usado aqui para achar o próprio piquete no
  /// meio do desenho sem sair da tela.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await resolveUserLocation();
    if (!mounted) return;
    setState(() => _locating = false);

    if (result is LocateSuccess) {
      setState(() {
        _userLocation = result.point;
        _userAccuracyMeters = result.accuracyMeters;
      });
      _map.move(result.point.toLatLng(), _locateZoom);
    } else if (result is LocateFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  /// Remove o vértice selecionado. Vibra ao remover — a mesma confirmação
  /// tátil de qualquer ação destrutiva rápida no app.
  ///
  /// Desmarca a seleção em seguida: o controller mantém o índice apontando
  /// para quem quer que tenha ocupado aquela posição depois da remoção (para
  /// nunca ficar com um índice fora da lista), mas aqui isso faria a barra
  /// de contexto continuar mostrando "selecionado" sobre um vértice
  /// diferente do que o operador escolheu — e um segundo toque em "Remover"
  /// apagaria esse vizinho sem querer.
  void _removeSelected() {
    final index = controller.selectedIndex;
    if (index == null) return;
    HapticFeedback.mediumImpact();
    controller.removeVertex(index);
    controller.select(null);
  }

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

                  // Pontos médios de cada aresta: alvo menor e translúcido —
                  // toque insere um vértice novo ali, para refinar um trecho
                  // do contorno sem precisar apagar e redesenhar tudo.
                  if (vertices.length >= 2)
                    MidpointMarkers(
                      midpoints: edgeMidpoints(vertices),
                      theme: theme,
                      onTap: (afterIndex, point) =>
                          controller.insertVertexAfter(afterIndex, point),
                    ),

                  // Vértices: alvos grandes, arrastáveis para ajustar o canto.
                  // Segurar remove — a mesma ação rápida usada em qualquer
                  // lista do app para descartar um item.
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
                          onLongPress: () {
                            controller.select(i);
                            _removeSelected();
                          },
                        ),
                    ],
                  ),

                  if (_userLocation != null)
                    UserLocationLayer(
                      position: _userLocation!,
                      accuracyMeters: _userAccuracyMeters,
                      theme: theme,
                    ),
                ],
              ),
            ),

            _TopBar(
              title: widget.title,
              theme: theme,
              onCancel: widget.onCancel,
              onLocate: _locating ? null : _locateMe,
              locating: _locating,
            ),

            _MeasurementPanel(
              controller: controller,
              theme: theme,
              onSave: widget.onSave,
              saveLabel: widget.saveLabel,
              onRemoveSelected: _removeSelected,
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.theme,
    this.onCancel,
    this.onLocate,
    this.locating = false,
  });

  final String title;
  final MapTheme theme;
  final VoidCallback? onCancel;
  final VoidCallback? onLocate;
  final bool locating;

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
            if (onLocate != null || locating)
              IconButton(
                onPressed: onLocate,
                tooltip: 'Ir para minha localização',
                icon: locating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.tagYellow,
                        ),
                      )
                    : Icon(Icons.my_location, color: theme.paperInk),
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
    this.onRemoveSelected,
  });

  final AreaDrawController controller;
  final MapTheme theme;
  final String saveLabel;
  final ValueChanged<List<GeoPoint>>? onSave;
  final VoidCallback? onRemoveSelected;

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

            if (controller.selectedIndex != null) ...[
              const SizedBox(height: 12),
              _SelectedPointBar(
                index: controller.selectedIndex!,
                theme: theme,
                onRemove: onRemoveSelected,
                onDeselect: () => controller.select(null),
              ),
            ],

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
    // Botão desativado precisa continuar legível: sumir com o rótulo faz o
    // operador achar que a ação não existe, em vez de estar indisponível agora.
    final color = enabled
        ? theme.paperInk
        : theme.paperInk.withValues(alpha: 0.55);

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

/// Barra de contexto do vértice selecionado.
///
/// Toque no vértice já seleciona (o círculo cresce e mostra o número); esta
/// barra é a segunda confirmação — vértice pequeno com luva é fácil de
/// tocar sem querer, então excluir exige o passo extra do botão, além do
/// atalho de segurar o vértice.
class _SelectedPointBar extends StatelessWidget {
  const _SelectedPointBar({
    required this.index,
    required this.theme,
    this.onRemove,
    this.onDeselect,
  });

  final int index;
  final MapTheme theme;
  final VoidCallback? onRemove;
  final VoidCallback? onDeselect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.tagYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.tagYellow.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: theme.tagYellow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: theme.stamp,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ponto ${index + 1} selecionado. Arraste para mover.',
              style: TextStyle(color: theme.paperInk, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              foregroundColor: theme.clay,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Remover'),
          ),
          IconButton(
            onPressed: onDeselect,
            tooltip: 'Cancelar seleção',
            icon: Icon(Icons.close,
                size: 18, color: theme.paperInk.withValues(alpha: 0.6)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// Pontos médios de cada aresta: alvo discreto que insere um vértice novo
/// exatamente ali quando tocado — refina um trecho do contorno sem apagar
/// tudo e recomeçar.
class MidpointMarkers extends StatelessWidget {
  const MidpointMarkers({
    super.key,
    required this.midpoints,
    required this.theme,
    required this.onTap,
  });

  final List<({int afterIndex, GeoPoint point})> midpoints;
  final MapTheme theme;
  final void Function(int afterIndex, GeoPoint point) onTap;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final m in midpoints)
          Marker(
            key: ValueKey('midpoint-${m.afterIndex}-${m.point}'),
            point: m.point.toLatLng(),
            width: 28,
            height: 28,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(m.afterIndex, m.point),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.paper.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.tagYellow.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.add, size: 9, color: theme.tagYellowDeep),
                ),
              ),
            ),
          ),
      ],
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
    this.onLongPress,
  });

  final Key key;
  final LatLng point;
  final Size size;
  final int index;
  final bool selected;
  final MapTheme theme;
  final ValueChanged<LatLng> onDragEnd;
  final VoidCallback onTap;

  /// Remove o vértice diretamente — atalho rápido, sem passar pela barra de
  /// contexto do painel.
  final VoidCallback? onLongPress;
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
      onLongPress: marker.onLongPress,
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
