import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/models/project_cashflow_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/data/repositories/member_repository_impl.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/appbar.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String _fmt(double v) => _currency.format(v);

// ═══════════════════════════════════════════════════════════════
// PROJECT DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════
class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback toggleTheme;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.toggleTheme,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _MemberListPage(project: widget.project),
      _OverallSummaryPage(project: widget.project),
    ];

    return Scaffold(
      appBar: buildAppBar(
        context,
        toggleTheme: widget.toggleTheme,
        title: widget.project.name,
      ),
      body: pages[_pageIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pageIndex,
        onDestinationSelected: (i) => setState(() => _pageIndex = i),
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.people),
            icon: Icon(Icons.people_outline),
            label: 'Member',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.pie_chart),
            icon: Icon(Icons.pie_chart_outline),
            label: 'Keseluruhan',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MEMBER LIST PAGE
// ═══════════════════════════════════════════════════════════════
enum _SortMode { name, balance, debt }

class _MemberListPage extends StatefulWidget {
  final ProjectModel project;
  const _MemberListPage({required this.project});

  @override
  State<_MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<_MemberListPage> {
  final MemberRepository _repo = MemberRepositoryImpl();
  late Future<List<MemberModel>> _future;
  _SortMode _sort = _SortMode.name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repo.getMembersByProject(widget.project.id!);
    });
  }

  List<MemberModel> _sorted(List<MemberModel> list) {
    final copy = [...list];
    switch (_sort) {
      case _SortMode.name:
        copy.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.balance:
        copy.sort((a, b) => b.effectiveBalance.compareTo(a.effectiveBalance));
      case _SortMode.debt:
        copy.sort((a, b) => b.sisaHutang!.compareTo(a.sisaHutang!));
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text('Urutkan:', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Nama',
                  selected: _sort == _SortMode.name,
                  onTap: () => setState(() => _sort = _SortMode.name),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'Saldo',
                  selected: _sort == _SortMode.balance,
                  onTap: () => setState(() => _sort = _SortMode.balance),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: 'Hutang',
                  selected: _sort == _SortMode.debt,
                  onTap: () => setState(() => _sort = _SortMode.debt),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MemberModel>>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final members = _sorted(snap.data ?? []);
                if (members.isEmpty) {
                  return _EmptyMembers(
                    onAdd: () => _showAddMemberDialog(context),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: members.length,
                    itemBuilder: (ctx, i) => _MemberTile(
                      member: members[i],
                      project: widget.project,
                      onRefresh: _load,
                      repo: _repo,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Member'),
      ),
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'No. HP (opsional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await _repo.addMember(
        MemberModel(
          projectId: widget.project.id!,
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        ),
      );
      _load();
    }
  }
}

// ── Member Tile ──────────────────────────────────────────────
class _MemberTile extends StatelessWidget {
  final MemberModel member;
  final ProjectModel project;
  final VoidCallback onRefresh;
  final MemberRepository repo;

  const _MemberTile({
    required this.member,
    required this.project,
    required this.onRefresh,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final balance = member.effectiveBalance;
    final isNegative = balance < 0;
    final hasDebt = (member.sisaHutang ?? 0) > 0;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: 16,
          right: 4,
          top: 8,
          bottom: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: isNegative ? cs.errorContainer : cs.primaryContainer,
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(
              color: isNegative ? cs.onErrorContainer : cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isNegative ? cs.error : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tabungan: ${_fmt(member.netSavings ?? 0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (hasDebt)
              Text(
                'Hutang: ${_fmt(member.sisaHutang ?? 0)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.error),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt(balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isNegative ? cs.error : cs.primary,
                  ),
                ),
                Text('efektif', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                if (v == 'rename') {
                  await _showRenameDialog(context);
                } else if (v == 'delete') {
                  await _showDeleteConfirm(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.person_off_outlined, color: Colors.red),
                    title: Text('Hapus', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberDetailScreen(
                member: member,
                project: project,
                onRefresh: onRefresh,
              ),
            ),
          ).then((_) => onRefresh());
        },
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: member.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Member'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nama baru',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == true &&
        ctrl.text.trim().isNotEmpty &&
        ctrl.text.trim() != member.name) {
      await repo.updateMember(member.copyWith(name: ctrl.text.trim()));
      onRefresh();
    }
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 40,
        ),
        title: const Text('Hapus Member?'),
        content: Text(
          'Member "${member.name}" akan dinonaktifkan.\n'
          'Semua riwayat transaksi tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await repo.deleteMember(member.id!);
      onRefresh();
    }
  }
}

// ── Sort Chip ────────────────────────────────────────────────
class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyMembers({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada member',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add),
            label: const Text('Tambah Member'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MEMBER DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════
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
      builder: (_) => _TransactionSheet(
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

// ── Stat Card ────────────────────────────────────────────────
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

// ── Savings List ─────────────────────────────────────────────
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
                            builder: (_) => _EditSavingSheet(
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

// ── Loans List ───────────────────────────────────────────────
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
                        _LoanStatusBadge(status: l.status),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await showModalBottomSheet(
                                context: ctx,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => _EditLoanSheet(
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

// ── Loan Status Badge ────────────────────────────────────────
class _LoanStatusBadge extends StatelessWidget {
  final String status;
  const _LoanStatusBadge({required this.status});

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

// ═══════════════════════════════════════════════════════════════
// ADD TRANSACTION SHEET
// ═══════════════════════════════════════════════════════════════
class _TransactionSheet extends StatefulWidget {
  final MemberModel member;
  final ProjectModel project;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const _TransactionSheet({
    required this.member,
    required this.project,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _savingAmountCtrl = TextEditingController();
  final _savingNoteCtrl = TextEditingController();
  String _savingType = 'deposit';
  DateTime _savingDate = DateTime.now();
  final _loanAmountCtrl = TextEditingController();
  final _loanNoteCtrl = TextEditingController();
  final _loanRateCtrl = TextEditingController(text: '0');
  DateTime _loanDate = DateTime.now();
  DateTime? _loanDueDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _savingAmountCtrl.dispose();
    _savingNoteCtrl.dispose();
    _loanAmountCtrl.dispose();
    _loanNoteCtrl.dispose();
    _loanRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(title: 'Transaksi — ${widget.member.name}'),
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'Tabungan'),
              Tab(text: 'Pinjaman'),
            ],
          ),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tab,
              children: [_buildSavingForm(), _buildLoanForm()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'deposit',
                label: Text('Setoran'),
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment(
                value: 'withdrawal',
                label: Text('Penarikan'),
                icon: Icon(Icons.arrow_upward),
              ),
            ],
            selected: {_savingType},
            onSelectionChanged: (v) => setState(() => _savingType = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _savingAmountCtrl,
            decoration: const InputDecoration(
              labelText: 'Jumlah (Rp) *',
              border: OutlineInputBorder(),
              prefixText: 'Rp ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _DatePickerField(
            label: 'Tanggal Transaksi',
            date: _savingDate,
            onPick: (d) => setState(() => _savingDate = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _savingNoteCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submitSaving,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Tabungan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _loanAmountCtrl,
            decoration: const InputDecoration(
              labelText: 'Jumlah Pinjaman (Rp) *',
              border: OutlineInputBorder(),
              prefixText: 'Rp ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loanRateCtrl,
            decoration: const InputDecoration(
              labelText: 'Bunga (%)',
              border: OutlineInputBorder(),
              suffixText: '%',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _DatePickerField(
            label: 'Tanggal Pinjam',
            date: _loanDate,
            onPick: (d) => setState(() => _loanDate = d),
          ),
          const SizedBox(height: 12),
          _DatePickerField(
            label: 'Jatuh Tempo (opsional)',
            date: _loanDueDate,
            onPick: (d) => setState(() => _loanDueDate = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loanNoteCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submitLoan,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Pinjaman'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSaving() async {
    final amount = double.tryParse(
      _savingAmountCtrl.text.trim().replaceAll('.', ''),
    );
    if (amount == null || amount <= 0) {
      _showError('Jumlah tidak valid');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.repo.addSaving(
        SavingModel(
          projectId: widget.project.id!,
          memberId: widget.member.id!,
          amount: amount,
          type: _savingType,
          note: _savingNoteCtrl.text.trim().isEmpty
              ? null
              : _savingNoteCtrl.text.trim(),
          transactionDate: _savingDate,
        ),
      );
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitLoan() async {
    final amount = double.tryParse(
      _loanAmountCtrl.text.trim().replaceAll('.', ''),
    );
    if (amount == null || amount <= 0) {
      _showError('Jumlah tidak valid');
      return;
    }
    final rate = double.tryParse(_loanRateCtrl.text.trim()) ?? 0;
    final total = amount + (amount * rate / 100);
    setState(() => _loading = true);
    try {
      await widget.repo.addLoan(
        LoanModel(
          projectId: widget.project.id!,
          memberId: widget.member.id!,
          amount: amount,
          interestRate: rate,
          totalAmount: total,
          loanDate: _loanDate,
          dueDate: _loanDueDate,
          note: _loanNoteCtrl.text.trim().isEmpty
              ? null
              : _loanNoteCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}

// ═══════════════════════════════════════════════════════════════
// EDIT SAVING SHEET
// ═══════════════════════════════════════════════════════════════
class _EditSavingSheet extends StatefulWidget {
  final SavingModel saving;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const _EditSavingSheet({
    required this.saving,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<_EditSavingSheet> createState() => _EditSavingSheetState();
}

class _EditSavingSheetState extends State<_EditSavingSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _type;
  late DateTime _date;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.saving.amount.toStringAsFixed(0),
    );
    _noteCtrl = TextEditingController(text: widget.saving.note ?? '');
    _type = widget.saving.type;
    _date = widget.saving.transactionDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(title: 'Edit Tabungan'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'deposit',
                        label: Text('Setoran'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                      ButtonSegment(
                        value: 'withdrawal',
                        label: Text('Penarikan'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (v) => setState(() => _type = v.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (Rp) *',
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Tanggal Transaksi',
                    date: _date,
                    onPick: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan Perubahan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah tidak valid'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.repo.updateSaving(
        SavingModel(
          id: widget.saving.id,
          projectId: widget.saving.projectId,
          memberId: widget.saving.memberId,
          amount: amount,
          type: _type,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          transactionDate: _date,
        ),
      );
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// EDIT LOAN SHEET
// ═══════════════════════════════════════════════════════════════
class _EditLoanSheet extends StatefulWidget {
  final LoanModel loan;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const _EditLoanSheet({
    required this.loan,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<_EditLoanSheet> createState() => _EditLoanSheetState();
}

class _EditLoanSheetState extends State<_EditLoanSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _loanDate;
  late DateTime? _dueDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.loan.amount.toStringAsFixed(0),
    );
    _rateCtrl = TextEditingController(
      text: widget.loan.interestRate.toStringAsFixed(0),
    );
    _noteCtrl = TextEditingController(text: widget.loan.note ?? '');
    _loanDate = widget.loan.loanDate;
    _dueDate = widget.loan.dueDate;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(title: 'Edit Pinjaman'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Pinjaman (Rp) *',
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bunga (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Tanggal Pinjam',
                    date: _loanDate,
                    onPick: (d) => setState(() => _loanDate = d),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Jatuh Tempo (opsional)',
                    date: _dueDate,
                    onPick: (d) => setState(() => _dueDate = d),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan Perubahan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah tidak valid'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final total = amount + (amount * rate / 100);
    setState(() => _loading = true);
    try {
      await widget.repo.updateLoan(
        LoanModel(
          id: widget.loan.id,
          projectId: widget.loan.projectId,
          memberId: widget.loan.memberId,
          amount: amount,
          interestRate: rate,
          totalAmount: total,
          paidAmount: widget.loan.paidAmount,
          status: widget.loan.status,
          loanDate: _loanDate,
          dueDate: _dueDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Shared Sheet Handle Widget ────────────────────────────────
class _SheetHandle extends StatelessWidget {
  final String title;
  const _SheetHandle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ── Date Picker Field ────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date != null
              ? DateFormat('dd MMMM yyyy', 'id_ID').format(date!)
              : '— pilih tanggal —',
          style: date == null
              ? TextStyle(color: Theme.of(context).colorScheme.outline)
              : null,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OVERALL SUMMARY PAGE
// ═══════════════════════════════════════════════════════════════
class _OverallSummaryPage extends StatefulWidget {
  final ProjectModel project;
  const _OverallSummaryPage({required this.project});

  @override
  State<_OverallSummaryPage> createState() => _OverallSummaryPageState();
}

class _OverallSummaryPageState extends State<_OverallSummaryPage> {
  final MemberRepository _repo = MemberRepositoryImpl();
  late Future<ProjectCashflowModel?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _repo.getProjectCashflow(widget.project.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProjectCashflowModel?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final cf = snap.data;
        if (cf == null) {
          return const Center(child: Text('Belum ada data'));
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: _SummaryContent(cashflow: cf),
        );
      },
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final ProjectCashflowModel cashflow;
  const _SummaryContent({required this.cashflow});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDana = cashflow.totalSetoran - cashflow.totalPenarikan;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PieChartCard(cashflow: cashflow),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _InfoCard(
              label: 'Total Dana\nTerkumpul',
              value: _fmt(totalDana),
              icon: Icons.savings,
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
            ),
            _InfoCard(
              label: 'Dana di\nTangan',
              value: _fmt(cashflow.danadiTangan),
              icon: Icons.account_balance_wallet,
              color: cs.secondaryContainer,
              onColor: cs.onSecondaryContainer,
            ),
            _InfoCard(
              label: 'Dana\nDipinjam',
              value: _fmt(cashflow.danaDipinjamAktif),
              icon: Icons.credit_card,
              color: cs.errorContainer,
              onColor: cs.onErrorContainer,
            ),
            _InfoCard(
              label: 'Total\nKembali',
              value: _fmt(cashflow.totalKembali),
              icon: Icons.keyboard_return,
              color: cs.tertiaryContainer,
              onColor: cs.onTertiaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailRow('Total Setoran', cashflow.totalSetoran, isPositive: true),
        _DetailRow(
          'Total Penarikan',
          cashflow.totalPenarikan,
          isPositive: false,
        ),
        const Divider(),
        _DetailRow(
          'Total Pernah Dipinjam',
          cashflow.totalDipinjam,
          isPositive: false,
        ),
        _DetailRow(
          'Total Sudah Kembali',
          cashflow.totalKembali,
          isPositive: true,
        ),
        const Divider(),
        _DetailRow(
          'Sisa Pinjaman Aktif',
          cashflow.danaDipinjamAktif,
          isPositive: false,
          isBold: true,
        ),
        _DetailRow(
          'Dana di Tangan',
          cashflow.danadiTangan,
          isPositive: true,
          isBold: true,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PIE CHART CARD — animated donut with percentage labels
// ═══════════════════════════════════════════════════════════════
class _PieChartCard extends StatefulWidget {
  final ProjectCashflowModel cashflow;
  const _PieChartCard({required this.cashflow});

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inHand = widget.cashflow.danadiTangan
        .clamp(0, double.infinity)
        .toDouble();
    final inLoan = widget.cashflow.danaDipinjamAktif
        .clamp(0, double.infinity)
        .toDouble();
    final total = inHand + inLoan;
    final pctHand = total > 0 ? (inHand / total * 100) : 0.0;
    final pctLoan = total > 0 ? (inLoan / total * 100) : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Distribusi Dana',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: total == 0
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pie_chart_outline,
                            size: 64,
                            color: cs.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada dana',
                            style: TextStyle(color: cs.outline),
                          ),
                        ],
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _anim,
                      builder: (_, _) => CustomPaint(
                        painter: _DonutChartPainter(
                          segments: [
                            _ChartSegment(
                              value: inHand,
                              color: cs.primary,
                              label: '${pctHand.toStringAsFixed(1)}%',
                            ),
                            _ChartSegment(
                              value: inLoan,
                              color: cs.error,
                              label: '${pctLoan.toStringAsFixed(1)}%',
                            ),
                          ],
                          progress: _anim.value,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmt(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Total Dana',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _LegendTile(
                    color: cs.primary,
                    label: 'Di Tangan',
                    value: _fmt(inHand),
                    percent: '${pctHand.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LegendTile(
                    color: cs.error,
                    label: 'Dipinjam',
                    value: _fmt(inLoan),
                    percent: '${pctLoan.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Donut Painter ─────────────────────────────────────────────
class _ChartSegment {
  final double value;
  final Color color;
  final String label;
  const _ChartSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSegment> segments;
  final double progress;
  final Color backgroundColor;

  _DonutChartPainter({
    required this.segments,
    required this.progress,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0.0, (s, e) => s + e.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final holeRadius = radius * 0.54;
    const startAngle = -math.pi / 2;
    const gapAngle = 0.03; // gap antar segment (radian)

    double currentAngle = startAngle;
    final outerRect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = ((seg.value / total) * 2 * math.pi - gapAngle) * progress;
      if (sweep <= 0) {
        currentAngle += (seg.value / total) * 2 * math.pi * progress;
        continue;
      }

      // Shadow
      final shadowPaint = Paint()
        ..color = seg.color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
        Rect.fromCircle(center: center + const Offset(2, 3), radius: radius),
        currentAngle,
        sweep,
        true,
        shadowPaint,
      );

      // Segment
      canvas.drawArc(
        outerRect,
        currentAngle,
        sweep,
        true,
        Paint()..color = seg.color,
      );

      // Percentage label (only when animation complete and segment > 8%)
      if (progress >= 1.0 && seg.value / total > 0.08) {
        final midAngle = currentAngle + sweep / 2;
        final labelRadius = (radius + holeRadius) / 2;
        final labelPos = Offset(
          center.dx + labelRadius * math.cos(midAngle),
          center.dy + labelRadius * math.sin(midAngle),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: seg.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
      }

      currentAngle += (seg.value / total) * 2 * math.pi * progress + gapAngle;
    }

    // Donut hole
    canvas.drawCircle(center, holeRadius, Paint()..color = backgroundColor);

    // Subtle inner ring
    canvas.drawCircle(
      center,
      holeRadius,
      Paint()
        ..color = backgroundColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DonutChartPainter old) => old.progress != progress;
}

// ── Legend Tile ───────────────────────────────────────────────
class _LegendTile extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String percent;

  const _LegendTile({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            percent,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color onColor;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: onColor, size: 20),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: onColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: onColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail Row ────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isPositive;
  final bool isBold;

  const _DetailRow(
    this.label,
    this.value, {
    required this.isPositive,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            _fmt(value),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isPositive ? cs.primary : cs.error,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
