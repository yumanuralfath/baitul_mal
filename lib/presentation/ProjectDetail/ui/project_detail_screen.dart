// lib/presentation/project_detail/screens/project_detail_screen.dart

import 'package:baitul_mal_plus/presentation/ProjectDetail/ui/member_list_page.dart';
import 'package:baitul_mal_plus/presentation/ProjectDetail/ui/overall_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/appbar.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback toggleTheme;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.toggleTheme,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(
        context,
        toggleTheme: widget.toggleTheme,
        title: widget.project.name,
      ),
      body: IndexedStack(
        index: _pageIndex,
        children: [
          MemberListPage(project: widget.project),
          OverallSummaryPage(project: widget.project),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pageIndex,
        onDestinationSelected: (i) => setState(() => _pageIndex = i),
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.people),
            icon: Icon(Icons.people_outline),
            label: 'Member',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.pie_chart),
            icon: Icon(Icons.pie_chart_outline),
            label: 'Keseluruhan',
          ),
        ],
      ),
    );
  }
}
