/// Model yang merepresentasikan satu project tabungan.
///
/// [id] bersifat nullable karena di-generate otomatis oleh database.
/// Saat membuat project baru, cukup isi [name] saja.
class ProjectModel {
  final int? id;
  final String name;

  const ProjectModel({
    this.id,
    required this.name,
  });

  /// Konversi object ke Map untuk disimpan ke database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id, // Jangan kirim id jika null (auto-increment)
      'name': name,
    };
  }

  /// Konversi Map dari database menjadi object [ProjectModel].
  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  /// Membuat salinan object dengan nilai yang diubah.
  ProjectModel copyWith({int? id, String? name}) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'ProjectModel(id: $id, name: $name)';
}
