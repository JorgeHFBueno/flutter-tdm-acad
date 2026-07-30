import 'package:firebased/app/appearance/app_appearance_controller.dart';
import 'package:firebased/app/appearance/app_appearance_mode.dart';
import 'package:firebased/app/appearance/app_appearance_overlay.dart';
import 'package:firebased/app/appearance/app_appearance_preferences.dart';
import 'package:firebased/app/appearance/app_appearance_scope.dart';
import 'package:firebased/app/appearance/app_theme_factory.dart';
import 'package:firebased/app/appearance/retro/retro_colors.dart';
import 'package:firebased/app/appearance/retro/retro_crt_overlay.dart';
import 'package:firebased/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppAppearanceController controller() {
    return AppAppearanceController(
      preferences: AppAppearancePreferences(),
    );
  }

  Future<void> pumpAppearanceApp(
    WidgetTester tester,
    AppAppearanceController appearance,
    Widget child,
  ) async {
    await tester.pumpWidget(
      AppAppearanceScope(
        controller: appearance,
        child: AnimatedBuilder(
          animation: appearance,
          builder: (context, _) {
            return MaterialApp(
              theme: AppThemeFactory.build(appearance.mode),
              builder: (context, child) => AppAppearanceOverlay(
                child: child ?? const SizedBox.shrink(),
              ),
              home: child,
            );
          },
        ),
      ),
    );
  }

  test('appearance controller defaults to retro with moderate CRT', () async {
    final appearance = controller();

    await appearance.load();

    expect(appearance.mode, AppAppearanceMode.retro);
    expect(appearance.crtIntensity, 0.5);
    expect(appearance.isLoaded, isTrue);
  });

  test('appearance controller clamps and persists values', () async {
    final appearance = controller();
    await appearance.load();

    await appearance.setMode(AppAppearanceMode.standard);
    await appearance.setCrtIntensity(1.4);

    final reloaded = controller();
    await reloaded.load();

    expect(reloaded.mode, AppAppearanceMode.standard);
    expect(reloaded.crtIntensity, 1);
  });

  testWidgets('settings switches mode and disables CRT slider in standard',
      (tester) async {
    final appearance = controller();
    await appearance.load();

    await pumpAppearanceApp(tester, appearance, const SettingsScreen());

    expect(find.text('Interface Retro'), findsOneWidget);
    expect(find.text('Interface Standard'), findsOneWidget);
    expect(find.text('Intensidade: 50%'), findsOneWidget);
    expect(find.byType(RetroCrtOverlay), findsWidgets);

    await tester.tap(find.byKey(const Key('settings-appearance-standard')));
    await tester.pumpAndSettle();

    expect(appearance.mode, AppAppearanceMode.standard);
    expect(find.text('Disponivel na Interface Retro.'), findsOneWidget);

    final slider = tester.widget<Slider>(
      find.byKey(const Key('settings-crt-intensity-slider')),
    );
    expect(slider.onChanged, isNull);
    expect(find.byType(RetroCrtOverlay), findsNothing);
  });

  testWidgets('settings slider previews immediately and zero disables overlay',
      (tester) async {
    final appearance = controller();
    await appearance.load();

    await pumpAppearanceApp(tester, appearance, const SettingsScreen());

    final sliderFinder = find.byKey(const Key('settings-crt-intensity-slider'));
    tester.widget<Slider>(sliderFinder).onChanged?.call(0);
    await tester.pump();

    expect(appearance.crtIntensity, 0);
    expect(find.text('Intensidade: 0%'), findsOneWidget);
    expect(find.byType(RetroCrtOverlay), findsNothing);

    tester.widget<Slider>(sliderFinder).onChangeEnd?.call(0.75);
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble(AppAppearancePreferences.crtIntensityKey),
      0.75,
    );
  });

  testWidgets('retro theme is applied globally', (tester) async {
    final appearance = controller();
    await appearance.load();

    await pumpAppearanceApp(tester, appearance, const Scaffold());

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    expect(theme.scaffoldBackgroundColor, RetroColors.background);
    expect(theme.colorScheme.primary, RetroColors.amber);
  });
}
