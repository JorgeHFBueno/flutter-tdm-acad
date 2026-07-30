enum AppAppearanceMode {
  retro,
  standard,
}

extension AppAppearanceModeLabel on AppAppearanceMode {
  String get label {
    switch (this) {
      case AppAppearanceMode.retro:
        return 'Interface Retro';
      case AppAppearanceMode.standard:
        return 'Interface Standard';
    }
  }

  String get storageValue {
    switch (this) {
      case AppAppearanceMode.retro:
        return 'retro';
      case AppAppearanceMode.standard:
        return 'standard';
    }
  }

  static AppAppearanceMode? fromStorageValue(String? value) {
    switch (value) {
      case 'retro':
        return AppAppearanceMode.retro;
      case 'standard':
        return AppAppearanceMode.standard;
      default:
        return null;
    }
  }
}
