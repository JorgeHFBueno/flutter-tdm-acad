import 'package:firebased/app/appearance/app_appearance_mode.dart';
import 'package:firebased/app/appearance/app_theme_factory.dart';
import 'package:firebased/app/appearance/retro/retro_colors.dart';
import 'package:firebased/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login uses retro themed controls and remains scrollable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeFactory.build(AppAppearanceMode.retro),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 520),
            viewInsets: EdgeInsets.only(bottom: 260),
          ),
          child: LoginScreen(onTap: () {}),
        ),
      ),
    );

    expect(find.text('VANGUARD'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Registre-se'), findsOneWidget);
    expect(find.byType(AutofillGroup), findsOneWidget);

    final context = tester.element(find.text('Entrar'));
    expect(Theme.of(context).colorScheme.primary, RetroColors.amber);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login also renders with standard theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeFactory.build(AppAppearanceMode.standard),
        home: LoginScreen(onTap: () {}),
      ),
    );

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
