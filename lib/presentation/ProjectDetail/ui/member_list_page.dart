// lib/presentation/project_detail/screens/member_list_page.dart

import 'package:baitul_mal_plus/presentation/ProjectDetail/ui/member_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/data/repositories/member_repository_impl.dart';

final _currency = _CurrencyFmt();

class _CurrencyFmt {
  String fmt(double v) {
    // Format Rp dengan titik ribuan
    final absVal = v.abs();
    final formatted = absVal
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }
}

String _fmt(double v) => _currency.fmt(v);

enum _SortMode { id, name, balance, debt, savings }

class MemberListPage extends StatefulWidget {
  final ProjectModel project;
  const MemberListPage({super.key, required this.project});

  @override
  State<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<MemberListPage> {
  final MemberRepository _repo = MemberRepositoryImpl();
  late Future<List<MemberModel>> _future;
  _SortMode _sort = _SortMode.id;

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
      case _SortMode.id:
        copy.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      case _SortMode.name:
        copy.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.balance:
        copy.sort((a, b) => b.effectiveBalance.compareTo(a.effectiveBalance));
      case _SortMode.debt:
        copy.sort((a, b) => (b.sisaHutang ?? 0).compareTo(a.sisaHutang ?? 0));
      case _SortMode.savings:
        copy.sort((a, b) => (b.netSavings ?? 0).compareTo(a.netSavings ?? 0));
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _SortBar(current: _sort, onChanged: (s) => setState(() => _sort = s)),
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
                    itemBuilder: (ctx, i) => MemberTile(
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

// ── Sort Bar ──────────────────────────────────────────────────
class _SortBar extends StatelessWidget {
  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;

  const _SortBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text('Urutkan:', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SortChip(
                    label: 'ID',
                    selected: current == _SortMode.id,
                    onTap: () => onChanged(_SortMode.id),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: 'Nama',
                    selected: current == _SortMode.name,
                    onTap: () => onChanged(_SortMode.name),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: 'Saldo',
                    selected: current == _SortMode.balance,
                    onTap: () => onChanged(_SortMode.balance),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: 'Hutang',
                    selected: current == _SortMode.debt,
                    onTap: () => onChanged(_SortMode.debt),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: 'Tabungan',
                    selected: current == _SortMode.savings,
                    onTap: () => onChanged(_SortMode.savings),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

// ── Member Tile ───────────────────────────────────────────────
class MemberTile extends StatelessWidget {
  final MemberModel member;
  final ProjectModel project;
  final VoidCallback onRefresh;
  final MemberRepository repo;

  const MemberTile({
    super.key,
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

// ── Empty State ───────────────────────────────────────────────
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
