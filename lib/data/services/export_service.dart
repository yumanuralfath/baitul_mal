// lib/data/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:baitul_mal_plus/data/source/local/database_helper.dart';

// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

final _nf = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
String _fmt(double v) => _nf.format(v);
String _fmtDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

// ═══════════════════════════════════════════════════════════════
// EXPORT SERVICE
// ═══════════════════════════════════════════════════════════════
class ExportService {
  /// Ekspor seluruh database sebagai file SQL dump
  /// Berguna untuk backup lengkap & restore
  static Future<File> exportSql({int? projectId}) async {
    final db = await DatabaseHelper().database;

    final buffer = StringBuffer();
    buffer.writeln('-- Baitul Mal Plus — SQL Backup');
    buffer.writeln(
      '-- Tanggal: ${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.now())}',
    );
    buffer.writeln('-- ');
    buffer.writeln();

    // Urutan tabel sesuai dependency
    const tables = ['projects', 'members', 'savings', 'loans', 'loan_payments'];

    for (final table in tables) {
      List<Map<String, dynamic>> rows;

      if (projectId != null && table != 'projects') {
        // Filter per project jika ada
        rows = await _getRowsFiltered(db, table, projectId);
      } else if (projectId != null && table == 'projects') {
        rows = await db.query(table, where: 'id = ?', whereArgs: [projectId]);
      } else {
        rows = await db.query(table);
      }

      if (rows.isEmpty) continue;

      buffer.writeln('-- Table: $table');
      buffer.writeln(
        'DELETE FROM $table${projectId != null && table == 'projects'
            ? ' WHERE id = $projectId'
            : projectId != null
            ? ' WHERE project_id = $projectId'
            : ''};',
      );

      for (final row in rows) {
        final cols = row.keys.join(', ');
        final vals = row.values
            .map((v) {
              if (v == null) return 'NULL';
              if (v is int || v is double) return v.toString();
              return "'${v.toString().replaceAll("'", "''")}'";
            })
            .join(', ');
        buffer.writeln('INSERT INTO $table ($cols) VALUES ($vals);');
      }
      buffer.writeln();
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = projectId != null
        ? 'backup_project_${projectId}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.sql'
        : 'backup_all_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.sql';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(buffer.toString());
    return file;
  }

  /// Ekspor data ke CSV
  static Future<File> exportCsv({required int projectId}) async {
    final db = await DatabaseHelper().database;

    final buffer = StringBuffer();

    // REKAP PER TANGGAL (lebih mudah dibaca: nama tidak berulang per transaksi)
    buffer.writeln('=== REKAP PER TANGGAL ===');
    buffer.writeln('Tanggal,Nama Member,Setoran,Penarikan,Pinjaman,Cicilan');

    final rekap = await db.rawQuery(
      '''
      SELECT
        x.tgl,
        x.name,
        SUM(x.setoran)   AS setoran,
        SUM(x.penarikan) AS penarikan,
        SUM(x.pinjaman)  AS pinjaman,
        SUM(x.cicilan)   AS cicilan
      FROM (
        SELECT
          date(s.transaction_date) AS tgl,
          m.name AS name,
          CASE WHEN s.type = 'deposit' THEN s.amount ELSE 0 END AS setoran,
          CASE WHEN s.type = 'withdrawal' THEN s.amount ELSE 0 END AS penarikan,
          0 AS pinjaman,
          0 AS cicilan
        FROM savings s
        JOIN members m ON m.id = s.member_id
        WHERE s.project_id = ?

        UNION ALL

        SELECT
          date(l.loan_date) AS tgl,
          m.name AS name,
          0 AS setoran,
          0 AS penarikan,
          l.total_amount AS pinjaman,
          0 AS cicilan
        FROM loans l
        JOIN members m ON m.id = l.member_id
        WHERE l.project_id = ?

        UNION ALL

        SELECT
          date(lp.payment_date) AS tgl,
          m.name AS name,
          0 AS setoran,
          0 AS penarikan,
          0 AS pinjaman,
          lp.amount AS cicilan
        FROM loan_payments lp
        JOIN loans l ON l.id = lp.loan_id
        JOIN members m ON m.id = l.member_id
        WHERE l.project_id = ?
      ) x
      GROUP BY x.tgl, x.name
      ORDER BY x.tgl DESC, x.name ASC
    ''',
      [projectId, projectId, projectId],
    );

    for (final row in rekap) {
      final tgl = row['tgl']?.toString() ?? '';
      final nama = (row['name'] ?? '').toString().replaceAll(',', ' ');
      final setoran = (row['setoran'] as num?)?.toDouble() ?? 0;
      final penarikan = (row['penarikan'] as num?)?.toDouble() ?? 0;
      final pinjaman = (row['pinjaman'] as num?)?.toDouble() ?? 0;
      final cicilan = (row['cicilan'] as num?)?.toDouble() ?? 0;
      buffer.writeln(
        '${_fmtDate(tgl)},$nama,${setoran.toStringAsFixed(0)},${penarikan.toStringAsFixed(0)},${pinjaman.toStringAsFixed(0)},${cicilan.toStringAsFixed(0)}',
      );
    }

    buffer.writeln();
    buffer.writeln('=== DETAIL TABUNGAN ===');
    buffer.writeln('Nama Member,Tipe,Jumlah,Tanggal,Catatan');

    final savings = await db.rawQuery(
      '''
      SELECT m.name, s.type, s.amount, s.transaction_date, s.note
      FROM savings s JOIN members m ON m.id = s.member_id
      WHERE s.project_id = ?
      ORDER BY s.transaction_date DESC
    ''',
      [projectId],
    );

    for (final row in savings) {
      final nama = row['name'] ?? '';
      final tipe = row['type'] == 'deposit' ? 'Setor' : 'Tarik';
      final jumlah = (row['amount'] as num?)?.toDouble() ?? 0;
      final tgl = _fmtDate(row['transaction_date']?.toString() ?? '');
      final catatan = (row['note'] ?? '').toString().replaceAll(',', ';');
      buffer.writeln('$nama,$tipe,${jumlah.toStringAsFixed(0)},$tgl,$catatan');
    }

    buffer.writeln();
    buffer.writeln('=== PINJAMAN ===');
    buffer.writeln(
      'Nama Member,Pokok,Bunga(%),Total,Terbayar,Sisa,Status,Tanggal Pinjam,Jatuh Tempo,Catatan',
    );

    final loans = await db.rawQuery(
      '''
      SELECT
        m.name,
        l.amount,
        l.interest_rate,
        l.total_amount,
        -- "Terbayar" diambil dari cicilan yang berasal dari setoran tabungan (auto-potong)
        COALESCE((
          SELECT SUM(lp.amount)
          FROM loan_payments lp
          WHERE lp.loan_id = l.id
            AND (lp.note LIKE '%tabungan%')
        ), 0) AS paid_amount,
        l.status,
        l.loan_date,
        l.due_date,
        l.note
      FROM loans l JOIN members m ON m.id = l.member_id
      WHERE l.project_id = ?
      ORDER BY l.loan_date DESC
    ''',
      [projectId],
    );

    for (final row in loans) {
      final nama = row['name'] ?? '';
      final pokok = (row['amount'] as num?)?.toDouble() ?? 0;
      final bunga = (row['interest_rate'] as num?)?.toDouble() ?? 0;
      final total = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final bayar = (row['paid_amount'] as num?)?.toDouble() ?? 0;
      final sisa = total - bayar;
      final status = _statusLabel(row['status']?.toString() ?? '');
      final tglPinjam = _fmtDate(row['loan_date']?.toString() ?? '');
      final tglTempo = row['due_date'] != null
          ? _fmtDate(row['due_date'].toString())
          : '-';
      final catatan = (row['note'] ?? '').toString().replaceAll(',', ';');
      buffer.writeln(
        '$nama,${pokok.toStringAsFixed(0)},$bunga,${total.toStringAsFixed(0)},${bayar.toStringAsFixed(0)},${sisa.toStringAsFixed(0)},$status,$tglPinjam,$tglTempo,$catatan',
      );
    }

    buffer.writeln();
    buffer.writeln('=== CICILAN PINJAMAN ===');
    buffer.writeln('Nama Member,Jumlah Pinjaman,Cicilan,Tanggal Bayar,Catatan');

    final payments = await db.rawQuery(
      '''
      SELECT m.name, l.total_amount, lp.amount, lp.payment_date, lp.note
      FROM loan_payments lp
      JOIN loans l ON l.id = lp.loan_id
      JOIN members m ON m.id = l.member_id
      WHERE l.project_id = ?
      ORDER BY lp.payment_date DESC
    ''',
      [projectId],
    );

    for (final row in payments) {
      final nama = row['name'] ?? '';
      final totalPinjam = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final cicilan = (row['amount'] as num?)?.toDouble() ?? 0;
      final tgl = _fmtDate(row['payment_date']?.toString() ?? '');
      final catatan = (row['note'] ?? '').toString().replaceAll(',', ';');
      buffer.writeln(
        '$nama,${totalPinjam.toStringAsFixed(0)},${cicilan.toStringAsFixed(0)},$tgl,$catatan',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'export_project_${projectId}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(buffer.toString(), encoding: const Utf8Codec());
    return file;
  }

  /// Ekspor laporan ke PDF
  static Future<File> exportPdf({required int projectId}) async {
    final db = await DatabaseHelper().database;

    // Ambil nama project
    final projectRows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [projectId],
    );
    final projectName = projectRows.isNotEmpty
        ? projectRows.first['name']?.toString() ?? 'Project'
        : 'Project';

    // Ambil summary
    final summaryRows = await db.rawQuery(
      '''
      SELECT * FROM v_project_cashflow WHERE project_id = ?
    ''',
      [projectId],
    );

    // Ambil member summary
    final memberRows = await db.rawQuery(
      '''
      SELECT
        m.name,
        COALESCE(vs.net_savings, 0)  AS net_savings,
        COALESCE(vl.sisa_hutang, 0)  AS sisa_hutang,
        COALESCE(vs.net_savings, 0) - COALESCE(vl.sisa_hutang, 0) AS saldo_efektif
      FROM members m
      LEFT JOIN v_member_savings vs ON vs.member_id = m.id
      LEFT JOIN v_member_loans   vl ON vl.member_id = m.id
      WHERE m.project_id = ? AND m.is_active = 1
      ORDER BY m.name ASC
    ''',
      [projectId],
    );

    // Rekap per tanggal (group by tgl + anggota)
    final dateRecapRows = await db.rawQuery(
      '''
      SELECT
        x.tgl,
        x.name,
        SUM(x.setoran)   AS setoran,
        SUM(x.penarikan) AS penarikan,
        SUM(x.pinjaman)  AS pinjaman,
        SUM(x.cicilan)   AS cicilan
      FROM (
        SELECT
          date(s.transaction_date) AS tgl,
          m.name AS name,
          CASE WHEN s.type = 'deposit' THEN s.amount ELSE 0 END AS setoran,
          CASE WHEN s.type = 'withdrawal' THEN s.amount ELSE 0 END AS penarikan,
          0 AS pinjaman,
          0 AS cicilan
        FROM savings s
        JOIN members m ON m.id = s.member_id
        WHERE s.project_id = ?

        UNION ALL

        SELECT
          date(l.loan_date) AS tgl,
          m.name AS name,
          0 AS setoran,
          0 AS penarikan,
          l.total_amount AS pinjaman,
          0 AS cicilan
        FROM loans l
        JOIN members m ON m.id = l.member_id
        WHERE l.project_id = ?

        UNION ALL

        SELECT
          date(lp.payment_date) AS tgl,
          m.name AS name,
          0 AS setoran,
          0 AS penarikan,
          0 AS pinjaman,
          lp.amount AS cicilan
        FROM loan_payments lp
        JOIN loans l ON l.id = lp.loan_id
        JOIN members m ON m.id = l.member_id
        WHERE l.project_id = ?
      ) x
      GROUP BY x.tgl, x.name
      ORDER BY x.tgl DESC, x.name ASC
    ''',
      [projectId, projectId, projectId],
    );

    // Ambil 20 transaksi terakhir
    final recentSavings = await db.rawQuery(
      '''
      SELECT m.name, s.type, s.amount, s.transaction_date, s.note
      FROM savings s JOIN members m ON m.id = s.member_id
      WHERE s.project_id = ?
      ORDER BY s.transaction_date DESC LIMIT 20
    ''',
      [projectId],
    );

    final recentLoans = await db.rawQuery(
      '''
      SELECT
        m.name,
        l.total_amount,
        COALESCE((
          SELECT SUM(lp.amount)
          FROM loan_payments lp
          WHERE lp.loan_id = l.id
            AND (lp.note LIKE '%tabungan%')
        ), 0) AS paid_amount,
        l.status,
        l.loan_date
      FROM loans l JOIN members m ON m.id = l.member_id
      WHERE l.project_id = ?
      ORDER BY l.loan_date DESC LIMIT 20
    ''',
      [projectId],
    );

    // Build PDF
    final pdf = pw.Document();
    final now = DateFormat(
      'dd MMMM yyyy HH:mm',
      'id_ID',
    ).format(DateTime.now());

    // Warna
    const primaryColor = PdfColor.fromInt(0xFF1565C0);
    const errorColor = PdfColor.fromInt(0xFFC62828);
    const successColor = PdfColor.fromInt(0xFF2E7D32);
    const bgColor = PdfColor.fromInt(0xFFF5F5F5);

    // ── Halaman 1: Cover + Summary ──────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          final summary = summaryRows.isNotEmpty ? summaryRows.first : {};
          final totalSetoran =
              (summary['total_setoran'] as num?)?.toDouble() ?? 0;
          final totalPenarikan =
              (summary['total_penarikan'] as num?)?.toDouble() ?? 0;
          final totalDipinjam =
              (summary['total_dipinjam'] as num?)?.toDouble() ?? 0;
          final totalKembali =
              (summary['total_kembali'] as num?)?.toDouble() ?? 0;
          final danaDipinjam =
              (summary['dana_dipinjam_aktif'] as num?)?.toDouble() ?? 0;
          final danadiTangan =
              (summary['dana_di_tangan'] as num?)?.toDouble() ?? 0;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LAPORAN TABUNGAN',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      projectName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Dicetak: $now',
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xB3FFFFFF),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Ringkasan keuangan
              pw.Text(
                'RINGKASAN KEUANGAN',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _pdfStatBox(
                    'Total Setoran',
                    _fmt(totalSetoran),
                    successColor,
                    ctx,
                  ),
                  pw.SizedBox(width: 8),
                  _pdfStatBox(
                    'Total Penarikan',
                    _fmt(totalPenarikan),
                    errorColor,
                    ctx,
                  ),
                  pw.SizedBox(width: 8),
                  _pdfStatBox(
                    'Dana di Tangan',
                    _fmt(danadiTangan),
                    primaryColor,
                    ctx,
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _pdfStatBox(
                    'Pernah Dipinjam',
                    _fmt(totalDipinjam),
                    errorColor,
                    ctx,
                  ),
                  pw.SizedBox(width: 8),
                  _pdfStatBox(
                    'Sudah Kembali',
                    _fmt(totalKembali),
                    successColor,
                    ctx,
                  ),
                  pw.SizedBox(width: 8),
                  _pdfStatBox(
                    'Dipinjam Aktif',
                    _fmt(danaDipinjam),
                    errorColor,
                    ctx,
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Tabel member
              pw.Text(
                'REKAP PER ANGGOTA',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      _pdfTh('Nama Anggota'),
                      _pdfTh('Tabungan'),
                      _pdfTh('Hutang'),
                      _pdfTh('Saldo Efektif'),
                    ],
                  ),
                  // Data
                  ...memberRows.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    final savings =
                        (row['net_savings'] as num?)?.toDouble() ?? 0;
                    final hutang =
                        (row['sisa_hutang'] as num?)?.toDouble() ?? 0;
                    final saldo =
                        (row['saldo_efektif'] as num?)?.toDouble() ?? 0;
                    final isNeg = saldo < 0;
                    return pw.TableRow(
                      decoration: i.isEven
                          ? const pw.BoxDecoration(color: bgColor)
                          : null,
                      children: [
                        _pdfTd(row['name']?.toString() ?? ''),
                        _pdfTd(_fmt(savings)),
                        _pdfTd(
                          _fmt(hutang),
                          color: hutang > 0 ? PdfColors.grey900 : PdfColors.grey700,
                        ),
                        _pdfTd(
                          _fmt(saldo),
                          color: isNeg ? PdfColors.grey900 : PdfColors.grey900,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 18),
              pw.Text(
                'REKAP PER TANGGAL',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Format pivot: 1 baris per anggota, kolom per tanggal (Net = Setor + Cicil - Tarik - Pinjam).',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
              if (dateRecapRows.isEmpty)
                pw.Text('-', style: const pw.TextStyle(fontSize: 9))
              else
                (() {
                  // Ambil daftar tanggal (maks 7) dari rekap, urut desc
                  final dates = <String>[];
                  for (final row in dateRecapRows) {
                    final raw = row['tgl']?.toString();
                    if (raw == null || raw.isEmpty) continue;
                    if (!dates.contains(raw)) dates.add(raw);
                    if (dates.length >= 7) break;
                  }

                  // Map: memberName -> dateRaw -> net
                  final netMap = <String, Map<String, double>>{};
                  for (final row in dateRecapRows) {
                    final raw = row['tgl']?.toString() ?? '';
                    if (!dates.contains(raw)) continue;
                    final name = row['name']?.toString() ?? '';
                    final setoran = (row['setoran'] as num?)?.toDouble() ?? 0;
                    final penarikan = (row['penarikan'] as num?)?.toDouble() ?? 0;
                    final pinjaman = (row['pinjaman'] as num?)?.toDouble() ?? 0;
                    final cicilan = (row['cicilan'] as num?)?.toDouble() ?? 0;
                    final net = setoran + cicilan - penarikan - pinjaman;
                    (netMap[name] ??= {})[raw] = net;
                  }

                  // List anggota: dari memberRows supaya konsisten dengan rekap anggota
                  final memberNames = memberRows
                      .map((r) => r['name']?.toString() ?? '')
                      .where((s) => s.trim().isNotEmpty)
                      .toList();

                  final colWidths = <int, pw.TableColumnWidth>{
                    0: const pw.FlexColumnWidth(0.7), // No
                    1: const pw.FlexColumnWidth(2.2), // Anggota
                  };
                  for (int i = 0; i < dates.length; i++) {
                    colWidths[i + 2] = const pw.FlexColumnWidth(1.3);
                  }

                  return pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: colWidths,
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: primaryColor),
                        children: [
                          _pdfTh('No'),
                          _pdfTh('Anggota'),
                          ...dates.map((d) {
                            final label = _fmtDate(d);
                            // tampilkan versi pendek biar muat
                            final shortLabel = label.length > 6 ? label.substring(0, 6) : label;
                            return _pdfTh(shortLabel);
                          }),
                        ],
                      ),
                      ...memberNames.asMap().entries.map((e) {
                        final idx = e.key + 1;
                        final name = e.value;
                        final byDate = netMap[name] ?? const {};
                        return pw.TableRow(
                          decoration: idx.isEven ? const pw.BoxDecoration(color: bgColor) : null,
                          children: [
                            _pdfTd(idx.toString()),
                            _pdfTd(name),
                            ...dates.map((d) {
                              final v = byDate[d] ?? 0;
                              return _pdfTd(v == 0 ? '-' : _fmt(v));
                            }),
                          ],
                        );
                      }),
                    ],
                  );
                })(),
            ],
          );
        },
      ),
    );

    // ── Halaman 2: Riwayat Tabungan ─────────────────────────────
    if (recentSavings.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfPageHeader(projectName, 'RIWAYAT TABUNGAN (20 Terakhir)'),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      _pdfTh('Anggota'),
                      _pdfTh('Tipe'),
                      _pdfTh('Jumlah'),
                      _pdfTh('Tanggal'),
                      _pdfTh('Catatan'),
                    ],
                  ),
                  ...recentSavings.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    final isDeposit = row['type'] == 'deposit';
                    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                    return pw.TableRow(
                      decoration: i.isEven
                          ? const pw.BoxDecoration(color: bgColor)
                          : null,
                      children: [
                        _pdfTd(row['name']?.toString() ?? ''),
                        _pdfTd(
                          isDeposit ? 'Setor' : 'Tarik',
                          color: isDeposit ? successColor : errorColor,
                        ),
                        _pdfTd(
                          '${isDeposit ? '+' : '-'}${_fmt(amount)}',
                          color: isDeposit ? successColor : errorColor,
                        ),
                        _pdfTd(
                          _fmtDate(row['transaction_date']?.toString() ?? ''),
                        ),
                        _pdfTd(row['note']?.toString() ?? '-', fontSize: 8),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── Halaman 3: Riwayat Pinjaman ─────────────────────────────
    if (recentLoans.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfPageHeader(projectName, 'RIWAYAT PINJAMAN (20 Terakhir)'),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: primaryColor),
                    children: [
                      _pdfTh('Anggota'),
                      _pdfTh('Total Pinjam'),
                      _pdfTh('Terbayar'),
                      _pdfTh('Sisa'),
                      _pdfTh('Status'),
                      _pdfTh('Tgl Pinjam'),
                    ],
                  ),
                  ...recentLoans.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    final total =
                        (row['total_amount'] as num?)?.toDouble() ?? 0;
                    final paid = (row['paid_amount'] as num?)?.toDouble() ?? 0;
                    final sisa = total - paid;
                    final status = _statusLabel(
                      row['status']?.toString() ?? '',
                    );
                    final statusColor = _statusPdfColor(
                      row['status']?.toString() ?? '',
                    );
                    return pw.TableRow(
                      decoration: i.isEven
                          ? const pw.BoxDecoration(color: bgColor)
                          : null,
                      children: [
                        _pdfTd(row['name']?.toString() ?? ''),
                        _pdfTd(_fmt(total)),
                        _pdfTd(_fmt(paid), color: successColor),
                        _pdfTd(
                          _fmt(sisa),
                          color: sisa > 0 ? errorColor : successColor,
                        ),
                        _pdfTd(status, color: statusColor),
                        _pdfTd(_fmtDate(row['loan_date']?.toString() ?? '')),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'laporan_${projectName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Ekspor data 1 member ke CSV
  static Future<File> exportMemberCsv({required int memberId}) async {
    final db = await DatabaseHelper().database;

    final memberInfo = await db.rawQuery(
      '''
      SELECT m.id, m.name AS member_name, p.name AS project_name
      FROM members m JOIN projects p ON p.id = m.project_id
      WHERE m.id = ?
    ''',
      [memberId],
    );

    if (memberInfo.isEmpty) {
      throw Exception('Member tidak ditemukan');
    }

    final memberName = memberInfo.first['member_name']?.toString() ?? 'Member';
    final projectName =
        memberInfo.first['project_name']?.toString() ?? 'Project';

    final buffer = StringBuffer();
    buffer.writeln('Project,$projectName');
    buffer.writeln('Member,$memberName');
    buffer.writeln('Dicetak,${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(DateTime.now())}');
    buffer.writeln();

    buffer.writeln('=== TABUNGAN ===');
    buffer.writeln('Tipe,Jumlah,Tanggal,Catatan');
    final savings = await db.rawQuery(
      '''
      SELECT s.type, s.amount, s.transaction_date, s.note
      FROM savings s
      WHERE s.member_id = ?
      ORDER BY s.transaction_date DESC
    ''',
      [memberId],
    );
    for (final row in savings) {
      final tipe = row['type'] == 'deposit' ? 'Setor' : 'Tarik';
      final jumlah = (row['amount'] as num?)?.toDouble() ?? 0;
      final tgl = _fmtDate(row['transaction_date']?.toString() ?? '');
      final catatan = (row['note'] ?? '').toString().replaceAll(',', ';');
      buffer.writeln('$tipe,${jumlah.toStringAsFixed(0)},$tgl,$catatan');
    }

    buffer.writeln();
    buffer.writeln('=== PINJAMAN ===');
    buffer.writeln(
      'Pokok,Bunga(%),Total,Terbayar,Sisa,Status,Tanggal Pinjam,Jatuh Tempo,Catatan',
    );
    final loans = await db.rawQuery(
      '''
      SELECT
        l.amount,
        l.interest_rate,
        l.total_amount,
        COALESCE((
          SELECT SUM(lp.amount)
          FROM loan_payments lp
          WHERE lp.loan_id = l.id
            AND (lp.note LIKE '%tabungan%')
        ), 0) AS paid_amount,
        l.status,
        l.loan_date,
        l.due_date,
        l.note
      FROM loans l
      WHERE l.member_id = ?
      ORDER BY l.loan_date DESC
    ''',
      [memberId],
    );
    for (final row in loans) {
      final pokok = (row['amount'] as num?)?.toDouble() ?? 0;
      final bunga = (row['interest_rate'] as num?)?.toDouble() ?? 0;
      final total = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final bayar = (row['paid_amount'] as num?)?.toDouble() ?? 0;
      final sisa = total - bayar;
      final status = _statusLabel(row['status']?.toString() ?? '');
      final tglPinjam = _fmtDate(row['loan_date']?.toString() ?? '');
      final tglTempo = row['due_date'] != null
          ? _fmtDate(row['due_date'].toString())
          : '-';
      final catatan = (row['note'] ?? '').toString().replaceAll(',', ';');
      buffer.writeln(
        '${pokok.toStringAsFixed(0)},$bunga,${total.toStringAsFixed(0)},${bayar.toStringAsFixed(0)},${sisa.toStringAsFixed(0)},$status,$tglPinjam,$tglTempo,$catatan',
      );
    }

    buffer.writeln();
    buffer.writeln('=== CICILAN PINJAMAN ===');
    buffer.writeln('Jumlah Pinjaman,Cicilan,Tanggal Bayar,Catatan');
    final payments = await db.rawQuery(
      '''
      SELECT l.total_amount, lp.amount, lp.payment_date, lp.note
      FROM loan_payments lp
      JOIN loans l ON l.id = lp.loan_id
      WHERE l.member_id = ?
      ORDER BY lp.payment_date DESC
    ''',
      [memberId],
    );
    for (final row in payments) {
      final totalPinjam = (row['total_amount'] as num?)?.toDouble() ?? 0;
      final cicilan = (row['amount'] as num?)?.toDouble() ?? 0;
      final tgl = _fmtDate(row['payment_date']?.toString() ?? '');
      final catatan = (row['note'] ?? '').toString().replaceAll(',', ';');
      buffer.writeln(
        '${totalPinjam.toStringAsFixed(0)},${cicilan.toStringAsFixed(0)},$tgl,$catatan',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final safeMember = memberName.replaceAll(' ', '_');
    final fileName =
        'export_member_${safeMember}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(buffer.toString(), encoding: const Utf8Codec());
    return file;
  }

  /// Ekspor laporan 1 member ke PDF
  static Future<File> exportMemberPdf({required int memberId}) async {
    final db = await DatabaseHelper().database;

    final memberInfo = await db.rawQuery(
      '''
      SELECT m.id, m.name AS member_name, m.project_id, p.name AS project_name
      FROM members m JOIN projects p ON p.id = m.project_id
      WHERE m.id = ?
    ''',
      [memberId],
    );
    if (memberInfo.isEmpty) {
      throw Exception('Member tidak ditemukan');
    }

    final memberName = memberInfo.first['member_name']?.toString() ?? 'Member';
    final projectName =
        memberInfo.first['project_name']?.toString() ?? 'Project';

    final memberSummary = await db.rawQuery(
      '''
      SELECT
        COALESCE(vs.net_savings, 0)  AS net_savings,
        COALESCE(vl.sisa_hutang, 0)  AS sisa_hutang,
        COALESCE(vs.net_savings, 0) - COALESCE(vl.sisa_hutang, 0) AS saldo_efektif
      FROM members m
      LEFT JOIN v_member_savings vs ON vs.member_id = m.id
      LEFT JOIN v_member_loans   vl ON vl.member_id = m.id
      WHERE m.id = ?
      LIMIT 1
    ''',
      [memberId],
    );

    final savings = await db.rawQuery(
      '''
      SELECT s.type, s.amount, s.transaction_date, s.note
      FROM savings s
      WHERE s.member_id = ?
      ORDER BY s.transaction_date DESC
    ''',
      [memberId],
    );

    final loans = await db.rawQuery(
      '''
      SELECT
        l.total_amount,
        COALESCE((
          SELECT SUM(lp.amount)
          FROM loan_payments lp
          WHERE lp.loan_id = l.id
            AND (lp.note LIKE '%tabungan%')
        ), 0) AS paid_amount,
        l.status,
        l.loan_date,
        l.due_date,
        l.note
      FROM loans l
      WHERE l.member_id = ?
      ORDER BY l.loan_date DESC
    ''',
      [memberId],
    );

    final pdf = pw.Document();
    final now = DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(DateTime.now());
    const primaryColor = PdfColor.fromInt(0xFF1565C0);
    const errorColor = PdfColor.fromInt(0xFFC62828);
    const successColor = PdfColor.fromInt(0xFF2E7D32);
    const bgColor = PdfColor.fromInt(0xFFF5F5F5);

    final summary = memberSummary.isNotEmpty ? memberSummary.first : {};
    final netSavings = (summary['net_savings'] as num?)?.toDouble() ?? 0;
    final sisaHutang = (summary['sisa_hutang'] as num?)?.toDouble() ?? 0;
    final saldoEfektif = (summary['saldo_efektif'] as num?)?.toDouble() ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: const pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN MEMBER',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  memberName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Project: $projectName',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xB3FFFFFF),
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  'Dicetak: $now',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xB3FFFFFF),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'RINGKASAN',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _pdfStatBox('Tabungan Bersih', _fmt(netSavings), successColor, ctx),
              pw.SizedBox(width: 8),
              _pdfStatBox(
                'Sisa Hutang',
                _fmt(sisaHutang),
                sisaHutang > 0 ? errorColor : PdfColors.grey700,
                ctx,
              ),
              pw.SizedBox(width: 8),
              _pdfStatBox(
                'Saldo Efektif',
                _fmt(saldoEfektif),
                saldoEfektif < 0 ? errorColor : successColor,
                ctx,
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          pw.Text(
            'RIWAYAT TABUNGAN',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          if (savings.isEmpty)
            pw.Text('-', style: const pw.TextStyle(fontSize: 9))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primaryColor),
                  children: [
                    _pdfTh('Tipe'),
                    _pdfTh('Jumlah'),
                    _pdfTh('Tanggal'),
                    _pdfTh('Catatan'),
                  ],
                ),
                ...savings.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  final isDeposit = row['type'] == 'deposit';
                  final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                  return pw.TableRow(
                    decoration:
                        i.isEven ? const pw.BoxDecoration(color: bgColor) : null,
                    children: [
                      _pdfTd(
                        isDeposit ? 'Setor' : 'Tarik',
                        color: isDeposit ? successColor : errorColor,
                      ),
                      _pdfTd(
                        '${isDeposit ? '+' : '-'}${_fmt(amount)}',
                        color: isDeposit ? successColor : errorColor,
                      ),
                      _pdfTd(_fmtDate(row['transaction_date']?.toString() ?? '')),
                      _pdfTd(row['note']?.toString() ?? '-', fontSize: 8),
                    ],
                  );
                }),
              ],
            ),

          pw.SizedBox(height: 18),
          pw.Text(
            'RIWAYAT PINJAMAN',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          if (loans.isEmpty)
            pw.Text('-', style: const pw.TextStyle(fontSize: 9))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(2.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primaryColor),
                  children: [
                    _pdfTh('Total'),
                    _pdfTh('Terbayar'),
                    _pdfTh('Sisa'),
                    _pdfTh('Status'),
                    _pdfTh('Tanggal'),
                  ],
                ),
                ...loans.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  final total =
                      (row['total_amount'] as num?)?.toDouble() ?? 0;
                  final paid = (row['paid_amount'] as num?)?.toDouble() ?? 0;
                  final remain = total - paid;
                  final statusRaw = row['status']?.toString() ?? '';
                  return pw.TableRow(
                    decoration:
                        i.isEven ? const pw.BoxDecoration(color: bgColor) : null,
                    children: [
                      _pdfTd(_fmt(total)),
                      _pdfTd(_fmt(paid), color: successColor),
                      _pdfTd(
                        _fmt(remain),
                        color: remain > 0 ? errorColor : successColor,
                      ),
                      _pdfTd(
                        _statusLabel(statusRaw),
                        color: _statusPdfColor(statusRaw),
                      ),
                      _pdfTd(_fmtDate(row['loan_date']?.toString() ?? '')),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'laporan_member_${memberName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Share file menggunakan share_plus
  // static Future<void> shareFile(File file, {String? subject}) async {
  //   await Share.shareXFiles([
  //     XFile(file.path),
  //   ], subject: subject ?? 'Export Baitul Mal Plus');
  // }

  static Future<void> shareFile(
    BuildContext context,
    File file, {
    String? subject,
  }) async {
    if (Platform.isLinux) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File disimpan di:\n${file.path}'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Buka',
            onPressed: () async {
              await launchUrl(Uri.directory(file.parent.path));
            },
          ),
        ),
      );
      return;
    }

    await Share.shareXFiles([
      XFile(file.path),
    ], subject: subject ?? 'Export Baitul Mal Plus');
  }

  // ── Helpers ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _getRowsFiltered(
    Database db,
    String table,
    int projectId,
  ) async {
    if (table == 'loan_payments') {
      return db.rawQuery(
        '''
        SELECT lp.* FROM loan_payments lp
        JOIN loans l ON l.id = lp.loan_id
        WHERE l.project_id = ?
      ''',
        [projectId],
      );
    }
    return db.query(table, where: 'project_id = ?', whereArgs: [projectId]);
  }

  static String _statusLabel(String s) => switch (s) {
    'paid' => 'Lunas',
    'overdue' => 'Terlambat',
    _ => 'Aktif',
  };

  static PdfColor _statusPdfColor(String s) => switch (s) {
    'paid' => const PdfColor.fromInt(0xFF2E7D32),
    'overdue' => const PdfColor.fromInt(0xFFC62828),
    _ => const PdfColor.fromInt(0xFFE65100),
  };
}

// ── PDF widget helpers ─────────────────────────────────────────
pw.Widget _pdfStatBox(
  String label,
  String value,
  PdfColor color,
  pw.Context ctx,
) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _pdfTh(String text) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      color: PdfColors.white,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    ),
  ),
);

pw.Widget _pdfTd(String text, {PdfColor? color, double fontSize = 9}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: color ?? PdfColors.grey900,
        ),
      ),
    );

pw.Widget _pdfPageHeader(String project, String title) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      project,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF1565C0),
      ),
    ),
    pw.Text(
      title,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
    ),
    pw.Divider(color: const PdfColor.fromInt(0xFF1565C0)),
  ],
);
