// lib/presentation/project_detail/screens/member_detail_screen.dart

import 'package:baitul_mal_plus/presentation/ProjectDetail/widget/transaction_sheets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/data/repositories/member_repository_impl.dart';

final _nf = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
String _fmt(double v) => _nf.format(v);

class MemberDetailScreen extends StatefulWidget {
  final MemberModel member;
  final ProjectModel project;
  final VoidCallback onRefresh;

  const MemberDetailScreen({
    super.key,
    required this.member,
    required this.project,
    required this.onRefresh,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SingleTickerProviderStateMixin {
  final MemberRepository _repo = MemberRepositoryImpl();
  late TabController _tabController;
  late Future<List<SavingModel>> _savingsFuture;
  late Future<List<LoanModel>> _loansFuture;
  late MemberModel _member;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _savingsFuture = _repo.getSavingsByMember(_member.id!);
      _loansFuture = _repo.getLoansByMember(_member.id!);
    });
  }

  Future<void> _refreshMember() async {
    final updated = await _repo.getMembersByProject(_member.projectId);
    final found = updated.where((m) => m.id == _member.id).firstOrNull;
    if (found != null && mounted) setState(() => _member = found);
    widget.onRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = _member.effectiveBalance;
    final isNegative = balance < 0;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.savings_outlined), text: 'Tabungan'),
            Tab(icon: Icon(Icons.credit_card_outlined), text: 'Pinjaman'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isNegative
                    ? [cs.errorContainer, cs.error.withValues(alpha: 0.3)]
                    : [cs.primaryContainer, cs.primary.withValues(alpha: 0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Tabungan\nBersih',
                    value: _fmt(_member.netSavings ?? 0),
                    icon: Icons.savings,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: cs.onSurface.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _StatCard(
                    label: 'Sisa\nHutang',
                    value: _fmt(_member.sisaHutang ?? 0),
                    icon: Icons.credit_card,
                    valueColor: (_member.sisaHutang ?? 0) > 0 ? cs.error : null,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: cs.onSurface.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _StatCard(
                    label: 'Saldo\nEfektif',
                    value: _fmt(balance),
                    icon: Icons.account_balance_wallet,
                    valueColor: isNegative ? cs.error : cs.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SavingsList(
                  future: _savingsFuture,
                  repo: _repo,
                  onChanged: () {
                    _loadAll();
                    _refreshMember();
                  },
                ),
                _LoansList(
                  future: _loansFuture,
                  repo: _repo,
                  onChanged: () {
                    _loadAll();
                    _refreshMember();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
    );
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransactionSheet(
        member: _member,
        project: widget.project,
        repo: _repo,
        onSuccess: () {
          _loadAll();
          _refreshMember();
        },
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Savings List ──────────────────────────────────────────────
class _SavingsList extends StatelessWidget {
  final Future<List<SavingModel>> future;
  final MemberRepository repo;
  final VoidCallback onChanged;

  const _SavingsList({
    required this.future,
    required this.repo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavingModel>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('Belum ada riwayat tabungan'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final s = list[i];
            final isDeposit = s.type == 'deposit';
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDeposit
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  child: Icon(
                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isDeposit ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
                title: Text(
                  isDeposit ? 'Setor' : 'Tarik',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  DateFormat('dd MMM yyyy', 'id_ID').format(s.transactionDate) +
                      (s.note != null ? '\n${s.note}' : ''),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isDeposit ? '+' : '-'}${_fmt(s.amount)}',
                      style: TextStyle(
                        color: isDeposit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await showModalBottomSheet(
                            context: ctx,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => EditSavingSheet(
                              saving: s,
                              repo: repo,
                              onSuccess: onChanged,
                            ),
                          );
                        } else if (v == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              icon: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 40,
                              ),
                              title: const Text('Hapus Transaksi?'),
                              content: Text(
                                'Transaksi ${isDeposit ? 'setoran' : 'penarikan'} '
                                'sebesar ${_fmt(s.amount)} akan dihapus.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Batal'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await repo.deleteSaving(s.id!);
                            onChanged();
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            title: Text(
                              'Hapus',
                              style: TextStyle(color: Colors.red),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Loans List ────────────────────────────────────────────────
class _LoansList extends StatelessWidget {
  final Future<List<LoanModel>> future;
  final MemberRepository repo;
  final VoidCallback onChanged;

  const _LoansList({
    required this.future,
    required this.repo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LoanModel>>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('Belum ada riwayat pinjaman'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final l = list[i];
            final isPaid = l.status == 'paid';
            final cs = Theme.of(ctx).colorScheme;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fmt(l.totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        LoanStatusBadge(status: l.status),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await showModalBottomSheet(
                                context: ctx,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => EditLoanSheet(
                                  loan: l,
                                  repo: repo,
                                  onSuccess: onChanged,
                                ),
                              );
                            } else if (v == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  icon: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 40,
                                  ),
                                  title: const Text('Hapus Pinjaman?'),
                                  content: Text(
                                    'Pinjaman sebesar ${_fmt(l.totalAmount)} '
                                    'beserta semua data cicilan akan dihapus.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Batal'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await repo.deleteLoan(l.id!);
                                onChanged();
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'Tgl: ${DateFormat('dd MMM yyyy', 'id_ID').format(l.loanDate)}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    if (l.dueDate != null)
                      Text(
                        'Jatuh tempo: ${DateFormat('dd MMM yyyy', 'id_ID').format(l.dueDate!)}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    if (!isPaid) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: l.totalAmount > 0
                            ? (l.paidAmount / l.totalAmount).clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Terbayar: ${_fmt(l.paidAmount)} / ${_fmt(l.totalAmount)}  |  Sisa: ${_fmt(l.remainingAmount)}',
                        style: Theme.of(ctx).textTheme.labelSmall,
                      ),
                    ],
                    if (l.note != null) ...[
                      const SizedBox(height: 4),
                      Text(l.note!, style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Loan Status Badge ─────────────────────────────────────────
class LoanStatusBadge extends StatelessWidget {
  final String status;
  const LoanStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'paid' => ('Lunas', Colors.green),
      'overdue' => ('Terlambat', Colors.red),
      _ => ('Aktif', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
