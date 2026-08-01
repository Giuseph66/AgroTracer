import 'package:flutter/foundation.dart';

import '../geo/geodesy.dart';
import '../geo/polygon_validation.dart';
import '../models/geo_point.dart';

/// Etapa do desenho de uma área.
enum DrawStage {
  /// Nada desenhado ainda.
  idle,

  /// Marcando os cantos.
  tracing,

  /// Contorno com pontos suficientes; dá para salvar ou continuar ajustando.
  closable,
}

/// Estado do desenho de um piquete.
///
/// Separado do widget de propósito: a máquina de estados do desenho é a parte
/// que erra na prática (undo no meio, ponto duplicado, contorno cruzado) e
/// precisa ser testável sem mapa, sem gesto e sem tile.
class AreaDrawController extends ChangeNotifier {
  AreaDrawController({List<GeoPoint>? initialRing})
      : _vertices = List.of(initialRing ?? const []);

  final List<GeoPoint> _vertices;

  /// Histórico para desfazer — o operador erra o toque com luva o tempo todo.
  final List<List<GeoPoint>> _history = [];

  int? _selectedIndex;

  List<GeoPoint> get vertices => List.unmodifiable(_vertices);
  int? get selectedIndex => _selectedIndex;
  bool get canUndo => _history.isNotEmpty;
  bool get isEmpty => _vertices.isEmpty;

  DrawStage get stage {
    if (_vertices.isEmpty) return DrawStage.idle;
    if (_vertices.length < 3) return DrawStage.tracing;
    return DrawStage.closable;
  }

  /// Medição ao vivo: com menos de três pontos ainda não há área, só a linha
  /// percorrida — mostrar "0 ha" enquanto se desenha confundiria.
  double get areaHectares =>
      _vertices.length < 3 ? 0 : Geodesy.polygonAreaHectares(_vertices);

  double get perimeterMeters => _vertices.length < 3
      ? Geodesy.pathLengthMeters(_vertices)
      : Geodesy.perimeterMeters(_vertices);

  String get formattedArea => Geodesy.formatArea(areaHectares);
  String get formattedPerimeter => Geodesy.formatDistance(perimeterMeters);

  /// Validação corrente do contorno. `null` enquanto não há pontos suficientes
  /// para ter o que validar.
  PolygonValidation? get validation =>
      _vertices.length < 3 ? null : PolygonValidation.check(_vertices);

  bool get canSave => validation?.isValid ?? false;

  void addVertex(GeoPoint point) {
    _pushHistory();
    _vertices.add(point);
    _selectedIndex = _vertices.length - 1;
    notifyListeners();
  }

  /// Move um vértice existente (arrastar para ajustar o canto).
  void moveVertex(int index, GeoPoint point) {
    if (index < 0 || index >= _vertices.length) return;
    _pushHistory();
    _vertices[index] = point;
    notifyListeners();
  }

  void removeVertex(int index) {
    if (index < 0 || index >= _vertices.length) return;
    _pushHistory();
    _vertices.removeAt(index);
    if (_selectedIndex != null && _selectedIndex! >= _vertices.length) {
      _selectedIndex = _vertices.isEmpty ? null : _vertices.length - 1;
    }
    notifyListeners();
  }

  /// Insere um ponto no meio de uma aresta — para refinar um contorno já feito
  /// sem ter que apagar tudo.
  void insertVertexAfter(int index, GeoPoint point) {
    if (index < 0 || index >= _vertices.length) return;
    _pushHistory();
    _vertices.insert(index + 1, point);
    _selectedIndex = index + 1;
    notifyListeners();
  }

  void select(int? index) {
    if (index != null && (index < 0 || index >= _vertices.length)) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    _vertices
      ..clear()
      ..addAll(previous);
    if (_selectedIndex != null && _selectedIndex! >= _vertices.length) {
      _selectedIndex = _vertices.isEmpty ? null : _vertices.length - 1;
    }
    notifyListeners();
  }

  void clear() {
    if (_vertices.isEmpty) return;
    _pushHistory();
    _vertices.clear();
    _selectedIndex = null;
    notifyListeners();
  }

  /// Carrega um contorno existente para edição.
  void load(List<GeoPoint> ring) {
    _pushHistory();
    _vertices
      ..clear()
      ..addAll(ring);
    _selectedIndex = null;
    notifyListeners();
  }

  /// Devolve o contorno pronto para salvar, ou `null` se ainda não é válido.
  List<GeoPoint>? build() => canSave ? List.of(_vertices) : null;

  void _pushHistory() {
    _history.add(List.of(_vertices));
    // Segurar histórico infinito não serve para nada no campo e come memória.
    if (_history.length > 50) _history.removeAt(0);
  }
}
