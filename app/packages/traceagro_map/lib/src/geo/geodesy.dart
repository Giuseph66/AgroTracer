import 'dart:math' as math;

import '../models/geo_point.dart';

/// Raio médio da Terra (IUGG), em metros.
const double earthRadiusMeters = 6371008.8;

const double _degToRad = math.pi / 180.0;

/// Cálculos geodésicos para medição de áreas rurais.
///
/// A medição é feita sobre a esfera, não sobre o plano: um piquete de 200 ha
/// medido com fórmula planar erra o suficiente para brigar com a matrícula do
/// imóvel. O erro do modelo esférico contra o elipsoidal fica abaixo de 0,5%
/// nas dimensões de uma propriedade, o que é adequado para manejo — medição com
/// valor legal continua sendo trabalho de georreferenciamento credenciado.
abstract final class Geodesy {
  /// Área do polígono em metros quadrados, pela fórmula do excesso esférico.
  ///
  /// O anel é fechado implicitamente (o último ponto liga no primeiro). A ordem
  /// dos vértices não importa: o valor absoluto é usado, então horário e
  /// anti-horário dão o mesmo resultado.
  static double polygonAreaSquareMeters(List<GeoPoint> ring) {
    if (ring.length < 3) return 0;

    double total = 0;
    for (var i = 0; i < ring.length; i++) {
      final current = ring[i];
      final next = ring[(i + 1) % ring.length];

      final deltaLon = (next.longitude - current.longitude) * _degToRad;
      final sinLatCurrent = math.sin(current.latitude * _degToRad);
      final sinLatNext = math.sin(next.latitude * _degToRad);

      total += deltaLon * (2 + sinLatCurrent + sinLatNext);
    }

    return (total * earthRadiusMeters * earthRadiusMeters / 2).abs();
  }

  /// Área em hectares — a unidade em que o produtor pensa.
  static double polygonAreaHectares(List<GeoPoint> ring) =>
      polygonAreaSquareMeters(ring) / 10000.0;

  /// Distância entre dois pontos pela fórmula de haversine, em metros.
  static double distanceMeters(GeoPoint a, GeoPoint b) {
    final lat1 = a.latitude * _degToRad;
    final lat2 = b.latitude * _degToRad;
    final deltaLat = (b.latitude - a.latitude) * _degToRad;
    final deltaLon = (b.longitude - a.longitude) * _degToRad;

    final h = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Perímetro do anel fechado, em metros.
  static double perimeterMeters(List<GeoPoint> ring) {
    if (ring.length < 2) return 0;
    double total = 0;
    for (var i = 0; i < ring.length; i++) {
      total += distanceMeters(ring[i], ring[(i + 1) % ring.length]);
    }
    return total;
  }

  /// Comprimento da linha aberta (usado enquanto o operador ainda desenha).
  static double pathLengthMeters(List<GeoPoint> path) {
    if (path.length < 2) return 0;
    double total = 0;
    for (var i = 0; i < path.length - 1; i++) {
      total += distanceMeters(path[i], path[i + 1]);
    }
    return total;
  }

  /// Centro geométrico simples dos vértices. Serve para posicionar rótulo e
  /// centralizar a câmera; não é o centroide de massa do polígono.
  static GeoPoint center(List<GeoPoint> points) {
    if (points.isEmpty) {
      throw ArgumentError('lista de pontos vazia não tem centro');
    }
    var lat = 0.0;
    var lon = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return GeoPoint(lat / points.length, lon / points.length);
  }

  /// Ponto médio entre dois pontos — usado para oferecer "inserir vértice
  /// aqui" no meio de uma aresta durante o desenho.
  ///
  /// Média aritmética de lat/lon, não grande círculo: na escala de um
  /// piquete (metros a poucos quilômetros) a diferença é submilimétrica, e a
  /// aproximação simples é o que se espera de um ponto de referência visual
  /// que o operador ainda vai arrastar para ajustar.
  static GeoPoint midpoint(GeoPoint a, GeoPoint b) => GeoPoint(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );

  /// Retângulo envolvente: sudoeste e nordeste.
  static (GeoPoint southWest, GeoPoint northEast) bounds(
    List<GeoPoint> points,
  ) {
    if (points.isEmpty) {
      throw ArgumentError('lista de pontos vazia não tem envolvente');
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    return (GeoPoint(minLat, minLon), GeoPoint(maxLat, maxLon));
  }

  /// O ponto está dentro do polígono? Ray casting no plano — suficiente nas
  /// dimensões de uma propriedade, onde a distorção é irrelevante para decidir
  /// se um animal está num piquete ou no vizinho.
  static bool containsPoint(List<GeoPoint> ring, GeoPoint point) {
    if (ring.length < 3) return false;

    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;

      final intersects = (yi > point.latitude) != (yj > point.latitude) &&
          point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi;

      if (intersects) inside = !inside;
    }
    return inside;
  }

  /// Formata área para leitura em campo: hectares com uma casa, ou metros
  /// quadrados quando a área é pequena demais para hectare fazer sentido.
  static String formatArea(double hectares) {
    if (hectares < 1) {
      final squareMeters = hectares * 10000;
      return '${squareMeters.toStringAsFixed(0).replaceAll('.', ',')} m²';
    }
    if (hectares < 100) {
      return '${hectares.toStringAsFixed(1).replaceAll('.', ',')} ha';
    }
    return '${hectares.toStringAsFixed(0)} ha';
  }

  /// Formata distância: metros até 1 km, depois quilômetros.
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';
  }
}
