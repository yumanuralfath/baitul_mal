class LoanModel {
  final int? id;
  final int projectId;
  final int memberId;
  final double amount;
  final double interestRate;
  final double totalAmount;
  final double paidAmount;
  final String status; // 'active' | 'paid' | 'overdue'
  final DateTime? dueDate;
  final String? note;
  final DateTime loanDate;
  final DateTime? createdAt;

  // Join field
  final String? memberName;

  const LoanModel({
    this.id,
    required this.projectId,
    required this.memberId,
    required this.amount,
    this.interestRate = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    this.status = 'active',
    this.dueDate,
    this.note,
    required this.loanDate,
    this.createdAt,
    this.memberName,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => paidAmount >= totalAmount;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_id': projectId,
      'member_id': memberId,
      'amount': amount,
      'interest_rate': interestRate,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
      'note': note,
      'loan_date': loanDate.toIso8601String(),
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      memberId: map['member_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num? ?? 0).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num? ?? 0).toDouble(),
      status: map['status'] as String? ?? 'active',
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      note: map['note'] as String?,
      loanDate: DateTime.parse(map['loan_date'] as String),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      memberName: map['member_name'] as String?,
    );
  }
}
