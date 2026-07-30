import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_appearance_mode.dart';

class AppAppearancePreferences {
  AppAppearancePreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  static const modeKey = 'app_appearance_mode';
  static const crtIntensityKey = 'app_crt_intensity';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _instance() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<AppAppearanceMode?> loadMode() async {
    try {
      final preferences = await _instance();
      return AppAppearanceModeLabel.fromStorageValue(
        preferences.getString(modeKey),
      );
    } catch (error, stackTrace) {
      debugPrint('Falha ao carregar modo de interface: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<double?> loadCrtIntensity() async {
    try {
      final preferences = await _instance();
      final value = preferences.getDouble(crtIntensityKey);
      return value?.clamp(0.0, 1.0);
    } catch (error, stackTrace) {
      debugPrint('Falha ao carregar intensidade CRT: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> saveMode(AppAppearanceMode mode) async {
    try {
      final preferences = await _instance();
      await preferences.setString(modeKey, mode.storageValue);
    } catch (error, stackTrace) {
      debugPrint('Falha ao salvar modo de interface: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> saveCrtIntensity(double intensity) async {
    try {
      final preferences = await _instance();
      await preferences.setDouble(crtIntensityKey, intensity.clamp(0.0, 1.0));
    } catch (error, stackTrace) {
      debugPrint('Falha ao salvar intensidade CRT: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
