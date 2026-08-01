import 'package:flutter/material.dart';

import '../models/map_area.dart';

/// Paleta dos componentes de mapa.
///
/// Os valores espelham a identidade definida em `AGENTS.md` §2, mas ficam
/// declarados aqui para que o pacote não dependa do tema do app — quem consome
/// pode passar um [MapTheme] próprio se a identidade mudar.
class MapTheme {
  const MapTheme({
    this.pasture = const Color(0xFF1A2E1D),
    this.paper = const Color(0xFFFAF7F0),
    this.paperDim = const Color(0xFFF0EBDF),
    this.tagYellow = const Color(0xFFF2B90D),
    this.tagYellowDeep = const Color(0xFFC79104),
    this.stamp = const Color(0xFF17190F),
    this.clay = const Color(0xFFB4552D),
    this.sage = const Color(0xFF5F7A4E),
    this.sky = const Color(0xFF3E6B8C),
    this.ink = const Color(0xFF1E211B),
    this.inkSoft = const Color(0xFF5C6154),
    this.paperInk = const Color(0xFFF4F1E6),
    this.line = const Color(0xFFDDD6C6),
  });

  final Color pasture;
  final Color paper;
  final Color paperDim;
  final Color tagYellow;
  final Color tagYellowDeep;
  final Color stamp;
  final Color clay;
  final Color sage;
  final Color sky;
  final Color ink;
  final Color inkSoft;
  final Color paperInk;
  final Color line;

  /// Cor de contorno da área conforme a situação sanitária. É o que faz o mapa
  /// responder à pergunta "onde tem problema?" sem precisar abrir nada.
  Color strokeFor(AreaHealthStatus status) => switch (status) {
        AreaHealthStatus.blocked => clay,
        AreaHealthStatus.withdrawal => tagYellowDeep,
        AreaHealthStatus.clear => sage,
        AreaHealthStatus.empty => inkSoft,
        AreaHealthStatus.unknown => inkSoft,
      };

  /// Preenchimento translúcido: o tile precisa continuar legível por baixo.
  Color fillFor(AreaHealthStatus status) =>
      strokeFor(status).withValues(alpha: status == AreaHealthStatus.empty ? 0.10 : 0.22);

  IconData iconFor(AreaHealthStatus status) => switch (status) {
        AreaHealthStatus.blocked => Icons.block,
        AreaHealthStatus.withdrawal => Icons.timer_outlined,
        AreaHealthStatus.clear => Icons.check_circle_outline,
        AreaHealthStatus.empty => Icons.crop_landscape,
        AreaHealthStatus.unknown => Icons.help_outline,
      };

  static const MapTheme fallback = MapTheme();

  /// Lê o tema do contexto, caindo no padrão quando não há provedor — assim um
  /// componente isolado funciona numa tela qualquer sem configuração.
  static MapTheme of(BuildContext context) =>
      MapThemeProvider.maybeOf(context) ?? fallback;
}

class MapThemeProvider extends InheritedWidget {
  const MapThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  final MapTheme theme;

  static MapTheme? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MapThemeProvider>()
      ?.theme;

  @override
  bool updateShouldNotify(MapThemeProvider oldWidget) =>
      theme != oldWidget.theme;
}
