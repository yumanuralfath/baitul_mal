// lib/presentation/core/widgets/date_picker_field.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPick;
  final bool required;

  const DatePickerField({
    super.key,
    required this.label,
    required this.date,
    required this.onPick,
    this.required = false,
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
      borderRadius: BorderRadius.circular(4),
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
