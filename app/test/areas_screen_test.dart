import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_map/traceagro_map.dart';

/// Regressão do arranjo da tela de áreas.
///
/// O mapa é o primeiro filho de um Stack cujo cabeçalho fica sobreposto. Se o
/// Stack não expandir, ele se dimensiona pelo cabeçalho e o mapa fica com a
/// altura dele — visualmente a tela parece vazia, sem nenhum erro no console.
/// Foi exatamente o que aconteceu, e este teste é o que pegou.
///
/// Os tiles usam a fonte offline: o teste verifica geometria e layout, não
/// download de imagem.
void main() {
  final areas = [
    MapArea(
      id: 'p1',
      name: 'Recria 12',
      ring: const [
        GeoPoint(-17.870, -51.725),
        GeoPoint(-17.870, -51.715),
        GeoPoint(-17.879, -51.715),
        GeoPoint(-17.879, -51.725),
      ],
      animalCount: 12,
      healthStatus: AreaHealthStatus.clear,
    ),
  ];

  Widget screenLike({required bool expand}) => MaterialApp(
        home: MapThemeProvider(
          theme: const MapTheme(),
          child: Scaffold(
            body: Stack(
              fit: expand ? StackFit.expand : StackFit.loose,
              children: [
                Positioned.fill(
                  child: AreaMapView(
                    areas: areas,
                    tileSource: TileSource.offline,
                    onAreaSelected: (_) {},
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 80, color: const Color(0xFF1A2E1D)),
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('mapa ocupa a tela inteira, não a altura do cabeçalho',
      (tester) async {
    await tester.pumpWidget(screenLike(expand: true));
    await tester.pump(const Duration(milliseconds: 100));

    final mapSize = tester.getSize(find.byType(FlutterMap));
    final screenSize = tester.getSize(find.byType(Scaffold));

    expect(mapSize.height, screenSize.height);
    expect(mapSize.width, screenSize.width);
  });

  testWidgets('as áreas viram polígonos com todos os vértices',
      (tester) async {
    await tester.pumpWidget(screenLike(expand: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PolygonLayer), findsOneWidget);
    final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(layer.polygons, hasLength(1));
    expect(layer.polygons.first.points, hasLength(4));
  });

  testWidgets('rótulo da área não estoura a caixa', (tester) async {
    await tester.pumpWidget(screenLike(expand: true));
    await tester.pump(const Duration(milliseconds: 100));

    // Overflow de layout vira exceção capturada pelo binding de teste.
    expect(tester.takeException(), isNull);
    expect(find.text('Recria 12'), findsOneWidget);
  });
}
