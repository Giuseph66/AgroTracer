import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_app/domain/models.dart';
import 'package:traceagro_app/features/areas/area_mapping.dart';
import 'package:traceagro_app/data/api_client.dart';
import 'package:traceagro_map/traceagro_map.dart';

Paddock paddock({
  int animalCount = 0,
  int alertCount = 0,
  List<List<double>>? boundary,
}) =>
    Paddock(
      id: 'p1',
      name: 'Recria 12',
      areaHa: 100,
      animalCount: animalCount,
      alertCount: alertCount,
      boundary: boundary ??
          const [
            [-51.72, -17.88],
            [-51.71, -17.88],
            [-51.71, -17.87],
            [-51.72, -17.87],
          ],
    );

void main() {
  group('Paddock → MapArea', () {
    test('converte contorno de [lon, lat] para GeoPoint(lat, lon)', () {
      final area = paddock().toMapArea()!;

      // Trocar a ordem colocaria a fazenda no oceano Índico; o teste existe
      // justamente porque GeoJSON e o mapa usam ordens opostas.
      expect(area.ring.first.latitude, -17.88);
      expect(area.ring.first.longitude, -51.72);
    });

    test('piquete sem contorno não vira área no mapa', () {
      expect(paddock(boundary: const []).toMapArea(), isNull);
      expect(
        paddock(boundary: const [
          [-51.72, -17.88],
          [-51.71, -17.88],
        ]).toMapArea(),
        isNull,
      );
    });

    test('área vazia aparece como sem animais', () {
      final area = paddock(animalCount: 0).toMapArea()!;
      expect(area.healthStatus, AreaHealthStatus.empty);
    });

    test('área sem alerta fica liberada', () {
      final area = paddock(animalCount: 40).toMapArea()!;
      expect(area.healthStatus, AreaHealthStatus.clear);
    });

    test('um único animal com restrição muda a cor da área toda', () {
      final area = paddock(animalCount: 40, alertCount: 1).toMapArea()!;
      expect(area.healthStatus, AreaHealthStatus.withdrawal);
    });

    test('a medida do mapa confere com a área calculada pelo servidor', () {
      final area = paddock().toMapArea()!;
      // O piquete do fixture é 0,01° × 0,01° em Jataí ≈ 117,7 ha; o servidor
      // usa PostGIS e o app usa a esfera, então basta convergirem.
      expect(area.areaHectares, closeTo(117.7, 0.5));
    });

    test('lista descarta os piquetes sem contorno e mantém os demais', () {
      final areas = toMapAreas([
        paddock(),
        paddock(boundary: const []),
      ]);
      expect(areas, hasLength(1));
    });
  });

  group('anel de volta para a API', () {
    test('inverte para [longitude, latitude] do GeoJSON', () {
      final api = ringToApi(const [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
      ]);

      expect(api.first, [-51.72, -17.88]);
    });

    test('ida e volta preserva as coordenadas', () {
      final original = paddock();
      final ring = original.toMapArea()!.ring;
      expect(ringToApi(ring), original.boundary);
    });
  });

  group('parseGeoJsonRing', () {
    test('descarta o ponto de fechamento repetido', () {
      final ring = parseGeoJsonRing({
        'type': 'Polygon',
        'coordinates': [
          [
            [-51.72, -17.88],
            [-51.71, -17.88],
            [-51.71, -17.87],
            [-51.72, -17.88],
          ]
        ],
      });

      // Quatro pares no GeoJSON, três vértices reais: manter a repetição
      // desenharia um vértice fantasma em cima do primeiro.
      expect(ring, hasLength(3));
    });

    test('geometria ausente ou malformada vira contorno vazio', () {
      expect(parseGeoJsonRing(null), isEmpty);
      expect(parseGeoJsonRing('Polygon'), isEmpty);
      expect(parseGeoJsonRing({'type': 'Polygon'}), isEmpty);
      expect(parseGeoJsonRing({'coordinates': []}), isEmpty);
    });
  });

  group('PaddockAnimal → estado no mapa', () {
    PaddockAnimal animal({String status = 'ACTIVE', DateTime? withdrawal}) =>
        PaddockAnimal(
          animalId: 'a1',
          sex: 'F',
          breed: 'Nelore',
          visualTagNumber: '4127',
          lifecycleStatus: status,
          withdrawalUntil: withdrawal,
          lastWeightKg: 300,
        );

    test('quarentena é a restrição mais severa', () {
      expect(animal(status: 'QUARANTINED').mapStatus, AreaHealthStatus.blocked);
    });

    test('carência vigente marca restrição', () {
      final future = DateTime.now().add(const Duration(days: 5));
      expect(animal(withdrawal: future).mapStatus, AreaHealthStatus.withdrawal);
    });

    test('carência vencida não restringe mais', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(animal(withdrawal: past).mapStatus, AreaHealthStatus.clear);
    });
  });
}
