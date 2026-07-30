import 'package:flutter/material.dart';

import 'retro_colors.dart';
import 'retro_metrics.dart';

class RetroTheme {
  const RetroTheme._();

  static ThemeData data() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: 'monospace',
      bodyColor: RetroColors.text,
      displayColor: RetroColors.text,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RetroMetrics.radius),
      borderSide: const BorderSide(color: RetroColors.border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: RetroColors.background,
      colorScheme: const ColorScheme.dark(
        primary: RetroColors.amber,
        onPrimary: RetroColors.textOnAmber,
        secondary: RetroColors.amberLight,
        onSecondary: RetroColors.textOnAmber,
        surface: RetroColors.surface,
        onSurface: RetroColors.text,
        error: RetroColors.error,
        onError: RetroColors.textOnAmber,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: RetroColors.surface,
        foregroundColor: RetroColors.amber,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: RetroColors.amber,
          fontFamily: 'monospace',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(color: RetroColors.amber),
      ),
      iconTheme: const IconThemeData(color: RetroColors.amber),
      drawerTheme: const DrawerThemeData(
        backgroundColor: RetroColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: RetroColors.amber,
        textColor: RetroColors.text,
        selectedColor: RetroColors.textOnAmber,
        selectedTileColor: RetroColors.amber,
      ),
      cardTheme: CardTheme(
        color: RetroColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroMetrics.radius),
          side: const BorderSide(color: RetroColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: RetroColors.border),
      dialogTheme: DialogTheme(
        backgroundColor: RetroColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroMetrics.radius),
          side: const BorderSide(color: RetroColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RetroColors.surfaceAlternative,
        labelStyle: const TextStyle(color: RetroColors.mutedText),
        hintStyle: const TextStyle(color: RetroColors.mutedText),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: RetroColors.amber),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: RetroColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: RetroColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroColors.amber,
          foregroundColor: RetroColors.textOnAmber,
          disabledBackgroundColor: RetroColors.disabled,
          disabledForegroundColor: RetroColors.mutedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RetroMetrics.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RetroColors.amber,
          side: const BorderSide(color: RetroColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RetroMetrics.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RetroColors.amberLight,
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RetroColors.amber,
        foregroundColor: RetroColors.textOnAmber,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? RetroColors.amber
              : RetroColors.surfaceAlternative,
        ),
        checkColor: WidgetStateProperty.all(RetroColors.textOnAmber),
        side: const BorderSide(color: RetroColors.borderStrong),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? RetroColors.amber
              : RetroColors.mutedText,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? RetroColors.amber
              : RetroColors.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? RetroColors.selection
              : RetroColors.surfaceAlternative,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: RetroColors.amber,
        inactiveTrackColor: RetroColors.border,
        thumbColor: RetroColors.amberLight,
        overlayColor: RetroColors.selection,
        valueIndicatorColor: RetroColors.amber,
        valueIndicatorTextStyle: TextStyle(color: RetroColors.textOnAmber),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RetroColors.amber,
        circularTrackColor: RetroColors.border,
        linearTrackColor: RetroColors.border,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: RetroColors.surfaceAlternative,
        contentTextStyle: TextStyle(
          color: RetroColors.text,
          fontFamily: 'monospace',
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: RetroColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: RetroColors.surfaceAlternative,
        textStyle: TextStyle(
          color: RetroColors.text,
          fontFamily: 'monospace',
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: RetroColors.surfaceAlternative,
          border: Border.all(color: RetroColors.border),
          borderRadius: BorderRadius.circular(RetroMetrics.radius),
        ),
        textStyle: const TextStyle(color: RetroColors.text),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: RetroColors.amber,
        unselectedLabelColor: RetroColors.mutedText,
        indicatorColor: RetroColors.amber,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: RetroColors.amber,
        collapsedIconColor: RetroColors.mutedText,
        textColor: RetroColors.text,
        collapsedTextColor: RetroColors.text,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: RetroColors.surfaceAlternative,
        selectedColor: RetroColors.amber,
        disabledColor: RetroColors.disabled,
        labelStyle: const TextStyle(color: RetroColors.text),
        secondaryLabelStyle: const TextStyle(color: RetroColors.textOnAmber),
        side: const BorderSide(color: RetroColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroMetrics.radius),
        ),
      ),
    );
  }
}
