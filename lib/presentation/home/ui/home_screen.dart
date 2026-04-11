import 'package:baitul_mal_plus/core/theme_controller.dart';
import 'package:baitul_mal_plus/data/source/local/database_helper.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/presentation/core/widget/action_button.dart';
import 'package:baitul_mal_plus/presentation/core/widget/appbar.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ProjectModel>> _projects;

  @override
  void initState() {
    super.initState();
    _projects = _getProjectList();
  }

  void refreshProjects() {
    setState(() {
      _projects = _getProjectList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, widget.toggleTheme),
      body: FutureBuilder<List<ProjectModel>>(
        future: _projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada Project'));
          }

          final projects = snapshot.data!;

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];

              return ListTile(title: Text(project.name));
            },
          );
        },
      ),
      floatingActionButton: ActionButton(onProjectAdded: refreshProjects),
    );
  }
}

Future<List<ProjectModel>> _getProjectList() async {
  return await DatabaseHelper().getProjects();
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
        colorSchemeSeed: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),

      home: HomeScreen(toggleTheme: _themeController.toggleTheme),
      themeAnimationDuration: const Duration(milliseconds: 300),
    );
  }
}
