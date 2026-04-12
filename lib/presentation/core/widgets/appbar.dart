import 'package:flutter/material.dart';

/// Membuat [AppBar] standar untuk seluruh aplikasi.
///
/// [toggleTheme] di-pass sebagai callback agar widget ini tidak
/// bergantung langsung ke [ThemeController].
PreferredSizeWidget buildAppBar(
  BuildContext context, {
  required VoidCallback toggleTheme,
  String title = 'Tabungan Musholla',
}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    centerTitle: false,
    scrolledUnderElevation: 2,
    actions: [
      _ThemeToggleButton(onToggle: toggleTheme),
      const SizedBox(width: 8),
    ],
  );
}

/// Tombol toggle tema dengan animasi fade + scale.
class _ThemeToggleButton extends StatelessWidget {
  final VoidCallback onToggle;

  const _ThemeToggleButton({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: IconButton(
        // ValueKey penting agar AnimatedSwitcher tahu widget berubah
        key: ValueKey(isDark),
        onPressed: onToggle,
        tooltip: isDark ? 'Ganti ke mode terang' : 'Ganti ke mode gelap',
        icon: Icon(
          isDark ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
          color: isDark ? Colors.orangeAccent : Colors.blueGrey,
        ),
      ),
    );
  }
}
