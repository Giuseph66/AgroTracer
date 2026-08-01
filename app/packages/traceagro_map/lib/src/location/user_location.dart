import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';

/// Por que não foi possível localizar o operador.
///
/// Cada motivo pede uma frase diferente: "ligue o GPS" e "autorize o app" são
/// ações distintas, e confundir as duas manda o operador mexer na coisa
/// errada no meio do curral.
enum LocateFailureKind {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unsupported,
  unknown,
}

sealed class LocateResult {
  const LocateResult();
}

class LocateSuccess extends LocateResult {
  const LocateSuccess(this.point, {this.accuracyMeters});
  final GeoPoint point;

  /// Raio de incerteza informado pelo GPS. `null` quando a plataforma não
  /// reporta — nesse caso o círculo de precisão não é desenhado, em vez de
  /// mostrar um número inventado.
  final double? accuracyMeters;
}

class LocateFailure extends LocateResult {
  const LocateFailure(this.kind, this.message);
  final LocateFailureKind kind;
  final String message;
}

/// Resolve a posição atual do dispositivo, traduzindo cada falha do
/// `geolocator` numa mensagem que o operador de campo entende.
///
/// Nunca lança: toda falha vira [LocateFailure] para a interface decidir o que
/// mostrar, sem try/catch espalhado pelas telas.
Future<LocateResult> resolveUserLocation({
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocateFailure(
        LocateFailureKind.serviceDisabled,
        'A localização do aparelho está desligada. Ative o GPS e tente de novo.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocateFailure(
        LocateFailureKind.permissionDenied,
        'Sem permissão para usar a localização. Autorize o acesso e tente de novo.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocateFailure(
        LocateFailureKind.permissionDeniedForever,
        'A localização foi bloqueada para este app. Libere nas configurações '
        'do aparelho para usar este botão.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );

    return LocateSuccess(
      GeoPoint(position.latitude, position.longitude),
      accuracyMeters:
          position.accuracy.isFinite && position.accuracy > 0
              ? position.accuracy
              : null,
    );
  } on LocationServiceDisabledException {
    return const LocateFailure(
      LocateFailureKind.serviceDisabled,
      'A localização do aparelho está desligada. Ative o GPS e tente de novo.',
    );
  } on PermissionDeniedException {
    return const LocateFailure(
      LocateFailureKind.permissionDenied,
      'Sem permissão para usar a localização. Autorize o acesso e tente de novo.',
    );
  } catch (err) {
    // No navegador, sem HTTPS nem localhost, a API de geolocalização do
    // próprio browser recusa a chamada — cai aqui, não num dos ramos acima.
    final message = err.toString();
    if (message.contains('secure') || message.contains('permissions policy')) {
      return const LocateFailure(
        LocateFailureKind.unsupported,
        'Este navegador só libera localização em conexão segura (HTTPS).',
      );
    }
    return const LocateFailure(
      LocateFailureKind.unknown,
      'Não foi possível obter a localização agora. Tente de novo.',
    );
  }
}
