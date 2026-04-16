import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Mengelola koneksi dan skema database SQLite.
///
/// Kelas ini hanya bertanggung jawab atas:
/// - Inisialisasi dan pembukaan database
/// - Pembuatan tabel (schema migration)
/// - Menyediakan instance [Database] untuk digunakan repository
///
/// Logika bisnis (insert, query, delete) ada di [ProjectRepositoryImpl].
class DatabaseHelper {
  // Singleton — hanya ada satu instance di seluruh aplikasi
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String _dbName = 'baitul_mal.db';
  static const int _dbVersion = 2;

  /// Mengembalikan instance database (membuat baru jika belum ada).
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Dipanggil pertama kali saat database dibuat.
  Future<void> _onCreate(Database db, int version) async {
    final sql = await _sqlLoader("assets/sql/schema.sql");
    await _executeSqlBatch(db, sql);
  }

  /// Dipanggil saat versi database dinaikkan.
  /// Gunakan ini untuk migrasi skema tanpa kehilangan data.
  /// SQLite best practice for update:
  ///   - Buat tabel baru dengan schema baru
  ///   - Copy data
  ///   - Drop tabel lama
  ///   - Rename
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int i = oldVersion; i < newVersion; i++) {
      final migrationFile = 'assets/sql/migrate/${i}_to_${i + 1}.sql';

      try {
        Logger().i('try migration from v$i to v${i + 1}');
        final sql = await _sqlLoader(migrationFile);
        await _executeSqlBatch(db, sql);
      } catch (e) {
        Logger().e('Migration file not found: $migrationFile');
        rethrow;
      }
    }
  }
}

/// sql loader with location
Future<String> _sqlLoader(String sqlLocation) async {
  return await rootBundle.loadString(sqlLocation);
}

/// execute sql with trimmed
Future<void> _executeSqlBatch(Database db, String sql) async {
  final statements = sql.split(';');

  await db.transaction((txn) async {
    for (var statement in statements) {
      final trimmed = statement.trim();
      if (trimmed.isNotEmpty) {
        await txn.execute(trimmed);
      }
    }
  });
}
