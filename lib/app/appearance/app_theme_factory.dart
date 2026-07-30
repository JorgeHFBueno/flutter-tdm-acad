import 'package:flutter/material.dart';

import 'app_appearance_mode.dart';
import 'retro/retro_theme.dart';
import 'standard_app_theme.dart';

class AppThemeFactory {
  const AppThemeFactory._();

  static ThemeData build(AppAppearanceMode mode) {
    switch (mode) {
      case AppAppearanceMode.retro:
        return RetroTheme.data();
      case AppAppearanceMode.standard:
        return StandardAppTheme.data();
    }
  }
}
