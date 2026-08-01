import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Origem dos tiles do mapa.
///
/// Em propriedade rural a rede é a exceção, não a regra. O padrão aponta para
/// OpenStreetMap, mas a camada é trocável: quando o cache offline entrar
/// (backlog B2, questão Q2), basta passar outro [TileSource] — os componentes
/// não sabem de onde o tile vem.
class TileSource {
  const TileSource({
    required this.urlTemplate,
    required this.attribution,
    this.subdomains = const [],
    this.maxZoom = 19,
    this.minZoom = 3,
    this.userAgentPackageName = 'br.com.neurelix.traceagro',
  });

  final String urlTemplate;
  final String attribution;
  final List<String> subdomains;
  final double maxZoom;
  final double minZoom;
  final String userAgentPackageName;

  /// Mapa de ruas padrão. Serve para localizar a propriedade e as estradas.
  static const openStreetMap = TileSource(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap',
  );

  /// Imagem de satélite: para desenhar piquete, o operador precisa ver a
  /// cerca e a vegetação, não o traçado de ruas.
  static const satellite = TileSource(
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri, Maxar, Earthstar Geographics',
    maxZoom: 18,
  );

  /// Sem rede: nenhum tile é buscado e o mapa mostra só as geometrias sobre
  /// fundo liso. É o modo honesto de operar offline — melhor um fundo vazio do
  /// que uma tela travada esperando tile que não vem.
  static const offline = TileSource(
    urlTemplate: '',
    attribution: 'Sem base cartográfica — modo offline',
  );

  bool get isOffline => urlTemplate.isEmpty;

  Widget buildLayer() {
    if (isOffline) return const SizedBox.shrink();
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
      maxNativeZoom: maxZoom.toInt(),
      subdomains: subdomains,
    );
  }
}
