import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_map/traceagro_map.dart';

/// Um piquete medido errado vira briga sobre lotação e sobre matrícula do
/// imóvel. Os valores esperados abaixo vêm do cálculo analítico independente
/// (lado × lado sobre a esfera), não da própria implementação.
void main() {
  group('Geodesy.polygonArea', () {
    test('quadrado de 0,01° no equador confere com o cálculo analítico', () {
      const ring = [
        GeoPoint(0, 0),
        GeoPoint(0, 0.01),
        GeoPoint(0.01, 0.01),
        GeoPoint(0.01, 0),
      ];

      // lado norte-sul: 0,01° × raio; lado leste-oeste: mesmo, com o cosseno
      // da latitude média (0,005°).
      const degreeMeters = earthRadiusMeters * math.pi / 180.0;
      final expected =
          (0.01 * degreeMeters) * (0.01 * degreeMeters * math.cos(0.005 * math.pi / 180));

      expect(
        Geodesy.polygonAreaSquareMeters(ring),
        closeTo(expected, expected * 0.0001),
      );
      expect(Geodesy.polygonAreaHectares(ring), closeTo(123.64, 0.01));
    });

    test('mesmo quadrado em Jataí-GO encolhe pelo cosseno da latitude', () {
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.87, -51.72),
      ];

      expect(Geodesy.polygonAreaHectares(ring), closeTo(117.67, 0.01));
    });

    test('a ordem dos vértices não muda a medida', () {
      const clockwise = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.87, -51.72),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.88, -51.71),
      ];
      final counterClockwise = clockwise.reversed.toList();

      expect(
        Geodesy.polygonAreaSquareMeters(clockwise),
        closeTo(Geodesy.polygonAreaSquareMeters(counterClockwise), 0.001),
      );
    });

    test('menos de três pontos não tem área', () {
      expect(Geodesy.polygonAreaSquareMeters(const []), 0);
      expect(
        Geodesy.polygonAreaSquareMeters(const [GeoPoint(0, 0), GeoPoint(0, 1)]),
        0,
      );
    });
  });

  group('Geodesy.distance', () {
    test('um grau de latitude são cerca de 111,2 km', () {
      final d = Geodesy.distanceMeters(
        const GeoPoint(0, 0),
        const GeoPoint(1, 0),
      );
      expect(d, closeTo(111194.9, 1));
    });

    test('um grau de longitude encolhe com a latitude', () {
      final noEquador = Geodesy.distanceMeters(
        const GeoPoint(0, 0),
        const GeoPoint(0, 1),
      );
      final emJatai = Geodesy.distanceMeters(
        const GeoPoint(-17.88, -51.72),
        const GeoPoint(-17.88, -50.72),
      );

      expect(noEquador, closeTo(111194.9, 1));
      expect(emJatai, lessThan(noEquador));
      expect(emJatai, closeTo(noEquador * math.cos(17.88 * math.pi / 180), 50));
    });

    test('distância de um ponto para ele mesmo é zero', () {
      expect(
        Geodesy.distanceMeters(
          const GeoPoint(-17.88, -51.72),
          const GeoPoint(-17.88, -51.72),
        ),
        0,
      );
    });
  });

  group('Geodesy.perimeter', () {
    test('fecha o anel: o último ponto liga no primeiro', () {
      const ring = [
        GeoPoint(0, 0),
        GeoPoint(0, 0.01),
        GeoPoint(0.01, 0.01),
        GeoPoint(0.01, 0),
      ];

      final perimeter = Geodesy.perimeterMeters(ring);
      final openPath = Geodesy.pathLengthMeters(ring);

      // O perímetro tem o lado de fechamento a mais que a linha aberta.
      expect(perimeter, greaterThan(openPath));
      expect(perimeter, closeTo(4 * 1111.9, 5));
    });
  });

  group('Geodesy.containsPoint', () {
    const paddock = [
      GeoPoint(-17.88, -51.72),
      GeoPoint(-17.88, -51.71),
      GeoPoint(-17.87, -51.71),
      GeoPoint(-17.87, -51.72),
    ];

    test('ponto no meio está dentro', () {
      expect(Geodesy.containsPoint(paddock, const GeoPoint(-17.875, -51.715)),
          isTrue);
    });

    test('ponto fora fica fora', () {
      expect(Geodesy.containsPoint(paddock, const GeoPoint(-17.90, -51.715)),
          isFalse);
      expect(Geodesy.containsPoint(paddock, const GeoPoint(-17.875, -51.70)),
          isFalse);
    });
  });

  group('Geodesy.bounds e center', () {
    test('envolvente cobre todos os pontos', () {
      const points = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.86, -51.70),
        GeoPoint(-17.87, -51.75),
      ];

      final (sw, ne) = Geodesy.bounds(points);
      expect(sw.latitude, -17.88);
      expect(sw.longitude, -51.75);
      expect(ne.latitude, -17.86);
      expect(ne.longitude, -51.70);
    });

    test('lista vazia não tem centro nem envolvente', () {
      expect(() => Geodesy.center(const []), throwsArgumentError);
      expect(() => Geodesy.bounds(const []), throwsArgumentError);
    });
  });

  group('formatação para leitura em campo', () {
    test('área pequena sai em metros quadrados, não em fração de hectare', () {
      expect(Geodesy.formatArea(0.05), '500 m²');
      expect(Geodesy.formatArea(0.9), '9000 m²');
    });

    test('hectare com uma casa até 100, inteiro acima', () {
      expect(Geodesy.formatArea(12.34), '12,3 ha');
      expect(Geodesy.formatArea(117.67), '118 ha');
    });

    test('distância vira quilômetro a partir de 1000 m', () {
      expect(Geodesy.formatDistance(850), '850 m');
      expect(Geodesy.formatDistance(1500), '1,50 km');
    });
  });
}
