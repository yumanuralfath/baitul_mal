// lib/presentation/project_detail/widgets/export_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:baitul_mal_plus/data/services/export_service.dart';

// ═══════════════════════════════════════════════════════════════
// EXPORT SHEET — bottom sheet pilih format ekspor
// ═══════════════════════════════════════════════════════════════
class ExportSheet extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ExportSheet({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _loading = false;
  String? _loadingLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.import_export, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Ekspor & Impor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.projectName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ),
          const SizedBox(height: 16),

          // Loading indicator
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _loadingLabel ?? 'Memproses...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          if (!_loading) ...[
            // EKSPOR section
            _SectionLabel(label: 'EKSPOR', icon: Icons.upload),
            _ExportTile(
              icon: Icons.picture_as_pdf,
              iconColor: Colors.red,
              title: 'Ekspor PDF',
              subtitle: 'Laporan lengkap siap cetak',
              onTap: () => _export('pdf'),
            ),
            _ExportTile(
              icon: Icons.table_chart_outlined,
              iconColor: Colors.green,
              title: 'Ekspor CSV',
              subtitle: 'Kompatibel dengan Excel / Google Sheets',
              onTap: () => _export('csv'),
            ),
            _ExportTile(
              icon: Icons.storage_outlined,
              iconColor: cs.primary,
              title: 'Backup SQL (Project ini)',
              subtitle: 'Backup data project untuk restore nanti',
              onTap: () => _export('sql_project'),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _export(String type) async {
    setState(() {
      _loading = true;
      _loadingLabel = switch (type) {
        'pdf' => 'Membuat PDF...',
        'csv' => 'Membuat CSV...',
        'sql_project' => 'Membuat backup project...',
        _ => 'Membuat backup...',
      };
    });

    try {
      File file;
      String subject;

      switch (type) {
        case 'pdf':
          file = await ExportService.exportPdf(projectId: widget.projectId);
          subject = 'Laporan ${widget.projectName}.pdf';
        case 'csv':
          file = await ExportService.exportCsv(projectId: widget.projectId);
          subject = 'Data ${widget.projectName}.csv';
        case 'sql_project':
          file = await ExportService.exportSql(projectId: widget.projectId);
          subject = 'Backup ${widget.projectName}.sql';
        default:
          file = await ExportService.exportSql();
          subject = 'Backup Semua Data.sql';
      }

      if (mounted) Navigator.pop(context);
      await ExportService.shareFile(context, file, subject: subject);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal ekspor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Section Label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Export Tile ───────────────────────────────────────────────
class _ExportTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DAILY STATS CARD — tampilkan aktivitas di hari tertentu
// ═══════════════════════════════════════════════════════════════
class DailyStatsCard extends StatelessWidget {
  final double setoranHariIni;
  final double pinjamanHariIni;
  final double pembayaranHariIni;
  final DateTime date;

  const DailyStatsCard({
    super.key,
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
            ],
          ],
        ),
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
