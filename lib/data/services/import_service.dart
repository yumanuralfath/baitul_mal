// lib/data/services/import_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ═══════════════════════════════════════════════════════════════
// IMPORT SERVICE
// ═══════════════════════════════════════════════════════════════
class ImportService {
  /// Import dari file SQL (hasil export backup)
  static Future<ImportResult> importFromSql() async {
    // Buka file picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sql', 'txt'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.cancelled();
    }

    final file = File(result.files.single.path!);
    if (!await file.exists()) {
      return ImportResult.error('File tidak ditemukan');
    }

    final content = await file.readAsString();
    return await _executeSqlImport(content);
  }

  /// Backup otomatis sebelum import (keamanan data)
  static Future<File> autoBackup() async {
    final dbPath = p.join(await getDatabasesPath(), 'baitul_mal.db');
    final dir = await getApplicationDocumentsDirectory();
    final backupPath = p.join(
      dir.path,
      'auto_backup_before_import_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    return File(dbPath).copy(backupPath);
  }

  static Future<ImportResult> _executeSqlImport(String sql) async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'baitul_mal.db'),
    );

    try {
      // Split statements dengan aman (handle BEGIN...END trigger)
      final statements = _splitSqlStatements(sql);

      int imported = 0;
      int skipped = 0;

      await db.transaction((txn) async {
        for (final stmt in statements) {
          final trimmed = stmt.trim();
          if (trimmed.isEmpty) continue;
          // Skip komentar
          if (trimmed.startsWith('--')) continue;

          try {
            await txn.execute(trimmed);
            imported++;
          } catch (e) {
            // Skip duplikat (INSERT OR IGNORE friendly)
            skipped++;
          }
        }
      });

      return ImportResult.success(imported: imported, skipped: skipped);
    } catch (e) {
      return ImportResult.error('Gagal import: $e');
    } finally {
      await db.close();
    }
  }

  static List<String> _splitSqlStatements(String sql) {
    // Hapus komentar -- per baris
    final cleaned = sql
        .split('\n')
        .map((line) {
          final idx = line.indexOf('--');
          return idx >= 0 ? line.substring(0, idx) : line;
        })
        .join('\n');

    final statements = <String>[];
    final buffer = StringBuffer();
    bool insideBeginEnd = false;

    for (int i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      buffer.write(char);

      if (char == ';') {
        final current = buffer.toString().trim().toUpperCase();
        if (!insideBeginEnd && current.contains(RegExp(r'\bBEGIN\b'))) {
          insideBeginEnd = true;
        } else if (insideBeginEnd && current.endsWith('END;')) {
          insideBeginEnd = false;
          statements.add(buffer.toString().trim());
          buffer.clear();
        } else if (!insideBeginEnd) {
          statements.add(buffer.toString().trim());
          buffer.clear();
        }
      }
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) statements.add(remaining);
    return statements;
  }
}

// ─── Import Result ─────────────────────────────────────────────
class ImportResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final int imported;
  final int skipped;

  const ImportResult._({
    required this.success,
    required this.cancelled,
    this.error,
    this.imported = 0,
    this.skipped = 0,
  });

  factory ImportResult.success({required int imported, required int skipped}) =>
      ImportResult._(
        success: true,
        cancelled: false,
        imported: imported,
        skipped: skipped,
      );

  factory ImportResult.error(String msg) =>
      ImportResult._(success: false, cancelled: false, error: msg);

  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);
}
