import 'package:baitul_mal_plus/data/source/local/database_helper.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/repositories/project_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Implementasi [ProjectRepository] menggunakan SQLite.
///
/// Jika suatu hari ingin ganti ke REST API, cukup buat
/// [ProjectRepositoryApiImpl] yang mengimplementasikan interface yang sama,
/// lalu ganti instansiasi di tempat yang perlu — tanpa menyentuh UI sama sekali.
class ProjectRepositoryImpl implements ProjectRepository {
  final DatabaseHelper _dbHelper;

  static const String _table = 'projects';

  ProjectRepositoryImpl({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<List<ProjectModel>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> rows = await db.query(
      _table,
      orderBy: 'id DESC', // Project terbaru tampil di atas
    );
    return rows.map(ProjectModel.fromMap).toList();
  }

  @override
  Future<int> add(ProjectModel project) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final projectToSave = project.copyWith(createdAt: now, updatedAt: now);
    return db.insert(
      _table,
      projectToSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(ProjectModel project) async {
    assert(project.id != null, 'Project harus memiliki id untuk di-update');
    final db = await _dbHelper.database;
    final projectToUpdate = project.copyWith(updatedAt: DateTime.now());

    await db.update(
      _table,
      projectToUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
