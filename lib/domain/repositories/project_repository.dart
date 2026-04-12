import 'package:baitul_mal_plus/domain/models/project_model.dart';

/// Interface (kontrak) untuk semua operasi data project.
///
/// Dengan menggunakan abstract class ini:
/// - Presentation layer hanya bergantung pada kontrak ini, bukan implementasi.
/// - Mudah mengganti sumber data (SQLite → API → Hive) tanpa ubah UI.
/// - Mudah membuat mock untuk testing.
///
/// Cara menambah operasi baru:
/// 1. Deklarasikan method abstract di sini.
/// 2. Implementasikan di [ProjectRepositoryImpl].
abstract class ProjectRepository {
  /// Mengambil semua project dari sumber data.
  Future<List<ProjectModel>> getAll();

  /// Menyimpan project baru. Mengembalikan [id] yang di-generate database.
  Future<int> add(ProjectModel project);

  /// Mengupdate project yang sudah ada berdasarkan [id].
  Future<void> update(ProjectModel project);

  /// Menghapus project berdasarkan [id].
  Future<void> delete(int id);
}
