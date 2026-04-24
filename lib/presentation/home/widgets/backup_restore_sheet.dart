import 'dart:io';

import 'package:baitul_mal_plus/core/restart_widget.dart';
import 'package:baitul_mal_plus/data/services/export_service.dart';
import 'package:baitul_mal_plus/data/services/import_service.dart';
import 'package:flutter/material.dart';

class BackupRestoreSheet extends StatefulWidget {
  final VoidCallback? onImportSuccess;

  const BackupRestoreSheet({super.key, this.onImportSuccess});

  @override
  State<BackupRestoreSheet> createState() => _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends State<BackupRestoreSheet> {
  bool _loading = false;
  String? _loadingLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.storage_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Backup & Restore',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _loadingLabel ?? 'Memproses...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          if (!_loading) ...[
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.backup_outlined, color: cs.primary, size: 22),
              ),
              title: const Text(
                'Backup SQL (Semua data)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text('Backup seluruh database (projects, members, transaksi)'),
              onTap: _backupAll,
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restore, color: Colors.orange, size: 22),
              ),
              title: const Text(
                'Restore dari SQL',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text('Import file .sql hasil backup'),
              onTap: _restore,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _backupAll() async {
    setState(() {
      _loading = true;
      _loadingLabel = 'Membuat backup...';
    });

    try {
      final File file = await ExportService.exportSql();
      if (mounted) Navigator.pop(context);
      await ExportService.shareFile(context, file, subject: 'Backup Semua Data.sql');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal backup: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 40,
        ),
        title: const Text('Restore Data?'),
        content: const Text(
          'Data dari file SQL akan digabungkan ke database yang ada.\n\n'
          'Backup otomatis akan dibuat sebelum import.\n\n'
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
      _loadingLabel = 'Membuat backup otomatis...';
    });

    try {
      await ImportService.autoBackup();
      if (mounted) setState(() => _loadingLabel = 'Mengimpor data...');

      final result = await ImportService.importFromSql();
      if (mounted) Navigator.pop(context);

      if (result.cancelled) return;

      if (result.success) {
        widget.onImportSuccess?.call();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Restore berhasil! ${result.imported} statement dijalankan.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Soft restart agar semua screen reload data dari DB
        if (context.mounted) {
          RestartWidget.restartApp(context);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Restore gagal'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

