import 'package:flutter/material.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  VoidCallback toggleTheme,
) {
  return AppBar(
    title: const Text(
      'Tabungan Musholla',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    centerTitle: false,
    scrolledUnderElevation: 2,
    actions: [
      buildThemeToggleButton(context, toggleTheme),
      const SizedBox(width: 8),
    ],
  );
}

Widget buildThemeToggleButton(BuildContext context, VoidCallback toggleTheme) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    transitionBuilder: (child, anim) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: anim, child: child),
    ),
    child: IconButton(
      // Key sangat penting agar AnimatedSwitcher tahu widget berubah
      key: ValueKey(isDark),
      onPressed: toggleTheme,
      icon: Icon(
        isDark ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
        color: isDark ? Colors.orangeAccent : Colors.blueGrey,
      ),
    ),
  );
}
