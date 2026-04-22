import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:flutter/material.dart';

class ProjectDetailScreen extends StatelessWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(project.name)));
  }
}
