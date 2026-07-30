import 'package:flutter/material.dart';

import 'app_appearance_scope.dart';
import 'retro/retro_crt_overlay.dart';

class AppAppearanceOverlay extends StatelessWidget {
  const AppAppearanceOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearanceScope.of(context);
    if (!appearance.shouldShowCrt) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        RetroCrtOverlay(intensity: appearance.crtIntensity),
      ],
    );
  }
}
