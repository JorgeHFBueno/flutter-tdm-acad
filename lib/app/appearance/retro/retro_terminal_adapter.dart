import 'package:easy_terminal/easy_terminal.dart';
import 'package:flutter/material.dart';

import 'retro_colors.dart';

class RetroTerminalAdapter {
  const RetroTerminalAdapter._();

  static TerminalTheme theme() => const TerminalTheme(
        backgroundColor: RetroColors.surface,
        foregroundColor: RetroColors.text,
        cursorColor: RetroColors.amber,
        selectionColor: RetroColors.selection,
        borderColor: RetroColors.border,
        errorColor: RetroColors.error,
        successColor: RetroColors.success,
        warningColor: RetroColors.amberLight,
        fontFamily: 'monospace',
        fontSize: 14,
        lineHeight: 1.25,
        borderRadius: 3,
        borderWidth: 1,
      );
}

class RetroTerminalText extends StatelessWidget {
  const RetroTerminalText({
    super.key,
    required this.text,
    this.color,
    this.bold = false,
    this.align,
  });

  final String text;
  final Color? color;
  final bool bold;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return TerminalText(
      text: text,
      theme: RetroTerminalAdapter.theme(),
      color: color,
      isBold: bold,
      textAlign: align,
    );
  }
}
