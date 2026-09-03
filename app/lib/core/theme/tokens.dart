import 'package:flutter/material.dart';

/// Design tokens do Soberano.
///
/// Identidade: "brinco de gado" — amarelo estampado sobre verde-pasto profundo
/// e papel quente. Alto contraste para uso sob sol; alvos grandes para luva.
abstract final class TaColors {
  // Ground
  static const pasture = Color(0xFF1A2E1D); // verde-pasto profundo (headers, nav)
  static const pastureDeep = Color(0xFF122015); // variação mais escura
  static const paper = Color(0xFFFAF7F0); // superfícies claras
  static const paperDim = Color(0xFFF0EBDF); // fundo de página

  // Assinatura
  static const tagYellow = Color(0xFFF2B90D); // amarelo-brinco (ação primária)
  static const tagYellowDeep = Color(0xFFC79104); // pressed / bordas
  static const stamp = Color(0xFF17190F); // "tinta estampada" — texto sobre amarelo

  // Semânticas
  static const clay = Color(0xFFB4552D); // alerta, carência, conflito
  static const clayBg = Color(0xFFF6E3D9);
  static const sage = Color(0xFF5F7A4E); // ok, sincronizado, saúde em dia
  static const sageBg = Color(0xFFE4EADB);
  static const sky = Color(0xFF3E6B8C); // informação, blockchain
  static const skyBg = Color(0xFFDFE9F0);

  // Texto
  static const ink = Color(0xFF1E211B); // texto principal sobre claro
  static const inkSoft = Color(0xFF5C6154); // secundário
  static const paperInk = Color(0xFFF4F1E6); // texto sobre pasture
  static const paperInkSoft = Color(0xFFB9C2B0);

  static const line = Color(0xFFDDD6C6); // divisores sobre claro
}

abstract final class TaSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class TaRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
}
