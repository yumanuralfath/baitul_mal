import 'package:baitul_mal_plus/core/helper/format_date_helper.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:flutter/material.dart';

/// type def to update rename project
typedef RenameCallback = void Function(String newName);

/// Widget yang menampilkan satu item project dalam daftar.
///
/// Dipisah dari [HomeScreen] agar mudah diubah tampilannya
/// tanpa menyentuh logika screen.
class ProjectListItem extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final RenameCallback? onRename;

  const ProjectListItem({
    super.key,
    required this.project,
    this.onTap,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: ListTile(
        leading: Icon(Icons.folder),
        title: Text(project.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDate(project.createdAt!),
              style: TextStyle(fontSize: 12),
            ),
            Text(
              timeAgo(project.updatedAt!),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        onTap: onTap,
        onLongPress: () => _showActionMenu(context),
      ),
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename Project'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRename(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Colors.red),
                title: const Text(
                  'Delete project',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Menampilkan dialog Rename
  void _confirmRename(BuildContext context) {
    final controller = TextEditingController(text: project.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Project?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Rename project',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),

          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              Navigator.pop(ctx);
              onRename?.call(newName);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Confirm'),
          ),
        ],
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
