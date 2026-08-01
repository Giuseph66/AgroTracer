import 'package:flutter_test/flutter_test.dart';
import 'package:traceagro_map/traceagro_map.dart';

/// A máquina de estados do desenho é a parte que erra na prática: toque
/// duplicado com luva, desfazer no meio, contorno cruzado. Testar sem mapa
/// deixa esses casos explícitos.
void main() {
  group('AreaDrawController — etapas', () {
    test('começa vazio e sem medida', () {
      final c = AreaDrawController();

      expect(c.stage, DrawStage.idle);
      expect(c.isEmpty, isTrue);
      expect(c.areaHectares, 0);
      expect(c.canSave, isFalse);
      expect(c.validation, isNull);
    });

    test('com um ou dois pontos ainda está traçando, sem área', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.88, -51.71));

      expect(c.stage, DrawStage.tracing);
      expect(c.areaHectares, 0);
      // Mas já mede a linha percorrida — o operador vê que está funcionando.
      expect(c.perimeterMeters, greaterThan(0));
    });

    test('no terceiro ponto vira fechável e passa a medir área', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.88, -51.71))
        ..addVertex(const GeoPoint(-17.87, -51.71));

      expect(c.stage, DrawStage.closable);
      expect(c.areaHectares, greaterThan(0));
      expect(c.canSave, isTrue);
    });
  });

  group('AreaDrawController — edição', () {
    AreaDrawController square() => AreaDrawController()
      ..addVertex(const GeoPoint(-17.88, -51.72))
      ..addVertex(const GeoPoint(-17.88, -51.71))
      ..addVertex(const GeoPoint(-17.87, -51.71))
      ..addVertex(const GeoPoint(-17.87, -51.72));

    test('mover vértice muda a medida', () {
      final c = square();
      final before = c.areaHectares;

      c.moveVertex(2, const GeoPoint(-17.86, -51.71));

      expect(c.areaHectares, isNot(closeTo(before, 0.01)));
      expect(c.areaHectares, greaterThan(before));
    });

    test('remover vértice encolhe o contorno', () {
      final c = square();
      c.removeVertex(0);

      expect(c.vertices, hasLength(3));
      expect(c.stage, DrawStage.closable);
    });

    test('inserir ponto no meio de uma aresta refina o contorno', () {
      final c = square();
      c.insertVertexAfter(1, const GeoPoint(-17.875, -51.705));

      expect(c.vertices, hasLength(5));
      expect(c.vertices[2], const GeoPoint(-17.875, -51.705));
      expect(c.selectedIndex, 2);
    });

    test('índice fora da faixa é ignorado, não estoura', () {
      final c = square();
      final before = c.vertices;

      c.moveVertex(99, const GeoPoint(0, 0));
      c.removeVertex(-1);
      c.insertVertexAfter(50, const GeoPoint(0, 0));
      c.select(42);

      expect(c.vertices, before);
    });
  });

  group('AreaDrawController — desfazer', () {
    test('desfaz o último ponto marcado', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.88, -51.71));

      expect(c.canUndo, isTrue);
      c.undo();

      expect(c.vertices, hasLength(1));
      expect(c.vertices.first, const GeoPoint(-17.88, -51.72));
    });

    test('desfaz um movimento de vértice, não só a inclusão', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.88, -51.71))
        ..addVertex(const GeoPoint(-17.87, -51.71));

      c.moveVertex(0, const GeoPoint(-17.90, -51.75));
      expect(c.vertices.first, const GeoPoint(-17.90, -51.75));

      c.undo();
      expect(c.vertices.first, const GeoPoint(-17.88, -51.72));
    });

    test('limpar também é desfazível — apagar tudo sem querer acontece', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.88, -51.71))
        ..addVertex(const GeoPoint(-17.87, -51.71));

      c.clear();
      expect(c.isEmpty, isTrue);

      c.undo();
      expect(c.vertices, hasLength(3));
    });

    test('desfazer sem histórico não faz nada', () {
      final c = AreaDrawController();
      expect(c.canUndo, isFalse);
      c.undo();
      expect(c.isEmpty, isTrue);
    });
  });

  group('AreaDrawController — salvar', () {
    test('contorno cruzado não pode ser salvo', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.87, -51.71))
        ..addVertex(const GeoPoint(-17.88, -51.71))
        ..addVertex(const GeoPoint(-17.87, -51.72));

      expect(c.canSave, isFalse);
      expect(c.build(), isNull);
      expect(
        c.validation!.issues,
        contains(PolygonIssue.selfIntersecting),
      );
    });

    test('contorno válido devolve cópia dos vértices', () {
      final c = AreaDrawController()
        ..addVertex(const GeoPoint(-17.88, -51.72))
        ..addVertex(const GeoPoint(-17.88, -51.71))
        ..addVertex(const GeoPoint(-17.87, -51.71));

      final ring = c.build();
      expect(ring, hasLength(3));

      // Cópia, não referência: mexer no controlador depois de salvar não pode
      // alterar o que já foi entregue para persistir.
      c.addVertex(const GeoPoint(-17.87, -51.72));
      expect(ring, hasLength(3));
    });

    test('carrega contorno existente para edição', () {
      const existing = [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
      ];

      final c = AreaDrawController()..load(existing);

      expect(c.vertices, existing);
      expect(c.canSave, isTrue);
      // E dá para voltar ao estado anterior à carga.
      c.undo();
      expect(c.isEmpty, isTrue);
    });

    test('inicia já com contorno quando recebe um', () {
      final c = AreaDrawController(initialRing: const [
        GeoPoint(-17.88, -51.72),
        GeoPoint(-17.88, -51.71),
        GeoPoint(-17.87, -51.71),
      ]);

      expect(c.stage, DrawStage.closable);
      expect(c.canSave, isTrue);
    });
  });

  group('AreaDrawController — notificação', () {
    test('avisa a interface a cada mudança', () {
      final c = AreaDrawController();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.addVertex(const GeoPoint(-17.88, -51.72));
      c.addVertex(const GeoPoint(-17.88, -51.71));
      c.moveVertex(0, const GeoPoint(-17.89, -51.72));
      c.undo();
      c.clear();

      expect(notifications, 5);
    });

    test('operação sem efeito não notifica à toa', () {
      final c = AreaDrawController();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.clear(); // já está vazio
      c.undo(); // sem histórico

      expect(notifications, 0);
    });
  });
}
