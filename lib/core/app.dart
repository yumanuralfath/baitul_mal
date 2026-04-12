import 'package:baitul_mal_plus/core/routes/app_routes.dart';
import 'package:baitul_mal_plus/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';

/// Root widget aplikasi.
/// Bertanggung jawab atas:
/// - Konfigurasi tema (light/dark)
/// - Konfigurasi routing
class BaitulMalApp extends StatefulWidget {
  const BaitulMalApp({super.key});

  @override
  State<BaitulMalApp> createState() => _BaitulMalAppState();
}

class _BaitulMalAppState extends State<BaitulMalApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    // Rebuild widget saat tema berubah
    _themeController.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baitul Mal Plus',

      // ── Tema ──────────────────────────────────────────────
      themeMode: _themeController.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeAnimationDuration: const Duration(milliseconds: 300),

      // ── Routing ───────────────────────────────────────────
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute(
        toggleTheme: _themeController.toggleTheme,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.greenAccent,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blueGrey,
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}
