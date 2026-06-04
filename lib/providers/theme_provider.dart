import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider();

  static const _darkModeKey = 'dark_mode';

  ThemeMode themeMode = ThemeMode.light;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final isDark = preferences.getBool(_darkModeKey) ?? false;
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    themeMode = value ? ThemeMode.dark : ThemeMode.light;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, value);
    notifyListeners();
  }
}
