import 'package:flutter/material.dart';

import '../retro_colors.dart';
import '../retro_metrics.dart';
import '../retro_terminal_adapter.dart';

class RetroPanel extends StatelessWidget {
  const RetroPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RetroColors.surface,
        border: Border.all(color: RetroColors.border),
        borderRadius: BorderRadius.circular(RetroMetrics.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: RetroColors.surfaceAlternative,
              border: Border(
                bottom: BorderSide(color: RetroColors.border),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                RetroTerminalText(
                  text: title,
                  bold: true,
                  color: RetroColors.amber,
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(RetroMetrics.panelPadding),
            child: child,
          ),
        ],
      ),
    );
  }
}
