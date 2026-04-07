import 'package:baitul_mal_plus/core/theme_controller.dart';
import 'package:baitul_mal_plus/ui/core/widget/action_button.dart';
import 'package:baitul_mal_plus/ui/core/widget/appbar.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, toggleTheme),
      body: const Center(child: Text('Belum Ada Peserta')),
      floatingActionButton: ActionButton(),
    );
  }
}

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
    _themeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeController.isDark ? ThemeMode.dark : ThemeMode.light,

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

      home: HomeScreen(toggleTheme: _themeController.toggleTheme),
      themeAnimationDuration: const Duration(milliseconds: 300),
    );
  }
}
