import 'package:traceagro_map/traceagro_map.dart';

/// Áreas de demonstração situadas em Jataí, Goiás — região de pecuária real,
/// para que as medidas exibidas na vitrine tenham ordem de grandeza plausível.
///
/// São dados de exemplo desta vitrine, não do aplicativo: o app nunca preenche
/// tela com dado inventado (AGENTS.md §2.5).
const propertyCenter = GeoPoint(-17.8750, -51.7150);

final List<MapArea> sampleAreas = [
  MapArea(
    id: 'paddock-recria-12',
    name: 'Recria 12',
    herdLotName: 'Recria 12',
    animalCount: 128,
    healthStatus: AreaHealthStatus.clear,
    ring: const [
      GeoPoint(-17.8700, -51.7250),
      GeoPoint(-17.8700, -51.7150),
      GeoPoint(-17.8790, -51.7150),
      GeoPoint(-17.8790, -51.7250),
    ],
  ),
  MapArea(
    id: 'paddock-engorda-03',
    name: 'Engorda 03',
    herdLotName: 'Engorda 03',
    animalCount: 64,
    // Um animal em carência já muda a cor da área inteira: a decisão sobre
    // embarque é tomada por piquete, não por cabeça.
    healthStatus: AreaHealthStatus.withdrawal,
    ring: const [
      GeoPoint(-17.8700, -51.7140),
      GeoPoint(-17.8700, -51.7040),
      GeoPoint(-17.8770, -51.7040),
      GeoPoint(-17.8770, -51.7140),
    ],
  ),
  MapArea(
    id: 'paddock-enfermaria',
    name: 'Enfermaria',
    animalCount: 3,
    healthStatus: AreaHealthStatus.blocked,
    ring: const [
      GeoPoint(-17.8800, -51.7140),
      GeoPoint(-17.8800, -51.7100),
      GeoPoint(-17.8840, -51.7100),
      GeoPoint(-17.8840, -51.7140),
    ],
  ),
  MapArea(
    id: 'paddock-descanso',
    name: 'Descanso 07',
    animalCount: 0,
    healthStatus: AreaHealthStatus.empty,
    ring: const [
      GeoPoint(-17.8800, -51.7250),
      GeoPoint(-17.8800, -51.7160),
      GeoPoint(-17.8870, -51.7160),
      GeoPoint(-17.8870, -51.7250),
    ],
  ),
  // Piquete em L: contorno côncavo, para conferir que o desenho e a medição
  // não assumem forma convexa.
  MapArea(
    id: 'paddock-baixada',
    name: 'Baixada',
    animalCount: 41,
    healthStatus: AreaHealthStatus.clear,
    ring: const [
      GeoPoint(-17.8650, -51.7250),
      GeoPoint(-17.8650, -51.7100),
      GeoPoint(-17.8685, -51.7100),
      GeoPoint(-17.8685, -51.7190),
      GeoPoint(-17.8690, -51.7190),
      GeoPoint(-17.8690, -51.7250),
    ],
  ),
  MapArea(
    id: 'corral-sede',
    name: 'Curral da sede',
    kind: AreaKind.corral,
    animalCount: 0,
    healthStatus: AreaHealthStatus.empty,
    ring: const [
      GeoPoint(-17.8745, -51.7205),
      GeoPoint(-17.8745, -51.7190),
      GeoPoint(-17.8757, -51.7190),
      GeoPoint(-17.8757, -51.7205),
    ],
  ),
];

/// Animais localizados individualmente — por exemplo, o que foi lido no último
/// manejo com posição registrada.
const List<MapMarker> sampleMarkers = [
  MapMarker(
    id: 'animal-3950',
    position: GeoPoint(-17.8820, -51.7120),
    label: 'Brinco 3950 · carência ativa',
    status: AreaHealthStatus.blocked,
  ),
  MapMarker(
    id: 'animal-4127',
    position: GeoPoint(-17.8740, -51.7200),
    label: 'Brinco 4127',
    status: AreaHealthStatus.clear,
  ),
];
