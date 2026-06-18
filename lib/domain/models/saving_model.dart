class SavingModel {
  final int? id;
  final int projectId;
  final int memberId;
  final double amount;
  final String type; // 'deposit' | 'withdrawal'
  final String? note;
  final DateTime transactionDate;
  final DateTime? createdAt;

  // Join field
  final String? memberName;

  const SavingModel({
    this.id,
    required this.projectId,
    required this.memberId,
    required this.amount,
    required this.type,
    this.note,
    required this.transactionDate,
    this.createdAt,
    this.memberName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_id': projectId,
      'member_id': memberId,
      'amount': amount,
      'type': type,
      'note': note,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }

  factory SavingModel.fromMap(Map<String, dynamic> map) {
    return SavingModel(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      memberId: map['member_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      note: map['note'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      memberName: map['member_name'] as String?,
    );
  }
}
