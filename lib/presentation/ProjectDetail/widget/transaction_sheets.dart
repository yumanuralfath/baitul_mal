// lib/presentation/project_detail/widgets/transaction_sheets.dart

import 'package:flutter/material.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/models/loan_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/core/helper/currency_input.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/amount_input_field.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/date_picker_field.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/sheet_handle.dart';

// ═══════════════════════════════════════════════════════════════
// ADD TRANSACTION SHEET (tabungan + pinjaman)
// ═══════════════════════════════════════════════════════════════
class TransactionSheet extends StatefulWidget {
  final MemberModel member;
  final ProjectModel project;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const TransactionSheet({
    super.key,
    required this.member,
    required this.project,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<TransactionSheet>
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
          SheetHandle(title: 'Transaksi — ${widget.member.name}'),
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'Tabungan'),
              Tab(text: 'Pinjaman'),
            ],
          ),
          SizedBox(
            height: 420,
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
          AmountInputField(controller: _savingAmountCtrl),
          const SizedBox(height: 12),
          DatePickerField(
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
          AmountInputField(
            controller: _loanAmountCtrl,
            label: 'Jumlah Pinjaman (Rp) *',
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
          DatePickerField(
            label: 'Tanggal Pinjam',
            date: _loanDate,
            onPick: (d) => setState(() => _loanDate = d),
          ),
          const SizedBox(height: 12),
          DatePickerField(
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
    final amount = parseFormattedAmount(_savingAmountCtrl.text);
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
    final amount = parseFormattedAmount(_loanAmountCtrl.text);
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
class EditSavingSheet extends StatefulWidget {
  final SavingModel saving;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const EditSavingSheet({
    super.key,
    required this.saving,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<EditSavingSheet> createState() => _EditSavingSheetState();
}

class _EditSavingSheetState extends State<EditSavingSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _type;
  late DateTime _date;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: formatThousands(widget.saving.amount.toInt()),
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
            SheetHandle(title: 'Edit Tabungan'),
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
                  AmountInputField(controller: _amountCtrl),
                  const SizedBox(height: 12),
                  DatePickerField(
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
    final amount = parseFormattedAmount(_amountCtrl.text);
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
class EditLoanSheet extends StatefulWidget {
  final LoanModel loan;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const EditLoanSheet({
    super.key,
    required this.loan,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<EditLoanSheet> createState() => _EditLoanSheetState();
}

class _EditLoanSheetState extends State<EditLoanSheet> {
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
      text: formatThousands(widget.loan.amount.toInt()),
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
            SheetHandle(title: 'Edit Pinjaman'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  AmountInputField(
                    controller: _amountCtrl,
                    label: 'Jumlah Pinjaman (Rp) *',
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
                  DatePickerField(
                    label: 'Tanggal Pinjam',
                    date: _loanDate,
                    onPick: (d) => setState(() => _loanDate = d),
                  ),
                  const SizedBox(height: 12),
                  DatePickerField(
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
    final amount = parseFormattedAmount(_amountCtrl.text);
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
