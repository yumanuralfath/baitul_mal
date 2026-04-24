// ─── IMPLEMENTATION ───────────────────────────────────────────
// lib/data/repositories/member_repository_impl.dart

import 'package:baitul_mal_plus/data/source/local/database_helper.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/models/project_cashflow_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:sqflite/sqlite_api.dart' show DatabaseExecutor;

class MemberRepositoryImpl implements MemberRepository {
  final DatabaseHelper _db = DatabaseHelper();

  @override
  Future<List<MemberModel>> getMembersByProject(int projectId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT m.*,
        COALESCE(vs.net_savings, 0) - COALESCE(ap.auto_potong, 0) AS net_savings,
        COALESCE(vl.sisa_hutang, 0) AS sisa_hutang
      FROM members m
      LEFT JOIN v_member_savings vs ON vs.member_id = m.id
      LEFT JOIN v_member_loans   vl ON vl.member_id = m.id
      LEFT JOIN (
        SELECT
          l.member_id,
          COALESCE(SUM(lp.amount), 0) AS auto_potong
        FROM loan_payments lp
        JOIN loans l ON l.id = lp.loan_id
        WHERE lp.note LIKE 'Auto-potong dari tabungan%'
        GROUP BY l.member_id
      ) ap ON ap.member_id = m.id
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
      await _syncAutoPaymentFromSavings(txn, saving.memberId);
    });
  }

  @override
  Future<void> updateSaving(SavingModel saving) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final oldRows = await txn.query(
        'savings',
        columns: ['member_id'],
        where: 'id = ?',
        whereArgs: [saving.id],
        limit: 1,
      );
      final oldMemberId = oldRows.isNotEmpty
          ? (oldRows.first['member_id'] as int)
          : saving.memberId;

      await txn.update(
        'savings',
        saving.toMap(),
        where: 'id = ?',
        whereArgs: [saving.id],
      );

      await _syncAutoPaymentFromSavings(txn, oldMemberId);
      if (oldMemberId != saving.memberId) {
        await _syncAutoPaymentFromSavings(txn, saving.memberId);
      }
    });
  }

  @override
  Future<void> deleteSaving(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'savings',
        columns: ['member_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final memberId = rows.first['member_id'] as int;

      await txn.delete('savings', where: 'id = ?', whereArgs: [id]);
      await _syncAutoPaymentFromSavings(txn, memberId);
    });
  }

  @override
  Future<List<LoanModel>> getLoansByMember(int memberId) async {
    final db = await _db.database;
    // Sinkronisasi auto-potong agar pinjaman lama juga terbayar dari tabungan yang sudah ada.
    await _syncAutoPaymentFromSavings(db, memberId);
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
    await db.transaction((txn) async {
      await txn.insert('loans', loan.toMap());
      await _syncAutoPaymentFromSavings(txn, loan.memberId);
    });
  }

  @override
  Future<void> updateLoan(LoanModel loan) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final oldRows = await txn.query(
        'loans',
        columns: ['member_id'],
        where: 'id = ?',
        whereArgs: [loan.id],
        limit: 1,
      );
      final oldMemberId = oldRows.isNotEmpty
          ? (oldRows.first['member_id'] as int)
          : loan.memberId;

      await txn.update(
        'loans',
        loan.toMap(),
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      await _syncAutoPaymentFromSavings(txn, oldMemberId);
      if (oldMemberId != loan.memberId) {
        await _syncAutoPaymentFromSavings(txn, loan.memberId);
      }
    });
  }

  @override
  Future<void> deleteLoan(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'loans',
        columns: ['member_id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final memberId = rows.first['member_id'] as int;

      await txn.delete('loans', where: 'id = ?', whereArgs: [id]);
      await _syncAutoPaymentFromSavings(txn, memberId);
    });
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

  @override
  Future<ProjectCashflowModel?> getProjectCashflowByDate(
    int projectId,
    DateTime date,
  ) async {
    final db = await _db.database;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      0,
      0,
      0,
    ).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT
        p.id   AS project_id,
        p.name AS project_name,
 
        -- Kumulatif s/d tanggal
        COALESCE((SELECT SUM(s.amount) FROM savings s
          WHERE s.project_id = p.id AND s.type = 'deposit'
          AND s.transaction_date <= ?1), 0) AS total_setoran,
 
        COALESCE((SELECT SUM(s.amount) FROM savings s
          WHERE s.project_id = p.id AND s.type = 'withdrawal'
          AND s.transaction_date <= ?1), 0) AS total_penarikan,
 
        COALESCE((SELECT SUM(l.amount) FROM loans l
          WHERE l.project_id = p.id AND l.loan_date <= ?1), 0) AS total_dipinjam,
 
        COALESCE((SELECT SUM(lp.amount) FROM loan_payments lp
          JOIN loans l ON l.id = lp.loan_id
          WHERE l.project_id = p.id AND lp.payment_date <= ?1), 0) AS total_kembali,
 
        COALESCE((SELECT SUM(l.total_amount - l.paid_amount) FROM loans l
          WHERE l.project_id = p.id AND l.loan_date <= ?1
          AND l.status != 'paid'), 0) AS dana_dipinjam_aktif,
 
        (
          COALESCE((SELECT SUM(s.amount) FROM savings s WHERE s.project_id = p.id
            AND s.type = 'deposit' AND s.transaction_date <= ?1), 0)
          - COALESCE((SELECT SUM(s.amount) FROM savings s WHERE s.project_id = p.id
            AND s.type = 'withdrawal' AND s.transaction_date <= ?1), 0)
          - COALESCE((SELECT SUM(l.amount) FROM loans l
            WHERE l.project_id = p.id AND l.loan_date <= ?1), 0)
          + COALESCE((SELECT SUM(lp.amount) FROM loan_payments lp
            JOIN loans l ON l.id = lp.loan_id
            WHERE l.project_id = p.id AND lp.payment_date <= ?1), 0)
        ) AS dana_di_tangan,
 
        -- Hanya hari itu saja
        COALESCE((SELECT SUM(s.amount) FROM savings s
          WHERE s.project_id = p.id AND s.type = 'deposit'
          AND s.transaction_date >= ?2 AND s.transaction_date <= ?1), 0)
          AS setoran_hari_ini,
 
        COALESCE((SELECT SUM(l.amount) FROM loans l
          WHERE l.project_id = p.id
          AND l.loan_date >= ?2 AND l.loan_date <= ?1), 0)
          AS pinjaman_hari_ini,
 
        COALESCE((SELECT SUM(lp.amount) FROM loan_payments lp
          JOIN loans l ON l.id = lp.loan_id
          WHERE l.project_id = p.id
          AND lp.payment_date >= ?2 AND lp.payment_date <= ?1), 0)
          AS pembayaran_hari_ini
 
      FROM projects p WHERE p.id = ?3
    ''',
      [endOfDay, startOfDay, projectId],
    );

    if (rows.isEmpty) return null;
    return ProjectCashflowModel.fromMap(rows.first);
  }

  @override
  Future<ProjectCashflowModel?> getProjectCashflowOnDate(
    int projectId,
    DateTime date,
  ) async {
    final db = await _db.database;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      0,
      0,
      0,
    ).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT
        p.id   AS project_id,
        p.name AS project_name,
 
        COALESCE((SELECT SUM(s.amount) FROM savings s
          WHERE s.project_id = p.id AND s.type = 'deposit'
          AND s.transaction_date >= ?1 AND s.transaction_date <= ?2), 0)
          AS total_setoran,
 
        COALESCE((SELECT SUM(s.amount) FROM savings s
          WHERE s.project_id = p.id AND s.type = 'withdrawal'
          AND s.transaction_date >= ?1 AND s.transaction_date <= ?2), 0)
          AS total_penarikan,
 
        COALESCE((SELECT SUM(l.amount) FROM loans l
          WHERE l.project_id = p.id
          AND l.loan_date >= ?1 AND l.loan_date <= ?2), 0)
          AS total_dipinjam,
 
        COALESCE((SELECT SUM(lp.amount) FROM loan_payments lp
          JOIN loans l ON l.id = lp.loan_id
          WHERE l.project_id = p.id
          AND lp.payment_date >= ?1 AND lp.payment_date <= ?2), 0)
          AS total_kembali,
 
        0.0 AS dana_dipinjam_aktif,
        0.0 AS dana_di_tangan,
 
        COALESCE((SELECT SUM(s.amount) FROM savings s
          WHERE s.project_id = p.id AND s.type = 'deposit'
          AND s.transaction_date >= ?1 AND s.transaction_date <= ?2), 0)
          AS setoran_hari_ini,
 
        COALESCE((SELECT SUM(l.amount) FROM loans l
          WHERE l.project_id = p.id
          AND l.loan_date >= ?1 AND l.loan_date <= ?2), 0)
          AS pinjaman_hari_ini,
 
        COALESCE((SELECT SUM(lp.amount) FROM loan_payments lp
          JOIN loans l ON l.id = lp.loan_id
          WHERE l.project_id = p.id
          AND lp.payment_date >= ?1 AND lp.payment_date <= ?2), 0)
          AS pembayaran_hari_ini
 
      FROM projects p WHERE p.id = ?3
    ''',
      [startOfDay, endOfDay, projectId],
    );

    if (rows.isEmpty) return null;
    return ProjectCashflowModel.fromMap(rows.first);
  }

  /// Sinkronisasi auto-potong dari tabungan bersih member ke pinjaman aktif.
  /// Deterministik: rebuild auto-potong dari data terbaru supaya edit/hapus transaksi ikut undo.
  Future<void> _syncAutoPaymentFromSavings(DatabaseExecutor db, int memberId) async {
    await _removeAutoPayments(db, memberId);
    await _refreshLoanPaidAmounts(db, memberId);

    final netSavingsRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0)
        AS net_savings
      FROM savings
      WHERE member_id = ?
    ''',
      [memberId],
    );
    final netSavings =
        (netSavingsRows.first['net_savings'] as num?)?.toDouble() ?? 0;
    if (netSavings <= 0) return;

    double remainingBudget = netSavings;

    final activeLoans = await db.query(
      'loans',
      where: "member_id = ? AND status != 'paid'",
      whereArgs: [memberId],
      orderBy: 'loan_date ASC',
    );

    for (final loan in activeLoans) {
      if (remainingBudget <= 0) break;

      final loanId = loan['id'] as int;
      final total = (loan['total_amount'] as num?)?.toDouble() ?? 0;
      final paid = (loan['paid_amount'] as num?)?.toDouble() ?? 0;
      final unpaid = total - paid;
      if (unpaid <= 0) continue;

      final payment = remainingBudget >= unpaid ? unpaid : remainingBudget;
      remainingBudget -= payment;
      if (payment <= 0) continue;

      await db.insert('loan_payments', {
        'loan_id': loanId,
        'amount': payment,
        'note': 'Auto-potong dari tabungan',
        'payment_date': DateTime.now().toIso8601String(),
      });
    }

    await _refreshLoanPaidAmounts(db, memberId);
  }

  Future<void> _removeAutoPayments(DatabaseExecutor db, int memberId) async {
    final rows = await db.rawQuery(
      '''
      SELECT lp.id
      FROM loan_payments lp
      JOIN loans l ON l.id = lp.loan_id
      WHERE l.member_id = ?
        AND lp.note LIKE 'Auto-potong dari tabungan%'
    ''',
      [memberId],
    );

    for (final row in rows) {
      final id = row['id'] as int;
      await db.delete('loan_payments', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> _refreshLoanPaidAmounts(DatabaseExecutor db, int memberId) async {
    final loans = await db.query(
      'loans',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );

    for (final loan in loans) {
      final loanId = loan['id'] as int;
      final total = (loan['total_amount'] as num?)?.toDouble() ?? 0;
      final currentStatus = loan['status']?.toString() ?? 'active';

      final paidRows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS paid FROM loan_payments WHERE loan_id = ?',
        [loanId],
      );
      final paid = (paidRows.first['paid'] as num?)?.toDouble() ?? 0;

      final nextStatus = paid >= total
          ? 'paid'
          : (currentStatus == 'overdue' ? 'overdue' : 'active');

      await db.update(
        'loans',
        {
          'paid_amount': paid,
          'status': nextStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
    }
  }
}
