import 'package:flutter/material.dart';

import '../../app/appearance/app_appearance_scope.dart';
import '../../app/appearance/retro/widgets/retro_panel.dart';

/// Bloco padrão das telas: título + conteúdo.
///
/// No modo Retro vira o [RetroPanel] (faixa de título estilo terminal);
/// no Standard, um Card com título.
class AppPanel extends StatelessWidget {
  const AppPanel({
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
    final isRetro = AppAppearanceScope.maybeOf(context)?.isRetro ?? false;
    if (isRetro) {
      return RetroPanel(title: title, trailing: trailing, child: child);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
