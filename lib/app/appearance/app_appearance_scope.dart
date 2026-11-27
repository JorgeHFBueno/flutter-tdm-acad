import 'package:flutter/widgets.dart';

import 'app_appearance_controller.dart';

class AppAppearanceScope extends InheritedNotifier<AppAppearanceController> {
  const AppAppearanceScope({
    super.key,
    required AppAppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppAppearanceController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppAppearanceScope>();
    assert(scope != null, 'AppAppearanceScope not found in context.');
    return scope!.notifier!;
  }

  /// Como [of], mas devolve null fora do escopo (ex.: telas montadas em teste).
  static AppAppearanceController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppAppearanceScope>()
        ?.notifier;
  }

  static AppAppearanceController read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppAppearanceScope>();
    final scope = element?.widget as AppAppearanceScope?;
    assert(scope != null, 'AppAppearanceScope not found in context.');
    return scope!.notifier!;
  }
}
