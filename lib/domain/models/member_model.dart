class MemberModel {
  final int? id;
  final int projectId;
  final String name;
  final String? phone;
  final String? note;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Summary fields (from VIEW, not stored)
  final double? netSavings;
  final double? sisaHutang;

  const MemberModel({
    this.id,
    required this.projectId,
    required this.name,
    this.phone,
    this.note,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.netSavings,
    this.sisaHutang,
  });

  /// Saldo efektif = tabungan bersih - sisa hutang
  double get effectiveBalance => (netSavings ?? 0) - (sisaHutang ?? 0);

  MemberModel copyWith({
    int? id,
    int? projectId,
    String? name,
    String? phone,
    String? note,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? netSavings,
    double? sisaHutang,
  }) {
    return MemberModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      netSavings: netSavings ?? this.netSavings,
      sisaHutang: sisaHutang ?? this.sisaHutang,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_id': projectId,
      'name': name,
      'phone': phone,
      'note': note,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      note: map['note'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      netSavings: (map['net_savings'] as num?)?.toDouble(),
      sisaHutang: (map['sisa_hutang'] as num?)?.toDouble(),
    );
  }
}
