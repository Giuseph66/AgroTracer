import '../geo/geodesy.dart';
import 'geo_point.dart';

/// Situação sanitária agregada de uma área.
///
/// Deriva dos animais que estão nela: um único animal em quarentena muda a cor
/// do piquete inteiro, porque a decisão do operador ("posso mandar esse lote
/// para o embarque?") é sobre a área, não sobre o animal isolado.
enum AreaHealthStatus {
  /// Nenhuma restrição entre os animais presentes.
  clear('Sem restrição'),

  /// Há carência ativa: o animal pode ser manejado, mas não abatido.
  withdrawal('Carência ativa'),

  /// Há quarentena ou suspeita: movimentação restrita.
  blocked('Movimentação restrita'),

  /// Área sem animais no momento.
  empty('Sem animais'),

  /// Ainda não se sabe (sem dados baixados para esta área).
  unknown('Sem informação');

  const AreaHealthStatus(this.label);
  final String label;

  /// Ordem de severidade: o pior estado presente define a cor da área.
  int get severity => switch (this) {
        AreaHealthStatus.blocked => 3,
        AreaHealthStatus.withdrawal => 2,
        AreaHealthStatus.clear => 1,
        AreaHealthStatus.empty => 0,
        AreaHealthStatus.unknown => -1,
      };

  static AreaHealthStatus worst(Iterable<AreaHealthStatus> values) {
    if (values.isEmpty) return AreaHealthStatus.unknown;
    return values.reduce((a, b) => a.severity >= b.severity ? a : b);
  }
}

/// Tipo de área desenhada.
enum AreaKind {
  paddock('Piquete'),
  corral('Curral'),
  propertyBoundary('Perímetro da propriedade'),
  restricted('Área restrita');

  const AreaKind(this.label);
  final String label;
}

/// Uma área desenhada no mapa: piquete, curral ou perímetro.
///
/// É um objeto de valor puro — sem dependência de widget, de banco ou dos
/// modelos do app. Quem consome converte dos próprios tipos para este.
class MapArea {
  MapArea({
    required this.id,
    required this.name,
    required this.ring,
    this.kind = AreaKind.paddock,
    this.healthStatus = AreaHealthStatus.unknown,
    this.animalCount = 0,
    this.herdLotName,
  }) : assert(ring.length >= 3, 'uma área precisa de ao menos três vértices');

  final String id;
  final String name;

  /// Vértices do contorno, fechado implicitamente.
  final List<GeoPoint> ring;

  final AreaKind kind;
  final AreaHealthStatus healthStatus;
  final int animalCount;
  final String? herdLotName;

  /// Área medida sobre a esfera, em hectares.
  late final double areaHectares = Geodesy.polygonAreaHectares(ring);

  /// Perímetro em metros.
  late final double perimeterMeters = Geodesy.perimeterMeters(ring);

  /// Centro para posicionar rótulo e centralizar câmera.
  late final GeoPoint center = Geodesy.center(ring);

  /// Lotação em cabeças por hectare — número que o produtor usa para decidir
  /// se o piquete aguenta o lote. Nulo quando não há área ou animais.
  double? get stockingRate {
    if (areaHectares <= 0 || animalCount == 0) return null;
    return animalCount / areaHectares;
  }

  bool containsPoint(GeoPoint point) => Geodesy.containsPoint(ring, point);

  String get formattedArea => Geodesy.formatArea(areaHectares);
  String get formattedPerimeter => Geodesy.formatDistance(perimeterMeters);

  MapArea copyWith({
    String? id,
    String? name,
    List<GeoPoint>? ring,
    AreaKind? kind,
    AreaHealthStatus? healthStatus,
    int? animalCount,
    String? herdLotName,
  }) =>
      MapArea(
        id: id ?? this.id,
        name: name ?? this.name,
        ring: ring ?? this.ring,
        kind: kind ?? this.kind,
        healthStatus: healthStatus ?? this.healthStatus,
        animalCount: animalCount ?? this.animalCount,
        herdLotName: herdLotName ?? this.herdLotName,
      );

  @override
  String toString() => 'MapArea($id, $name, $formattedArea)';
}

/// Marcador pontual sobre o mapa: um animal localizado, um curral, um bebedouro.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.label,
    this.status = AreaHealthStatus.unknown,
  });

  final String id;
  final GeoPoint position;
  final String label;
  final AreaHealthStatus status;
}
