import 'package:baitul_mal_plus/presentation/home/ui/home_screen.dart';
import 'package:flutter/material.dart';

/// Kelas yang menyimpan semua nama route dan logika navigasi.
///
/// Cara menambah route baru:
/// 1. Tambahkan konstanta nama route di bawah.
/// 2. Tambahkan case baru di dalam [onGenerateRoute].
class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  // ── Nama Route ────────────────────────────────────────────
  static const String home = '/';
  // Tambahkan route baru di sini, contoh:
  // static const String projectDetail = '/project/detail';
  // static const String settings = '/settings';

  // ── Route Generator ───────────────────────────────────────
  /// Mengembalikan [RouteFactory] yang digunakan oleh [MaterialApp.onGenerateRoute].
  ///
  /// Parameter seperti [toggleTheme] di-pass lewat sini agar
  /// screen tidak perlu bergantung langsung ke ThemeController.
  static RouteFactory onGenerateRoute({required VoidCallback toggleTheme}) {
    return (RouteSettings settings) {
      switch (settings.name) {
        case AppRoutes.home:
          return MaterialPageRoute(
            builder: (_) => HomeScreen(toggleTheme: toggleTheme),
          );

        // Contoh route dengan argument:
        // case AppRoutes.projectDetail:
        //   final args = settings.arguments as ProjectDetailArgs;
        //   return MaterialPageRoute(
        //     builder: (_) => ProjectDetailScreen(project: args.project),
        //   );

        default:
          // Fallback jika route tidak ditemukan
          return MaterialPageRoute(
            builder: (_) => const _RouteNotFoundScreen(),
          );
      }
    };
  }
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Halaman tidak ditemukan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (_) => false,
              ),
              child: const Text('Kembali ke beranda'),
            ),
          ],
        ),
      ),
    );
  }
}
