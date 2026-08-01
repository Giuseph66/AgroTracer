import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_map/traceagro_map.dart';

/// `edgeMidpoints` decide onde aparecem os alvos de "inserir ponto aqui" no
/// desenho de um piquete. É função pura de propósito: o gesto (toque) é
/// widget, mas "qual aresta existe e onde fica o meio dela" não precisa de
/// mapa nenhum para ser testado.
void main() {
  group('edgeMidpoints', () {
    test('sem pontos ou com um só, não há aresta', () {
      expect(edgeMidpoints(const []), isEmpty);
      expect(edgeMidpoints(const [GeoPoint(-17.88, -51.72)]), isEmpty);
    });

    test('dois pontos: uma aresta só, sem fechar', () {
      const a = GeoPoint(-17.88, -51.72);
      const b = GeoPoint(-17.87, -51.71);

      final mids = edgeMidpoints([a, b]);

      expect(mids, hasLength(1));
      expect(mids.first.afterIndex, 0);
      expect(mids.first.point, Geodesy.midpoint(a, b));
    });

    test('três pontos: inclui a aresta de fechamento entre o último e o primeiro', () {
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
      ];

      final mids = edgeMidpoints(ring);

      expect(mids, hasLength(3));
      expect(mids.map((m) => m.afterIndex), [0, 1, 2]);
      // A aresta de fechamento (depois do último) volta para o primeiro.
      expect(mids.last.point, Geodesy.midpoint(ring[2], ring[0]));
    });

    test('quatro pontos: quatro arestas, uma por lado do quadrado', () {
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.87, -51.72),
      ];

      final mids = edgeMidpoints(ring);

      expect(mids, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(
          mids[i].point,
          Geodesy.midpoint(ring[i], ring[(i + 1) % 4]),
        );
      }
    });

    test('inserir no índice devolvido reproduz o ponto médio', () {
      // Simula o que o controller faz: insertVertexAfter(afterIndex, point).
      const ring = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
        GeoPoint(-17.87, -51.72),
      ];
      final mids = edgeMidpoints(ring);
      final target = mids[1]; // aresta entre o vértice 1 e o 2

      final withInserted = [...ring]..insert(target.afterIndex + 1, target.point);

      expect(withInserted, hasLength(5));
      expect(withInserted[2], target.point);
      // Os vizinhos do ponto inserido continuam sendo as pontas da aresta
      // original — a inserção não bagunçou a ordem do contorno.
      expect(withInserted[1], ring[1]);
      expect(withInserted[3], ring[2]);
    });
  });

  group('Geodesy.midpoint', () {
    test('é a média aritmética de latitude e longitude', () {
      const a = GeoPoint(-17.80, -51.70);
      const b = GeoPoint(-17.90, -51.74);

      final mid = Geodesy.midpoint(a, b);

      expect(mid.latitude, closeTo(-17.85, 1e-9));
      expect(mid.longitude, closeTo(-51.72, 1e-9));
    });

    test('ponto médio de um ponto consigo mesmo é ele mesmo', () {
      const a = GeoPoint(-17.80, -51.70);
      expect(Geodesy.midpoint(a, a), a);
    });
  });
}
