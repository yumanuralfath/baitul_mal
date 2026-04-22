// ─── IMPLEMENTATION ───────────────────────────────────────────
// lib/data/repositories/member_repository_impl.dart

import 'package:baitul_mal_plus/data/source/local/database_helper.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/models/project_cashflow_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';

class MemberRepositoryImpl implements MemberRepository {
  final DatabaseHelper _db = DatabaseHelper();

  @override
  Future<List<MemberModel>> getMembersByProject(int projectId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT m.*,
        COALESCE(vs.net_savings, 0) AS net_savings,
        COALESCE(vl.sisa_hutang, 0) AS sisa_hutang
      FROM members m
      LEFT JOIN v_member_savings vs ON vs.member_id = m.id
      LEFT JOIN v_member_loans   vl ON vl.member_id = m.id
      WHERE m.project_id = ? AND m.is_active = 1
      ORDER BY m.name ASC
    ''',
      [projectId],
    );
    return rows.map(MemberModel.fromMap).toList();
  }

  @override
  Future<MemberModel> addMember(MemberModel member) async {
    final db = await _db.database;
    final id = await db.insert('members', member.toMap());
    return member.copyWith(id: id);
  }

  @override
  Future<void> updateMember(MemberModel member) async {
    final db = await _db.database;
    await db.update(
      'members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  @override
  Future<void> deleteMember(int id) async {
    final db = await _db.database;
    await db.update(
      'members',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<SavingModel>> getSavingsByMember(int memberId) async {
    final db = await _db.database;
    final rows = await db.query(
      'savings',
      where: 'member_id = ?',
      whereArgs: [memberId],
      orderBy: 'transaction_date DESC',
    );
    return rows.map(SavingModel.fromMap).toList();
  }

  @override
  Future<void> addSaving(SavingModel saving) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('savings', saving.toMap());
      if (saving.type == 'deposit') {
        final loans = await txn.query(
          'loans',
          where: 'member_id = ? AND status = ?',
          whereArgs: [saving.memberId, 'active'],
          orderBy: 'loan_date ASC',
        );
        double remaining = saving.amount;
        for (final loanMap in loans) {
          if (remaining <= 0) break;
          final loanId = loanMap['id'] as int;
          final total = (loanMap['total_amount'] as num).toDouble();
          final paid = (loanMap['paid_amount'] as num? ?? 0).toDouble();
          final unpaid = total - paid;
          if (unpaid <= 0) continue;
          final payment = remaining >= unpaid ? unpaid : remaining;
          remaining -= payment;
          await txn.insert('loan_payments', {
            'loan_id': loanId,
            'amount': payment,
            'note': 'Auto-potong dari tabungan',
            'payment_date': saving.transactionDate.toIso8601String(),
          });
        }
      }
    });
  }

  @override
  Future<void> updateSaving(SavingModel saving) async {
    final db = await _db.database;
    await db.update(
      'savings',
      saving.toMap(),
      where: 'id = ?',
      whereArgs: [saving.id],
    );
  }

  @override
  Future<void> deleteSaving(int id) async {
    final db = await _db.database;
    await db.delete('savings', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<LoanModel>> getLoansByMember(int memberId) async {
    final db = await _db.database;
    final rows = await db.query(
      'loans',
      where: 'member_id = ?',
      whereArgs: [memberId],
      orderBy: 'loan_date DESC',
    );
    return rows.map(LoanModel.fromMap).toList();
  }

  @override
  Future<List<LoanModel>> getActiveLoansByProject(int projectId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT l.*, m.name AS member_name
      FROM loans l JOIN members m ON m.id = l.member_id
      WHERE l.project_id = ? AND l.status != 'paid'
      ORDER BY l.loan_date DESC
    ''',
      [projectId],
    );
    return rows.map(LoanModel.fromMap).toList();
  }

  @override
  Future<void> addLoan(LoanModel loan) async {
    final db = await _db.database;
    await db.insert('loans', loan.toMap());
  }

  @override
  Future<void> updateLoan(LoanModel loan) async {
    final db = await _db.database;
    await db.update(
      'loans',
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  @override
  Future<void> deleteLoan(int id) async {
    final db = await _db.database;
    await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<ProjectCashflowModel?> getProjectCashflow(int projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'v_project_cashflow',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    if (rows.isEmpty) return null;
    return ProjectCashflowModel.fromMap(rows.first);
  }
}

