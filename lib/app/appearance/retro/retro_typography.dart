import 'package:flutter/material.dart';

import 'retro_colors.dart';

/// Fonte e escala de texto do tema Retro.
///
/// Telas usam os papéis do [TextTheme] (nunca fontSize solto):
/// - headlineSmall: título da página (nome do treino, da máquina)
/// - titleMedium: título de seção ("Eventos", "Exercícios")
/// - titleSmall: nome de item em lista/card
/// - bodyMedium: texto corrido
/// - bodySmall: legenda / informação secundária
class RetroTypography {
  const RetroTypography._();

  /// Embutida em assets/fonts (JetBrains Mono, OFL): igual no Web e no Android.
  static const fontFamily = 'JetBrainsMono';

  static TextTheme textTheme(TextTheme base) {
    return base
        .apply(
          fontFamily: fontFamily,
          bodyColor: RetroColors.text,
          displayColor: RetroColors.text,
        )
        .copyWith(
          headlineSmall: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: RetroColors.amber,
          ),
          titleLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: RetroColors.text,
          ),
          titleMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: RetroColors.amber,
          ),
          titleSmall: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: RetroColors.text,
          ),
          bodyLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            height: 1.4,
            color: RetroColors.text,
          ),
          bodyMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            height: 1.4,
            color: RetroColors.text,
          ),
          bodySmall: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1.35,
            color: RetroColors.mutedText,
          ),
          labelLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        );
  }
}
