// lib/presentation/core/utils/currency_input.dart

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter yang otomatis menambahkan titik ribuan saat input
/// Contoh: "5000" → "5.000", "1500000" → "1.500.000"
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Hapus semua titik/koma yang ada
    final raw = newValue.text.replaceAll('.', '').replaceAll(',', '');

    // Pastikan hanya angka
    if (!RegExp(r'^\d+$').hasMatch(raw)) return oldValue;

    // Format dengan titik ribuan
    final number = int.tryParse(raw);
    if (number == null) return oldValue;

    final formatted = _formatter.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Mengambil nilai numerik bersih dari string berformat
/// "1.500.000" → 1500000.0
double? parseFormattedAmount(String text) {
  final clean = text.replaceAll('.', '').replaceAll(',', '').trim();
  return double.tryParse(clean);
}

/// Generate suggestion berdasarkan input digit awal
/// "5"  → [5000, 50000, 500000, 5000000]
/// "25" → [25000, 250000, 2500000]
/// "1"  → [1000, 10000, 100000, 1000000]
List<int> generateAmountSuggestions(String rawDigits) {
  if (rawDigits.isEmpty) return [];

  // Hapus titik dari input
  final digits = rawDigits.replaceAll('.', '').replaceAll(',', '');
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) return [];

  final base = int.tryParse(digits);
  if (base == null || base == 0) return [];

  final results = <int>[];
  final digitsLength = digits.length;

  // Dari 3 nol sampai 7 nol (1.000 hingga 10.000.000)
  for (int zeros = 3; zeros <= 7; zeros++) {
    final multiplier = _pow10(zeros - (digitsLength - 1));
    if (multiplier < 1) continue;
    final candidate = (base * multiplier / 10).round() * 10;
    // Pastikan >= 1000 dan tidak duplikat
    if (candidate >= 1000 && !results.contains(candidate)) {
      // Pastikan prefix masih cocok dengan input
      final candidateStr = candidate.toString();
      if (candidateStr.startsWith(digits)) {
        results.add(candidate);
      }
    }
  }

  // Alternatif: kalkulasi lebih simpel dan reliable
  if (results.isEmpty) {
    // Coba pendekatan berbeda: tambahkan 0 sampai minimal 4 digit
    for (int extra = 0; extra <= 4; extra++) {
      final val = int.parse(digits + '0' * extra);
      if (val >= 1000 && !results.contains(val)) {
        results.add(val);
      }
      if (results.length >= 4) break;
    }
  }

  results.sort();
  return results.take(4).toList();
}

double _pow10(int exp) {
  double result = 1;
  for (int i = 0; i < exp; i++) {
    result *= 10;
  }
  return result;
}

/// Format angka dengan titik ribuan (tanpa simbol mata uang)
/// 1500000 → "1.500.000"
String formatThousands(int value) {
  return NumberFormat('#,###', 'id_ID').format(value);
}
