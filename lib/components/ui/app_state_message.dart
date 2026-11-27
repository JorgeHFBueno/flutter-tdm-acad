import 'package:flutter/material.dart';

import 'status_tag.dart';

/// Estado de tela sem conteúdo: lista vazia, erro de carga, sem login.
///
/// Sempre o mesmo formato: etiqueta, mensagem e (opcional) uma ação.
class AppStateMessage extends StatelessWidget {
  const AppStateMessage({
    super.key,
    required this.tag,
    required this.message,
    this.tone = StatusTone.muted,
    this.action,
  });

  /// Lista ou tela sem dados ainda. [action] costuma ser "criar o primeiro".
  const AppStateMessage.empty(
    this.message, {
    super.key,
    this.action,
  })  : tag = 'Vazio',
        tone = StatusTone.muted;

  /// Falha ao carregar. Com [onRetry], mostra "Tentar novamente".
  AppStateMessage.error(
    this.message, {
    super.key,
    VoidCallback? onRetry,
  })  : tag = 'Erro',
        tone = StatusTone.error,
        action = onRetry == null
            ? null
            : OutlinedButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              );

  final String tag;
  final String message;
  final StatusTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusTag(tag, tone: tone),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
