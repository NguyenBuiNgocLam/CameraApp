import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'routes.dart';
import 'theme.dart';

class AIEnglishVocabularyApp extends StatelessWidget {
  const AIEnglishVocabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return ThemeController(
      themeMode: themeProvider.themeMode,
      setDarkMode: themeProvider.setDarkMode,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AI Vocabulary Camera',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeProvider.themeMode,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}

class ThemeController extends InheritedWidget {
  const ThemeController({
    required this.themeMode,
    required this.setDarkMode,
    required super.child,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<bool> setDarkMode;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  static ThemeController of(BuildContext context) {
    final controller =
        context.dependOnInheritedWidgetOfExactType<ThemeController>();
    assert(controller != null, 'ThemeController not found in context');
    return controller!;
  }

  @override
  bool updateShouldNotify(ThemeController oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}
