import 'package:baitul_mal_plus/data/repositories/project_repository_impl.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/repositories/project_repository.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/appbar.dart';
import 'package:baitul_mal_plus/presentation/home/widgets/action_button.dart';
import 'package:baitul_mal_plus/presentation/home/widgets/project_list_item.dart';
import 'package:flutter/material.dart';

/// Halaman utama yang menampilkan daftar project tabungan.
///
/// Screen ini tidak tahu tentang database — semua operasi data
/// dilakukan melalui [ProjectRepository].
class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Gunakan interface, bukan implementasi langsung.
  // Ini memudahkan testing dan penggantian data source di masa depan.
  final ProjectRepository _repository = ProjectRepositoryImpl();

  late Future<List<ProjectModel>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    setState(() {
      _projectsFuture = _repository.getAll();
    });
  }

  Future<void> _deleteProject(int id) async {
    try {
      await _repository.delete(id);
      _loadProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus project: $e')));
      }
    }
  }

  Future<void> _renameProject(ProjectModel project, String newName) async {
    try {
      final updatedProject = project.copyWith(name: newName);

      await _repository.update(updatedProject);
      _loadProjects(); //refresh ui
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project berhasil di-rename')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal rename project: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, toggleTheme: widget.toggleTheme),
      body: FutureBuilder<List<ProjectModel>>(
        future: _projectsFuture,
        builder: _buildBody,
      ),
      floatingActionButton: AddProjectButton(
        repository: _repository,
        onProjectAdded: _loadProjects,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<ProjectModel>> snapshot,
  ) {
    // Loading
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (snapshot.hasError) {
      return _ErrorView(
        message: snapshot.error.toString(),
        onRetry: _loadProjects,
      );
    }

    // Kosong
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const _EmptyView();
    }

    // Daftar project
    final projects = snapshot.data!;
    return RefreshIndicator(
      onRefresh: () async => _loadProjects(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          return ProjectListItem(
            project: project,
            onRename: (String newName) {
              if (project.id != null) {
                _renameProject(project, newName);
              }
            },
            onDelete: project.id != null
                ? () => _deleteProject(project.id!)
                : null,
          );
        },
      ),
    );
  }
}

// ── Widget bantu (private, hanya dipakai HomeScreen) ──────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada project',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol + untuk menambahkan project baru',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Terjadi kesalahan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
