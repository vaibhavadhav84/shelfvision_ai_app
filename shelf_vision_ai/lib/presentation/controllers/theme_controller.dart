import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Manages and persists the application's [ThemeMode].
/// Defaults to [ThemeMode.light] and saves the user's preference to local disk.
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  /// Returns whether dark theme is currently active.
  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Loads saved theme preference from local storage.
  /// If none is saved, defaults to [ThemeMode.light].
  Future<void> loadTheme() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_mode.txt');
      if (await file.exists()) {
        final content = (await file.readAsString()).trim().toLowerCase();
        if (content == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (content == 'system') {
          _themeMode = ThemeMode.system;
        } else {
          _themeMode = ThemeMode.light;
        }
        notifyListeners();
      }
    } catch (_) {
      // Retain default light mode on error.
      _themeMode = ThemeMode.light;
    }
  }

  /// Sets and persists a new [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveTheme();
  }

  /// Toggles between light and dark modes and saves the choice.
  Future<void> toggleTheme(BuildContext context) async {
    final currentIsDark = isDark(context);
    final nextMode = currentIsDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  Future<void> _saveTheme() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_mode.txt');
      final value = _themeMode == ThemeMode.dark
          ? 'dark'
          : (_themeMode == ThemeMode.system ? 'system' : 'light');
      await file.writeAsString(value);
    } catch (_) {
      // Disk write failure silently ignored in transient sandbox.
    }
  }
}
