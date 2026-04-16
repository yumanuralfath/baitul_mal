/// Model yang merepresentasikan satu project tabungan.
///
/// [id] bersifat nullable karena di-generate otomatis oleh database.
/// Saat membuat project baru, cukup isi [name] saja.
class ProjectModel {
  final int? id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectModel({
    this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  ProjectModel copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProjectModel('
        'id: $id, '
        'name: $name, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }
}
