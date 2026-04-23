// lib/data/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'baitul_mal.db'),
    );

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

    await db.close();

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
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'baitul_mal.db'),
    );

    final buffer = StringBuffer();

    // Header
    buffer.writeln('=== TABUNGAN ===');
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
      SELECT m.name, l.amount, l.interest_rate, l.total_amount,
             l.paid_amount, l.status, l.loan_date, l.due_date, l.note
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

    await db.close();

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'export_project_${projectId}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(buffer.toString(), encoding: const Utf8Codec());
    return file;
  }

  /// Ekspor laporan ke PDF
  static Future<File> exportPdf({required int projectId}) async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'baitul_mal.db'),
    );

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
      SELECT m.name, l.total_amount, l.paid_amount, l.status, l.loan_date
      FROM loans l JOIN members m ON m.id = l.member_id
      WHERE l.project_id = ?
      ORDER BY l.loan_date DESC LIMIT 20
    ''',
      [projectId],
    );

    await db.close();

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
                        _pdfTd(_fmt(savings), color: successColor),
                        _pdfTd(
                          _fmt(hutang),
                          color: hutang > 0 ? errorColor : PdfColors.grey700,
                        ),
                        _pdfTd(
                          _fmt(saldo),
                          color: isNeg ? errorColor : successColor,
                        ),
                      ],
                    );
                  }),
                ],
              ),
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

  /// Share file menggunakan share_plus
  static Future<void> shareFile(File file, {String? subject}) async {
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
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColor(color.red, color.green, color.blue, 0.08),
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
              color: color,
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
