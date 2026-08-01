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
    this.maxNativeZoom = 18,
    this.userAgentPackageName = 'br.com.neurelix.traceagro',
  });

  final String urlTemplate;
  final String attribution;
  final List<String> subdomains;

  /// Até onde a câmera pode aproximar.
  final double maxZoom;
  final double minZoom;

  /// Último nível em que o provedor realmente tem imagem.
  ///
  /// Precisa ser menor que [maxZoom] em base de satélite: a cobertura em área
  /// rural termina antes da urbana, e pedir um nível inexistente devolve o
  /// tile de aviso do próprio servidor ("Map data not yet available"), que
  /// toma a tela inteira. Parando aqui, o mapa amplia o último tile válido —
  /// fica borrado, mas o operador continua vendo a cerca que está seguindo.
  final int maxNativeZoom;

  final String userAgentPackageName;

  /// Mapa de ruas padrão. Serve para localizar a propriedade e as estradas.
  /// O acervo do OSM chega ao nível 19 em todo lugar.
  static const openStreetMap = TileSource(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap',
    maxZoom: 19,
    maxNativeZoom: 19,
  );

  /// Imagem de satélite: para desenhar piquete, o operador precisa ver a
  /// cerca e a vegetação, não o traçado de ruas.
  ///
  /// A câmera vai até 19 para permitir marcar canto com precisão, mas os tiles
  /// param em 17. O limite foi medido na região do piloto (Jataí-GO): até o
  /// nível 17 o acervo devolve imagem de 20 a 27 KB; do 18 em diante devolve
  /// sempre os mesmos 2.521 bytes do aviso "Map data not yet available", que
  /// tomava a tela inteira no lugar da foto.
  static const satellite = TileSource(
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri, Maxar, Earthstar Geographics',
    maxZoom: 19,
    maxNativeZoom: 17,
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
      // Passando deste nível, o flutter_map amplia o último tile baixado em
      // vez de pedir um que o provedor não tem.
      maxNativeZoom: maxNativeZoom,
      maxZoom: maxZoom,
      subdomains: subdomains,
      // Enquanto o tile do nível novo não chega, mantém o anterior na tela:
      // sem isso o mapa pisca em branco a cada aproximação.
      keepBuffer: 3,
    );
  }
}
