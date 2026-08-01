/// Componentes de mapa do TraceAgro.
///
/// Pacote autocontido: não conhece os modelos, o tema nem a camada de dados do
/// aplicativo. Quem consome converte os próprios tipos para [GeoPoint] e
/// [MapArea] e recebe de volta contornos prontos para persistir.
///
/// Uso típico:
///
/// ```dart
/// // Visualizar a propriedade com a situação sanitária por área
/// AreaMapView(
///   areas: paddocks.map(toMapArea).toList(),
///   selectedAreaId: selected?.id,
///   onAreaSelected: (area) => setState(() => selected = area),
/// )
///
/// // Desenhar um piquete novo
/// AreaDrawMap(
///   controller: controller,
///   onSave: (ring) => salvarPiquete(ring),
/// )
/// ```
library;

export 'src/drawing/area_draw_controller.dart';
export 'src/geo/geodesy.dart';
export 'src/geo/polygon_validation.dart';
export 'src/location/user_location.dart';
export 'src/models/geo_point.dart';
export 'src/models/map_area.dart';
export 'src/theme/map_theme.dart';
export 'src/tiles/tile_source.dart';
export 'src/widgets/area_draw_map.dart' show AreaDrawMap, edgeMidpoints;
export 'src/widgets/area_labels_layer.dart' show AreaLabelsLayer;
export 'src/widgets/area_legend.dart';
export 'src/widgets/area_map_view.dart' show AreaMapView, AreaMapViewState;
export 'src/widgets/area_summary_sheet.dart';
export 'src/widgets/user_location_layer.dart';
