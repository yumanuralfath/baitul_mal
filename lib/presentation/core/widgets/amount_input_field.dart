// lib/presentation/core/widgets/amount_input_field.dart

import 'package:baitul_mal_plus/core/helper/currency_input.dart';
import 'package:flutter/material.dart';

/// TextField jumlah uang dengan:
/// - Auto titik ribuan saat ketik
/// - Suggestion chip: ketik "5" → 5.000 / 50.000 / 500.000 / 5.000.000
class AmountInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;

  const AmountInputField({
    super.key,
    required this.controller,
    this.label = 'Jumlah (Rp) *',
    this.autofocus = false,
  });

  @override
  State<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends State<AmountInputField> {
  List<int> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final raw = widget.controller.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .trim();
    final suggestions = generateAmountSuggestions(raw);
    if (mounted) {
      setState(() => _suggestions = suggestions);
    }
  }

  void _applySuggestion(int value) {
    final formatted = formatThousands(value);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            prefixText: 'Rp ',
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() => _suggestions = []);
                    },
                  )
                : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorInputFormatter()],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestions.map((val) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _applySuggestion(val),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        formatThousands(val),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
