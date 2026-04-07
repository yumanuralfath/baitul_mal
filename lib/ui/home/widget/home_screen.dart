import 'package:baitul_mal_plus/ui/core/ui/appbar.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, toggleTheme),
      body: Center(child: Text('Hello World')),
    );
  }
}

class BaitulMalApp extends StatefulWidget {
  const BaitulMalApp({super.key});

  @override
  State<BaitulMalApp> createState() => _BaitulMalAppState();
}

class _BaitulMalAppState extends State<BaitulMalApp> {
  bool isDark = false;

  void toggleTheme() {
    setState(() {
      isDark = !isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.greenAccent,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
      ),

      home: HomeScreen(toggleTheme: toggleTheme),
      themeAnimationDuration: const Duration(milliseconds: 300),
    );
  }
}
