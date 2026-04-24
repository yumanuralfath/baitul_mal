// lib/presentation/project_detail/screens/overall_summary_page.dart
// (Versi update — tambah daily stats di tab Per Tanggal + tombol export di AppBar)

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:baitul_mal_plus/presentation/ProjectDetail/widget/export_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/models/project_cashflow_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/data/repositories/member_repository_impl.dart';

final _nf = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
String _fmt(double v) => _nf.format(v);

class OverallSummaryPage extends StatefulWidget {
  final ProjectModel project;
  const OverallSummaryPage({super.key, required this.project});

  @override
  State<OverallSummaryPage> createState() => _OverallSummaryPageState();
}

class _OverallSummaryPageState extends State<OverallSummaryPage>
    with SingleTickerProviderStateMixin {
  final MemberRepository _repo = MemberRepositoryImpl();
  DateTime? _filterDate;
  late Future<ProjectCashflowModel?> _allTimeFuture;
  late Future<ProjectCashflowModel?> _dateFuture;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _allTimeFuture = _repo.getProjectCashflow(widget.project.id!);
      _dateFuture = _filterDate != null
          ? _repo.getProjectCashflowByDate(widget.project.id!, _filterDate!)
          : Future.value(null);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _load();
    }
  }

  void _clearDate() {
    setState(() => _filterDate = null);
    _load();
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExportSheet(
        projectId: widget.project.id!,
        projectName: widget.project.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _filterDate != null;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Tab bar + export button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabCtrl,
                  tabs: [
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.all_inclusive, size: 16),
                          SizedBox(width: 6),
                          Text('Keseluruhan'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: hasFilter ? cs.primary : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasFilter
                                ? DateFormat(
                                    'dd MMM',
                                    'id_ID',
                                  ).format(_filterDate!)
                                : 'Per Tanggal',
                            style: TextStyle(
                              color: hasFilter ? cs.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Export button
              IconButton(
                icon: const Icon(Icons.import_export),
                onPressed: _showExportSheet,
                tooltip: 'Ekspor & Impor',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // Tab 1: Keseluruhan
              _SummaryView(
                future: _allTimeFuture,
                onRefresh: _load,
                showDailyStats: false,
              ),
              // Tab 2: Per Tanggal
              _DateFilterView(
                future: _dateFuture,
                filterDate: _filterDate,
                onPickDate: _pickDate,
                onClearDate: _clearDate,
                onRefresh: _load,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Summary View ─────────────────────────────────────────────
class _SummaryView extends StatelessWidget {
  final Future<ProjectCashflowModel?> future;
  final VoidCallback onRefresh;
  final bool showDailyStats;

  const _SummaryView({
    required this.future,
    required this.onRefresh,
    this.showDailyStats = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProjectCashflowModel?>(
      future: future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final cf = snap.data;
        if (cf == null) {
          return const Center(child: Text('Belum ada data'));
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: _SummaryContent(cashflow: cf, showDailyStats: showDailyStats),
        );
      },
    );
  }
}

// ─── Date Filter View ─────────────────────────────────────────
class _DateFilterView extends StatelessWidget {
  final Future<ProjectCashflowModel?> future;
  final DateTime? filterDate;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final VoidCallback onRefresh;

  const _DateFilterView({
    required this.future,
    required this.filterDate,
    required this.onPickDate,
    required this.onClearDate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFilter = filterDate != null;

    return Column(
      children: [
        // Date picker bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    hasFilter
                        ? DateFormat(
                            'dd MMMM yyyy',
                            'id_ID',
                          ).format(filterDate!)
                        : 'Pilih Tanggal',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasFilter
                        ? cs.primary
                        : cs.onSurfaceVariant,
                    side: BorderSide(
                      color: hasFilter ? cs.primary : cs.outline,
                    ),
                  ),
                ),
              ),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClearDate,
                  tooltip: 'Hapus filter',
                ),
              ],
            ],
          ),
        ),
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  'Kumulatif s/d ${DateFormat('dd MMM yyyy', 'id_ID').format(filterDate!)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.outline),
                ),
              ],
            ),
          ),
        Expanded(
          child: hasFilter
              ? FutureBuilder<ProjectCashflowModel?>(
                  future: future,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final cf = snap.data;
                    if (cf == null) {
                      return const Center(child: Text('Belum ada data'));
                    }
                    return RefreshIndicator(
                      onRefresh: () async => onRefresh(),
                      child: _SummaryContent(
                        cashflow: cf,
                        showDailyStats: true,
                        filterDate: filterDate,
                      ),
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_outlined,
                        size: 64,
                        color: cs.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pilih tanggal untuk melihat ringkasan',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: onPickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Pilih Tanggal'),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Summary Content ──────────────────────────────────────────
class _SummaryContent extends StatelessWidget {
  final ProjectCashflowModel cashflow;
  final bool showDailyStats;
  final DateTime? filterDate;

  const _SummaryContent({
    required this.cashflow,
    this.showDailyStats = false,
    this.filterDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDana = cashflow.totalSetoran - cashflow.totalPenarikan;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily stats card (hanya di tab per tanggal)
        if (showDailyStats && filterDate != null)
          DailyStatsCard(
            setoranHariIni: cashflow.setoranHariIni ?? 0,
            pinjamanHariIni: cashflow.pinjamanHariIni ?? 0,
            pembayaranHariIni: cashflow.pembayaranHariIni ?? 0,
            date: filterDate!,
          ),

        PieChartCard(cashflow: cashflow),
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
// PIE CHART (sama seperti sebelumnya)
// ═══════════════════════════════════════════════════════════════
class PieChartCard extends StatefulWidget {
  final ProjectCashflowModel cashflow;
  const PieChartCard({super.key, required this.cashflow});

  @override
  State<PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<PieChartCard>
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
              height: 200,
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
                        painter: DonutChartPainter(
                          segments: [
                            ChartSegment(
                              value: inHand,
                              color: cs.primary,
                              label: '${pctHand.toStringAsFixed(1)}%',
                            ),
                            ChartSegment(
                              value: inLoan,
                              color: cs.error,
                              label: '${pctLoan.toStringAsFixed(1)}%',
                            ),
                          ],
                          progress: _anim.value,
                          backgroundColor: cs.surface,
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
                  child: LegendTile(
                    color: cs.primary,
                    label: 'Di Tangan',
                    value: _fmt(inHand),
                    percent: '${pctHand.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LegendTile(
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

class ChartSegment {
  final double value;
  final Color color;
  final String label;
  const ChartSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class DonutChartPainter extends CustomPainter {
  final List<ChartSegment> segments;
  final double progress;
  final Color backgroundColor;

  DonutChartPainter({
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
    const gapAngle = 0.03;
    double currentAngle = startAngle;
    final outerRect = Rect.fromCircle(center: center, radius: radius);

    for (final seg in segments) {
      final sweep = ((seg.value / total) * 2 * math.pi - gapAngle) * progress;
      if (sweep <= 0) {
        currentAngle += (seg.value / total) * 2 * math.pi * progress;
        continue;
      }
      canvas.drawArc(
        Rect.fromCircle(center: center + const Offset(2, 3), radius: radius),
        currentAngle,
        sweep,
        true,
        Paint()
          ..color = seg.color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawArc(
        outerRect,
        currentAngle,
        sweep,
        true,
        Paint()..color = seg.color,
      );
      if (progress >= 1.0 && seg.value / total > 0.08) {
        final midAngle = currentAngle + sweep / 2;
        final lr = (radius + holeRadius) / 2;
        final pos = Offset(
          center.dx + lr * math.cos(midAngle),
          center.dy + lr * math.sin(midAngle),
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
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
      currentAngle += (seg.value / total) * 2 * math.pi * progress + gapAngle;
    }
    canvas.drawCircle(center, holeRadius, Paint()..color = backgroundColor);
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
  bool shouldRepaint(DonutChartPainter old) => old.progress != progress;
}

class LegendTile extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String percent;
  const LegendTile({
    super.key,
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
