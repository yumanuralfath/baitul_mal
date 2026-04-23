// ─── INTERFACE ───────────────────────────────────────────────
// lib/domain/repositories/member_repository.dart

import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/models/project_cashflow_model.dart';

abstract class MemberRepository {
  Future<List<MemberModel>> getMembersByProject(int projectId);
  Future<MemberModel> addMember(MemberModel member);
  Future<void> updateMember(MemberModel member);
  Future<void> deleteMember(int id);
  // Savings
  Future<List<SavingModel>> getSavingsByMember(int memberId);
  Future<void> addSaving(SavingModel saving);
  Future<void> updateSaving(SavingModel saving);
  Future<void> deleteSaving(int id);
  // Loans
  Future<List<LoanModel>> getLoansByMember(int memberId);
  Future<List<LoanModel>> getActiveLoansByProject(int projectId);
  Future<void> addLoan(LoanModel loan);
  Future<void> updateLoan(LoanModel loan);
  Future<void> deleteLoan(int id);
  // Summary
  Future<ProjectCashflowModel?> getProjectCashflow(int projectId);

  Future<ProjectCashflowModel?> getProjectCashflowByDate(
    int projectId,
    DateTime date,
  );
  Future<ProjectCashflowModel?> getProjectCashflowOnDate(
    int projectId,
    DateTime date,
  );
}
