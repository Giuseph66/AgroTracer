import 'package:latlong2/latlong.dart' as ll;

/// Ponto geográfico em WGS84 / SIRGAS 2000 (equivalentes na prática para uso
/// cartográfico rural; o banco guarda SRID 4674).
///
/// O pacote define o próprio tipo em vez de expor `LatLng` do flutter_map para
/// que quem consome os componentes não fique preso à biblioteca de mapa
/// escolhida — trocar de biblioteca não deve vazar para o app.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude)
      : assert(latitude >= -90 && latitude <= 90, 'latitude fora de faixa'),
        assert(longitude >= -180 && longitude <= 180, 'longitude fora de faixa');

  final double latitude;
  final double longitude;

  /// Conversão para o tipo interno do flutter_map. Uso restrito aos widgets
  /// deste pacote.
  ll.LatLng toLatLng() => ll.LatLng(latitude, longitude);

  static GeoPoint fromLatLng(ll.LatLng p) => GeoPoint(p.latitude, p.longitude);

  /// Formato usado pela API (GeoJSON: longitude primeiro).
  List<double> toGeoJsonCoordinate() => [longitude, latitude];

  static GeoPoint fromGeoJsonCoordinate(List<dynamic> pair) =>
      GeoPoint((pair[1] as num).toDouble(), (pair[0] as num).toDouble());

  GeoPoint copyWith({double? latitude, double? longitude}) =>
      GeoPoint(latitude ?? this.latitude, longitude ?? this.longitude);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';
}
