import 'package:flutter/material.dart';

import '../app/appearance/app_appearance_mode.dart';
import '../app/appearance/app_appearance_scope.dart';
import '../app/appearance/retro/retro_colors.dart';
import '../app/appearance/retro/retro_crt_overlay.dart';
import '../app/appearance/retro/retro_terminal_adapter.dart';
import '../app/appearance/retro/widgets/retro_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _draftIntensity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _draftIntensity = AppAppearanceScope.of(context).crtIntensity;
  }

  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearanceScope.of(context);
    final isRetro = appearance.isRetro;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'INTERFACE',
          retro: isRetro,
          child: Column(
            children: [
              _ModeOption(
                mode: AppAppearanceMode.retro,
                groupValue: appearance.mode,
                onChanged: appearance.setMode,
              ),
              const SizedBox(height: 8),
              _ModeOption(
                mode: AppAppearanceMode.standard,
                groupValue: appearance.mode,
                onChanged: appearance.setMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'EFEITO CRT',
          retro: isRetro,
          child: _CrtSettings(
            enabled: isRetro,
            intensity: _draftIntensity,
            onChanged: (value) {
              setState(() => _draftIntensity = value);
              appearance.previewCrtIntensity(value);
            },
            onChangeEnd: appearance.setCrtIntensity,
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'CRT PREVIEW',
          retro: isRetro,
          child: _CrtPreview(
            enabled: isRetro && _draftIntensity > 0,
            intensity: _draftIntensity,
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(child: body),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    required this.retro,
  });

  final String title;
  final Widget child;
  final bool retro;

  @override
  Widget build(BuildContext context) {
    if (retro) {
      return RetroPanel(title: title, child: child);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.groupValue,
    required this.onChanged,
  });

  final AppAppearanceMode mode;
  final AppAppearanceMode groupValue;
  final ValueChanged<AppAppearanceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = mode == groupValue;
    return Semantics(
      button: true,
      selected: selected,
      label: mode.label,
      child: RadioListTile<AppAppearanceMode>(
        key: Key('settings-appearance-${mode.storageValue}'),
        value: mode,
        groupValue: groupValue,
        onChanged: (_) => onChanged(mode),
        selected: selected,
        title: Text(mode.label),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class _CrtSettings extends StatelessWidget {
  const _CrtSettings({
    required this.enabled,
    required this.intensity,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final bool enabled;
  final double intensity;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final percent = (intensity * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intensidade: $percent%'),
        const SizedBox(height: 8),
        Semantics(
          label: 'Intensidade do efeito CRT',
          value: '$percent%',
          enabled: enabled,
          child: Slider(
            key: const Key('settings-crt-intensity-slider'),
            value: intensity,
            min: 0,
            max: 1,
            divisions: 20,
            label: '$percent%',
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0%'),
            Text('25%'),
            Text('50%'),
            Text('75%'),
            Text('100%'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          enabled
              ? '0% desliga o CRT. 100% mantem o efeito forte e legivel.'
              : 'Disponivel na Interface Retro.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CrtPreview extends StatelessWidget {
  const _CrtPreview({
    required this.enabled,
    required this.intensity,
  });

  final bool enabled;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final isRetro = AppAppearanceScope.of(context).isRetro;
    final previewText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRetro) ...[
          const RetroTerminalText(
            text: 'VANGUARD // DISPLAY TEST',
            bold: true,
            color: RetroColors.amber,
          ),
          const SizedBox(height: 6),
          const RetroTerminalText(text: 'SCANLINE 01'),
          const RetroTerminalText(text: 'SYSTEM READY'),
        ] else ...[
          Text(
            'VANGUARD // DISPLAY TEST',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          const Text('SCANLINE 01'),
          const Text('SYSTEM READY'),
        ],
      ],
    );

    return ClipRect(
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color:
                    isRetro ? RetroColors.surfaceAlternative : Colors.black12,
                border: Border.all(
                  color: isRetro
                      ? RetroColors.border
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: previewText,
              ),
            ),
            if (enabled) RetroCrtOverlay(intensity: intensity),
          ],
        ),
      ),
    );
  }
}
