import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/data/repositories/member_repository_impl.dart';

class DailyStatsCard extends StatelessWidget {
  final int projectId;
  final double setoranHariIni;
  final double pinjamanHariIni;
  final double pembayaranHariIni;
  final DateTime date;

  const DailyStatsCard({
    super.key,
    required this.projectId,
    required this.setoranHariIni,
    required this.pinjamanHariIni,
    required this.pembayaranHariIni,
    required this.date,
  });

  String _fmt(double v) {
    final absVal = v.abs();
    final formatted = absVal
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasActivity =
        setoranHariIni > 0 || pinjamanHariIni > 0 || pembayaranHariIni > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cs.surfaceContainerHigh,
      child: InkWell(
        onTap: hasActivity ? () => _showDetails(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Aktivitas Hari Ini',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  if (hasActivity)
                    Icon(Icons.chevron_right, size: 16, color: cs.outline),
                ],
              ),
              if (!hasActivity) ...[
                const SizedBox(height: 8),
                Text(
                  'Belum ada transaksi hari ini',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.outline),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (setoranHariIni > 0)
                      Expanded(
                        child: _DailyItem(
                          label: 'Setoran',
                          value: _fmt(setoranHariIni),
                          color: Colors.green,
                          icon: Icons.arrow_downward,
                        ),
                      ),
                    if (pinjamanHariIni > 0) ...[
                      if (setoranHariIni > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _DailyItem(
                          label: 'Pinjaman',
                          value: _fmt(pinjamanHariIni),
                          color: Colors.red,
                          icon: Icons.credit_card,
                        ),
                      ),
                    ],
                    if (pembayaranHariIni > 0) ...[
                      if (setoranHariIni > 0 || pinjamanHariIni > 0)
                        const SizedBox(width: 8),
                      Expanded(
                        child: _DailyItem(
                          label: 'Bayar Hutang',
                          value: _fmt(pembayaranHariIni),
                          color: Colors.blue,
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Klik untuk lihat detail member',
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DailyTransactionDetailSheet(
        projectId: projectId,
        date: date,
      ),
    );
  }
}

class _DailyItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _DailyItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class DailyTransactionDetailSheet extends StatelessWidget {
  final int projectId;
  final DateTime date;

  const DailyTransactionDetailSheet({
    super.key,
    required this.projectId,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final MemberRepository repo = MemberRepositoryImpl();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Detail Transaksi — ${date.day}/${date.month}/${date.year}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: Future.wait([
                  repo.getSavingsByDate(projectId, date),
                  repo.getLoansByDate(projectId, date),
                ]),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final savings = snap.data![0] as List<SavingModel>;
                  final loans = snap.data![1] as List<LoanModel>;

                  if (savings.isEmpty && loans.isEmpty) {
                    return const Center(child: Text('Tidak ada detail transaksi'));
                  }

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (savings.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Tabungan (Setoran/Penarikan)'),
                        ...savings.map((s) => _buildSavingTile(context, s)),
                        const SizedBox(height: 16),
                      ],
                      if (loans.isNotEmpty) ...[
                        _buildSectionHeader(context, 'Pinjaman Baru'),
                        ...loans.map((l) => _buildLoanTile(context, l)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSavingTile(BuildContext context, SavingModel s) {
    final isDeposit = s.type == 'deposit';
    final color = isDeposit ? Colors.green : Colors.orange;
    final nf = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
        ),
        title: Text(s.memberName ?? 'Member #${s.memberId}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: s.note != null ? Text(s.note!) : null,
        trailing: Text(
          nf.format(s.amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildLoanTile(BuildContext context, LoanModel l) {
    final nf = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          child: const Icon(Icons.credit_card, color: Colors.red, size: 20),
        ),
        title: Text(l.memberName ?? 'Member #${l.memberId}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: l.note != null ? Text(l.note!) : null,
        trailing: Text(
          nf.format(l.amount),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ),
    );
  }
}
