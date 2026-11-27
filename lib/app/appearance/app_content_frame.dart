import 'package:flutter/material.dart';

/// Em telas largas (Web no desktop), centraliza o app numa coluna de
/// [maxWidth] px em vez de esticar campos e cards de ponta a ponta.
/// Em telas estreitas (celular) não muda nada.
class AppContentFrame extends StatelessWidget {
  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) {
      return child;
    }

    final theme = Theme.of(context);
    final frameSize = Size(maxWidth, media.size.height);
    return ColoredBox(
      color: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.35),
        theme.scaffoldBackgroundColor,
      ),
      child: Center(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(
                color: theme.dividerTheme.color ?? theme.dividerColor,
              ),
            ),
          ),
          child: SizedBox(
            width: maxWidth,
            child: MediaQuery(
              data: media.copyWith(size: frameSize),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
