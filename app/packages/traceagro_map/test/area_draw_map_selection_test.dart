import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_map/traceagro_map.dart';

/// Regressão: remover o vértice selecionado tem que desmarcar a seleção.
///
/// O controller mantém `selectedIndex` num índice válido depois de uma
/// remoção — correto para o controller em geral, mas se a interface não
/// desmarcasse, a barra de contexto continuaria de pé sobre o vizinho que
/// "herdou" aquele índice, e um segundo toque em "Remover" apagaria esse
/// vizinho sem o operador ter escolhido isso.
void main() {
  const square = [
    GeoPoint(-17.880, -51.720),
    GeoPoint(-17.880, -51.710),
    GeoPoint(-17.870, -51.710),
    GeoPoint(-17.870, -51.720),
  ];

  Widget host(AreaDrawController controller) => MaterialApp(
        home: MapThemeProvider(
          theme: const MapTheme(),
          child: Scaffold(
            body: AreaDrawMap(
              controller: controller,
              tileSource: TileSource.offline,
              onSave: (_) {},
            ),
          ),
        ),
      );

  testWidgets(
      'remover o ponto selecionado limpa a seleção, não pula para o vizinho',
      (tester) async {
    final controller = AreaDrawController(initialRing: square);
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    await tester.pump(const Duration(milliseconds: 100));

    controller.select(1);
    await tester.pump();

    expect(find.textContaining('Ponto 2 selecionado'), findsOneWidget);

    await tester.tap(find.text('Remover'));
    await tester.pump();

    expect(controller.selectedIndex, isNull);
    expect(find.textContaining('selecionado'), findsNothing);
    expect(controller.vertices, hasLength(3));
  });

  testWidgets('tocar no meio de uma aresta insere um vértice ali',
      (tester) async {
    final controller = AreaDrawController(initialRing: square);
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.vertices, hasLength(4));

    final expectedMidpoint = Geodesy.midpoint(square[0], square[1]);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(controller.vertices, hasLength(5));
    expect(controller.vertices[1], expectedMidpoint);
  });
}
