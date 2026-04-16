import 'package:baitul_mal_plus/domain/repositories/project_repository.dart';
import 'package:baitul_mal_plus/presentation/home/widgets/add_project_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Floating action button untuk menambah project baru.
///
/// Widget ini hanya bertanggung jawab menampilkan tombol dan membuka
/// bottom sheet. Logika simpan ada di [showAddProjectSheet].
class AddProjectButton extends StatelessWidget {
  final ProjectRepository repository;
  final VoidCallback onProjectAdded;

  const AddProjectButton({
    super.key,
    required this.repository,
    required this.onProjectAdded,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => showAddProjectSheet(
        context,
        repository: repository,
        onSuccess: onProjectAdded,
      ),
      icon: const Icon(Icons.add),
      label: const Text('Tambah Project'),
    );
  }
}
