import 'package:flutter/material.dart';

import 'retro_colors.dart';
import 'retro_effect_settings.dart';

class RetroScanlinePainter extends CustomPainter {
  const RetroScanlinePainter({
    required this.settings,
    this.sweepProgress,
  });

  final RetroCrtSettings settings;
  final double? sweepProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    if (settings.scanlineOpacity > 0) {
      final scanlinePaint = Paint()
        ..color = RetroColors.scanline.withValues(
          alpha: settings.scanlineOpacity,
        )
        ..strokeWidth = 1;
      for (double y = 0; y < size.height; y += 4) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
      }
    }

    if (settings.noiseOpacity > 0) {
      final noisePaint = Paint()
        ..color = RetroColors.text.withValues(alpha: settings.noiseOpacity)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 23) {
        final y = (x * 37) % size.height;
        canvas.drawCircle(Offset(x, y), 0.55, noisePaint);
      }
    }

    final progress = sweepProgress;
    if (progress != null && settings.sweepOpacity > 0) {
      final y = size.height * progress;
      final sweepPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            RetroColors.glow.withValues(alpha: settings.sweepOpacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, y - 18, size.width, 36));
      canvas.drawRect(Rect.fromLTWH(0, y - 18, size.width, 36), sweepPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RetroScanlinePainter oldDelegate) {
    return oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.settings.scanlineOpacity != settings.scanlineOpacity ||
        oldDelegate.settings.noiseOpacity != settings.noiseOpacity ||
        oldDelegate.settings.sweepOpacity != settings.sweepOpacity;
  }
}
