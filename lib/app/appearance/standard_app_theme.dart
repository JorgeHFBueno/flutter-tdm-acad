import 'package:flutter/material.dart';

class StandardAppTheme {
  const StandardAppTheme._();

  static ThemeData data() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
  }
}
