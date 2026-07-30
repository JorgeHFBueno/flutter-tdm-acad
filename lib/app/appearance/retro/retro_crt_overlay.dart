import 'package:flutter/material.dart';

import 'retro_colors.dart';
import 'retro_effect_settings.dart';
import 'retro_scanline_painter.dart';

class RetroCrtOverlay extends StatefulWidget {
  const RetroCrtOverlay({
    super.key,
    required this.intensity,
  });

  final double intensity;

  @override
  State<RetroCrtOverlay> createState() => _RetroCrtOverlayState();
}

class _RetroCrtOverlayState extends State<RetroCrtOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = RetroCrtSettings.fromIntensity(widget.intensity);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                RetroColors.glow.withValues(alpha: settings.glowOpacity),
                Colors.transparent,
                RetroColors.background.withValues(
                  alpha: settings.vignetteOpacity,
                ),
              ],
              stops: const [0, 0.58, 1],
              radius: 1.15,
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: RetroScanlinePainter(
                  settings: settings,
                  sweepProgress: disableAnimations ? null : _controller.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}
