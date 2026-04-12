import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mengelola state tema aplikasi (light / dark).
///
/// Tema disimpan secara persisten menggunakan [SharedPreferences],
/// sehingga pilihan pengguna tetap tersimpan setelah aplikasi ditutup.
class ThemeController extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  static const String _prefKey = 'isDarkMode';

  ThemeController() {
    _loadSavedTheme();
  }

  /// Membaca preferensi tema yang tersimpan saat controller dibuat.
  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_prefKey) ?? false;
    notifyListeners();
  }

  /// Membalik tema antara light dan dark, lalu menyimpannya.
  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners(); // Update UI lebih dulu agar terasa responsif

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isDark);
  }
}
