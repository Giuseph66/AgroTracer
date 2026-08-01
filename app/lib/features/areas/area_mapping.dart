import 'package:traceagro_map/traceagro_map.dart';

import '../../domain/models.dart';

/// Ponte entre o domínio do app e o pacote de mapa.
///
/// O pacote não conhece `Paddock` nem `PaddockAnimal` de propósito — quem
/// converte é o app. Concentrar a conversão aqui evita que a regra de "qual
/// cor a área recebe" se espalhe pelas telas.
extension PaddockMapping on Paddock {
  /// Converte para a área desenhável no mapa.
  ///
  /// Devolve `null` quando o piquete não tem geometria: um contorno com menos
  /// de três pontos não é uma área, e inventar um retângulo qualquer no lugar
  /// mostraria ao operador um piquete que não existe daquele jeito.
  MapArea? toMapArea() {
    if (!hasBoundary) return null;
    return MapArea(
      id: id,
      name: name,
      ring: boundary.map((c) => GeoPoint(c[1], c[0])).toList(),
      animalCount: animalCount,
      healthStatus: _statusFor(this),
      kind: AreaKind.paddock,
    );
  }
}

/// A área herda o pior estado entre os animais que estão nela.
///
/// A decisão que o operador toma olhando o mapa é sobre o lote inteiro
/// ("posso mandar esse piquete para o embarque?"), então um único animal com
/// restrição precisa mudar a cor da área toda — o contrário esconderia o
/// problema até alguém abrir a ficha.
AreaHealthStatus _statusFor(Paddock paddock) {
  if (paddock.animalCount == 0) return AreaHealthStatus.empty;
  if (paddock.alertCount > 0) return AreaHealthStatus.withdrawal;
  return AreaHealthStatus.clear;
}

/// Converte a lista de piquetes, descartando os que ainda não têm contorno.
List<MapArea> toMapAreas(Iterable<Paddock> paddocks) =>
    paddocks.map((p) => p.toMapArea()).whereType<MapArea>().toList();

/// Anel do mapa de volta para o formato da API (GeoJSON: longitude primeiro).
List<List<double>> ringToApi(List<GeoPoint> ring) =>
    ring.map((p) => p.toGeoJsonCoordinate()).toList();

extension PaddockAnimalMapping on PaddockAnimal {
  /// Estado sanitário do animal, para colorir a linha na lista da área.
  AreaHealthStatus get mapStatus {
    if (lifecycleStatus == 'QUARANTINED') return AreaHealthStatus.blocked;
    if (withdrawalUntil != null && withdrawalUntil!.isAfter(DateTime.now())) {
      return AreaHealthStatus.withdrawal;
    }
    return AreaHealthStatus.clear;
  }
}
