import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_map/traceagro_map.dart';

void main() {
  group('PolygonValidation', () {
    test('quadrado simples é válido', () {
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.87, -51.72),
      ];

      expect(PolygonValidation.check(ring).isValid, isTrue);
    });

    test('dois pontos não fazem um piquete', () {
      const ring = [GeoPoint(-17.88, -51.72), GeoPoint(-17.88, -51.71)];
      final result = PolygonValidation.check(ring);

      expect(result.isValid, isFalse);
      expect(result.firstIssue, PolygonIssue.tooFewVertices);
    });

    test('gravata-borboleta é recusada por cruzar as próprias linhas', () {
      // Trocar dois vértices do quadrado produz o cruzamento clássico — é o
      // erro que o operador comete ao marcar os cantos fora de ordem.
      const bowtie = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.72),
      ];

      final result = PolygonValidation.check(bowtie);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(PolygonIssue.selfIntersecting));
    });

    test('ponto repetido é apontado', () {
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.72),
      ];

      final result = PolygonValidation.check(ring);
      expect(result.issues, contains(PolygonIssue.duplicatePoint));
    });

    test('área minúscula é recusada como degenerada', () {
      const ring = [
        GeoPoint(-17.880000, -51.720000),
        GeoPoint(-17.880000, -51.720030),
        GeoPoint(-17.880030, -51.720030),
      ];

      final result = PolygonValidation.check(ring);
      expect(result.issues, contains(PolygonIssue.degenerateArea));
    });

    test('polígono côncavo em L é válido — piquete não precisa ser convexo', () {
      const lShape = [
        GeoPoint(-17.880, -51.720),
        GeoPoint(-17.880, -51.710),
        GeoPoint(-17.875, -51.710),
        GeoPoint(-17.875, -51.715),
        GeoPoint(-17.870, -51.715),
        GeoPoint(-17.870, -51.720),
      ];

      expect(PolygonValidation.check(lShape).isValid, isTrue);
    });

    test('cada problema traz um texto que o operador entende', () {
      for (final issue in PolygonIssue.values) {
        expect(issue.message, isNotEmpty);
        expect(issue.message.endsWith('.'), isTrue);
      }
    });
  });

  group('PolygonValidation.hasSelfIntersection', () {
    test('triângulo não cruza', () {
      const triangle = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.715),
      ];
      expect(PolygonValidation.hasSelfIntersection(triangle), isFalse);
    });

    test('arestas vizinhas se tocam no vértice e isso não é cruzamento', () {
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.87, -51.72),
      ];
      expect(PolygonValidation.hasSelfIntersection(ring), isFalse);
    });
  });
}
