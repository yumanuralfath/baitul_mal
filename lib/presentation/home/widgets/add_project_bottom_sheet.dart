import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/repositories/project_repository.dart';
import 'package:flutter/material.dart';

/// Menampilkan bottom sheet untuk menambahkan project baru.
///
/// [repository] digunakan untuk menyimpan data — widget ini tidak
/// bergantung langsung ke database, hanya ke interface [ProjectRepository].
///
/// [onSuccess] dipanggil setelah project berhasil disimpan,
/// biasanya untuk me-refresh daftar di screen pemanggil.
Future<void> showAddProjectSheet(
  BuildContext context, {
  required ProjectRepository repository,
  required VoidCallback onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Agar konten naik saat keyboard muncul
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _AddProjectSheetContent(repository: repository, onSuccess: onSuccess),
  );
}

class _AddProjectSheetContent extends StatefulWidget {
  final ProjectRepository repository;
  final VoidCallback onSuccess;

  const _AddProjectSheetContent({
    required this.repository,
    required this.onSuccess,
  });

  @override
  State<_AddProjectSheetContent> createState() =>
      _AddProjectSheetContentState();
}

class _AddProjectSheetContentState extends State<_AddProjectSheetContent> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      await widget.repository.add(
        ProjectModel(name: _nameController.text.trim()),
      );
      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan project: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding bawah mengikuti tinggi keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Project Baru',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nama Project',
                    hintText: 'Contoh: Tabungan Tahun 2026',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama project tidak boleh kosong';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _confirmCreateProject(context),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _confirmCreateProject(context),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Project'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Menampilkan dialog konfirmasi sebelum menyimpan project.
  void _confirmCreateProject(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan Project?'),
        content: Text('Project "${_nameController.text}" akan disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _save();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
