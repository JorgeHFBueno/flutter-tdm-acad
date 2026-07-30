import 'package:flutter/foundation.dart';

import 'app_appearance_mode.dart';
import 'app_appearance_preferences.dart';

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController({
    AppAppearancePreferences? preferences,
    AppAppearanceMode defaultMode = AppAppearanceMode.retro,
    double defaultCrtIntensity = 0.5,
  })  : _preferences = preferences ?? AppAppearancePreferences(),
        _mode = defaultMode,
        _crtIntensity = defaultCrtIntensity.clamp(0.0, 1.0);

  final AppAppearancePreferences _preferences;
  AppAppearanceMode _mode;
  double _crtIntensity;
  bool _isLoaded = false;

  AppAppearanceMode get mode => _mode;
  double get crtIntensity => _crtIntensity;
  bool get isLoaded => _isLoaded;
  bool get isRetro => _mode == AppAppearanceMode.retro;
  bool get shouldShowCrt => isRetro && _crtIntensity > 0;

  Future<void> load() async {
    final loadedMode = await _preferences.loadMode();
    final loadedIntensity = await _preferences.loadCrtIntensity();

    _mode = loadedMode ?? _mode;
    _crtIntensity = (loadedIntensity ?? _crtIntensity).clamp(0.0, 1.0);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppAppearanceMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    await _preferences.saveMode(mode);
  }

  void previewCrtIntensity(double value) {
    final nextValue = value.clamp(0.0, 1.0);
    if (_crtIntensity == nextValue) {
      return;
    }
    _crtIntensity = nextValue;
    notifyListeners();
  }

  Future<void> setCrtIntensity(double value) async {
    previewCrtIntensity(value);
    await _preferences.saveCrtIntensity(_crtIntensity);
  }
}
