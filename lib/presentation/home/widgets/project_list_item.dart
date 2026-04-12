import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:flutter/material.dart';

/// Widget yang menampilkan satu item project dalam daftar.
///
/// Dipisah dari [HomeScreen] agar mudah diubah tampilannya
/// tanpa menyentuh logika screen.
class ProjectListItem extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ProjectListItem({
    super.key,
    required this.project,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            project.name.isNotEmpty ? project.name[0].toUpperCase() : '?',
          ),
        ),
        title: Text(project.name),
        subtitle: project.id != null ? Text('ID: ${project.id}') : null,
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Theme.of(context).colorScheme.error,
                tooltip: 'Hapus project',
                onPressed: () => _confirmDelete(context),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  /// Menampilkan dialog konfirmasi sebelum menghapus.
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Project?'),
        content: Text('Project "${project.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
