import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:traceagro_map/traceagro_map.dart';

/// Cada motivo de falha pede uma frase diferente — "ligue o GPS" e "autorize
/// o app" mandam o operador mexer em coisas diferentes do aparelho. Estes
/// testes trocam a implementação de plataforma do geolocator por um dublê
/// controlado, então cobrem a tradução de cada cenário sem depender de GPS
/// real nem de canal de plataforma.
class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestResult,
    this.position,
    this.positionError,
  });

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission? requestResult;
  Position? position;
  Object? positionError;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestResult ?? permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionError != null) throw positionError!;
    return position!;
  }
}

Position _positionAt(double lat, double lon, {double accuracy = 8}) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('resolveUserLocation', () {
    test('serviço de localização desligado pede para ligar o GPS', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);

      final result = await resolveUserLocation();

      expect(result, isA<LocateFailure>());
      final failure = result as LocateFailure;
      expect(failure.kind, LocateFailureKind.serviceDisabled);
      expect(failure.message, contains('GPS'));
    });

    test('permissão negada pede para autorizar, sem insistir sozinho',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
        requestResult: LocationPermission.denied,
      );

      final result = await resolveUserLocation();

      expect(result, isA<LocateFailure>());
      expect((result as LocateFailure).kind, LocateFailureKind.permissionDenied);
    });

    test('permissão negada para sempre orienta ir nas configurações',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.deniedForever,
      );

      final result = await resolveUserLocation();

      expect(result, isA<LocateFailure>());
      final failure = result as LocateFailure;
      expect(failure.kind, LocateFailureKind.permissionDeniedForever);
      expect(failure.message, contains('configurações'));
    });

    test('permissão concedida na hora (estava negada) segue e localiza',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.denied,
        requestResult: LocationPermission.whileInUse,
        position: _positionAt(-17.88, -51.72),
      );

      final result = await resolveUserLocation();

      expect(result, isA<LocateSuccess>());
      final success = result as LocateSuccess;
      expect(success.point.latitude, -17.88);
      expect(success.point.longitude, -51.72);
    });

    test('sucesso devolve ponto e precisão informados pelo GPS', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        position: _positionAt(-17.875, -51.715, accuracy: 12),
      );

      final result = await resolveUserLocation();

      expect(result, isA<LocateSuccess>());
      final success = result as LocateSuccess;
      expect(success.point, const GeoPoint(-17.875, -51.715));
      expect(success.accuracyMeters, 12);
    });

    test('precisão zero ou não finita não é repassada como número real',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        position: _positionAt(-17.875, -51.715, accuracy: 0),
      );

      final result = await resolveUserLocation();

      expect((result as LocateSuccess).accuracyMeters, isNull);
    });

    test('serviço desligado detectado durante a leitura também é traduzido',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        positionError: const LocationServiceDisabledException(),
      );

      final result = await resolveUserLocation();

      expect((result as LocateFailure).kind, LocateFailureKind.serviceDisabled);
    });

    test('permissão negada detectada durante a leitura também é traduzida',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        positionError: const PermissionDeniedException('nope'),
      );

      final result = await resolveUserLocation();

      expect((result as LocateFailure).kind, LocateFailureKind.permissionDenied);
    });

    test('erro desconhecido do plugin vira mensagem genérica, não trava',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        positionError: StateError('algo inesperado'),
      );

      final result = await resolveUserLocation();

      expect(result, isA<LocateFailure>());
      expect((result as LocateFailure).kind, LocateFailureKind.unknown);
    });

    test('recusa do navegador por falta de HTTPS vira mensagem específica',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        positionError: Exception('Position update is unavailable: '
            'permissions policy exposes location only on secure origins'),
      );

      final result = await resolveUserLocation();

      expect((result as LocateFailure).kind, LocateFailureKind.unsupported);
    });
  });
}
