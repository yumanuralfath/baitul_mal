import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
  static const int _dbVersion = 1;

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
    await db.execute('''
      CREATE TABLE projects (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT    NOT NULL
      )
    ''');
    // Tambahkan CREATE TABLE lain di sini jika perlu
  }

  /// Dipanggil saat versi database dinaikkan.
  /// Gunakan ini untuk migrasi skema tanpa kehilangan data.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Contoh migrasi:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE projects ADD COLUMN description TEXT');
    // }
  }
}
