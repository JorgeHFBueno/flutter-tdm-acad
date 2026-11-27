import 'package:flutter/material.dart';

import '../../app/appearance/app_semantic_colors.dart';

enum StatusTone { active, done, warning, error, muted }

/// Etiqueta curta de estado no estilo terminal: `EM ANDAMENTO`, `VAZIO`.
///
/// `active` é preenchida (chama atenção); as demais são só contorno.
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, this.tone = StatusTone.muted});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      StatusTone.active || StatusTone.done => scheme.primary,
      StatusTone.warning => AppSemanticColors.of(context).warning,
      StatusTone.error => scheme.error,
      StatusTone.muted => scheme.onSurfaceVariant,
    };
    final filled = tone == StatusTone.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : null,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: filled ? scheme.onPrimary : color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
