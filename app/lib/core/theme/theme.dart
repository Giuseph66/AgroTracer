import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Tema claro único do app de campo: papel quente, verde-pasto e amarelo-brinco.
ThemeData buildTaTheme() {
  final display = GoogleFonts.archivoBlack();
  final body = GoogleFonts.archivo();
  final mono = GoogleFonts.splineSansMono();

  final textTheme = TextTheme(
    displayLarge: display.copyWith(fontSize: 40, height: 1.05, color: TaColors.ink),
    displayMedium: display.copyWith(fontSize: 28, height: 1.1, color: TaColors.ink),
    headlineMedium: display.copyWith(fontSize: 22, height: 1.15, color: TaColors.ink),
    titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: TaColors.ink),
    titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: TaColors.ink),
    titleSmall: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: TaColors.inkSoft), // "eyebrow" em caixa alta
    bodyLarge: body.copyWith(fontSize: 16, height: 1.4, color: TaColors.ink),
    bodyMedium: body.copyWith(fontSize: 14, height: 1.4, color: TaColors.ink),
    bodySmall: body.copyWith(fontSize: 12, height: 1.35, color: TaColors.inkSoft),
    labelLarge: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    labelMedium: mono.copyWith(fontSize: 13, color: TaColors.inkSoft), // códigos RFID, horas
    labelSmall: mono.copyWith(fontSize: 11, color: TaColors.inkSoft),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: TaColors.paperDim,
    colorScheme: const ColorScheme.light(
      primary: TaColors.tagYellow,
      onPrimary: TaColors.stamp,
      secondary: TaColors.sage,
      onSecondary: Colors.white,
      surface: TaColors.paper,
      onSurface: TaColors.ink,
      error: TaColors.clay,
      onError: Colors.white,
      outline: TaColors.line,
    ),
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TaColors.tagYellow,
        foregroundColor: TaColors.stamp,
        minimumSize: const Size(64, 56), // alvo de luva
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(TaRadius.rMd)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TaColors.ink,
        minimumSize: const Size(64, 56),
        side: const BorderSide(color: TaColors.ink, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(TaRadius.rMd)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    dividerTheme: const DividerThemeData(color: TaColors.line, thickness: 1, space: 1),
    cardTheme: const CardThemeData(
      color: TaColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(TaRadius.rLg),
        side: BorderSide(color: TaColors.line),
      ),
    ),
  );
}
