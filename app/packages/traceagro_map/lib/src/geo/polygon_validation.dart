import '../models/geo_point.dart';
import 'geodesy.dart';

/// Por que um desenho de piquete foi recusado.
enum PolygonIssue {
  tooFewVertices('Um piquete precisa de pelo menos três pontos.'),
  selfIntersecting('As linhas se cruzam. Refaça o contorno sem cruzar.'),
  duplicatePoint('Dois pontos caíram no mesmo lugar.'),
  degenerateArea('A área ficou pequena demais para ser um piquete.');

  const PolygonIssue(this.message);

  /// Texto exibido ao operador — direto, sem jargão de geometria.
  final String message;
}

class PolygonValidation {
  const PolygonValidation._(this.issues);

  const PolygonValidation.valid() : issues = const [];

  final List<PolygonIssue> issues;

  bool get isValid => issues.isEmpty;
  PolygonIssue? get firstIssue => issues.isEmpty ? null : issues.first;

  /// Verifica se o anel pode virar um piquete.
  ///
  /// Roda a cada vértice enquanto o operador desenha, então precisa ser barata:
  /// piquetes têm dezenas de vértices, não milhares, e a checagem de cruzamento
  /// em O(n²) é confortável nessa escala.
  factory PolygonValidation.check(
    List<GeoPoint> ring, {
    double minimumAreaSquareMeters = 100,
    double minimumVertexDistanceMeters = 1,
  }) {
    final issues = <PolygonIssue>[];

    if (ring.length < 3) {
      return PolygonValidation._([PolygonIssue.tooFewVertices]);
    }

    if (_hasDuplicatePoints(ring, minimumVertexDistanceMeters)) {
      issues.add(PolygonIssue.duplicatePoint);
    }

    if (hasSelfIntersection(ring)) {
      issues.add(PolygonIssue.selfIntersecting);
    }

    if (Geodesy.polygonAreaSquareMeters(ring) < minimumAreaSquareMeters) {
      issues.add(PolygonIssue.degenerateArea);
    }

    return PolygonValidation._(issues);
  }

  static bool _hasDuplicatePoints(List<GeoPoint> ring, double minDistance) {
    for (var i = 0; i < ring.length; i++) {
      for (var j = i + 1; j < ring.length; j++) {
        if (Geodesy.distanceMeters(ring[i], ring[j]) < minDistance) {
          return true;
        }
      }
    }
    return false;
  }

  /// Alguma aresta cruza outra que não seja sua vizinha?
  ///
  /// Um polígono que se cruza não tem área definida: o Postgres recusa com
  /// `ST_IsValid` e o operador ficaria sem entender o motivo. Detectar aqui
  /// permite avisar durante o desenho, antes de tentar salvar.
  static bool hasSelfIntersection(List<GeoPoint> ring) {
    final n = ring.length;
    if (n < 4) return false;

    for (var i = 0; i < n; i++) {
      final a1 = ring[i];
      final a2 = ring[(i + 1) % n];

      for (var j = i + 1; j < n; j++) {
        // Arestas vizinhas compartilham vértice: tocar não é cruzar.
        final adjacent = (j == i + 1) || (i == 0 && j == n - 1);
        if (adjacent) continue;

        final b1 = ring[j];
        final b2 = ring[(j + 1) % n];

        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  /// Interseção de segmentos por orientação. Trabalha em graus (plano local) —
  /// nas dimensões de uma propriedade a distorção não muda o resultado.
  static bool _segmentsIntersect(
    GeoPoint p1,
    GeoPoint p2,
    GeoPoint p3,
    GeoPoint p4,
  ) {
    final d1 = _orientation(p3, p4, p1);
    final d2 = _orientation(p3, p4, p2);
    final d3 = _orientation(p1, p2, p3);
    final d4 = _orientation(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    // Casos colineares: só conta como cruzamento se houver sobreposição real.
    if (d1 == 0 && _onSegment(p3, p4, p1)) return true;
    if (d2 == 0 && _onSegment(p3, p4, p2)) return true;
    if (d3 == 0 && _onSegment(p1, p2, p3)) return true;
    if (d4 == 0 && _onSegment(p1, p2, p4)) return true;

    return false;
  }

  static double _orientation(GeoPoint a, GeoPoint b, GeoPoint c) {
    final value = (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
    if (value.abs() < 1e-12) return 0;
    return value;
  }

  static bool _onSegment(GeoPoint a, GeoPoint b, GeoPoint point) {
    return point.longitude >= (a.longitude < b.longitude ? a.longitude : b.longitude) &&
        point.longitude <= (a.longitude > b.longitude ? a.longitude : b.longitude) &&
        point.latitude >= (a.latitude < b.latitude ? a.latitude : b.latitude) &&
        point.latitude <= (a.latitude > b.latitude ? a.latitude : b.latitude);
  }
}
