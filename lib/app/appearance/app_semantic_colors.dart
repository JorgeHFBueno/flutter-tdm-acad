import 'package:flutter/material.dart';

/// Cores com significado que o [ColorScheme] não cobre.
///
/// Uso: `AppSemanticColors.of(context).warning`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({required this.warning});

  /// Atenção que não é erro: máquina indisponível, configuração incompleta.
  final Color warning;

  /// Fallback para temas sem a extensão (ex.: MaterialApp cru nos testes).
  static final fallback = AppSemanticColors(warning: Colors.orange.shade800);

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ?? fallback;

  @override
  AppSemanticColors copyWith({Color? warning}) =>
      AppSemanticColors(warning: warning ?? this.warning);

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(warning: Color.lerp(warning, other.warning, t)!);
  }
}
