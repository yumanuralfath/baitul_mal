import 'package:flutter/material.dart';
import 'package:baitul_mal_plus/domain/models/member_model.dart';
import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:baitul_mal_plus/domain/models/saving_model.dart';
import 'package:baitul_mal_plus/domain/repositories/member_repository.dart';
import 'package:baitul_mal_plus/core/helper/currency_input.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/amount_input_field.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/date_picker_field.dart';
import 'package:baitul_mal_plus/presentation/core/widgets/sheet_handle.dart';

class BatchTransactionSheet extends StatefulWidget {
  final List<MemberModel> members;
  final ProjectModel project;
  final MemberRepository repo;
  final VoidCallback onSuccess;

  const BatchTransactionSheet({
    super.key,
    required this.members,
    required this.project,
    required this.repo,
    required this.onSuccess,
  });

  @override
  State<BatchTransactionSheet> createState() => _BatchTransactionSheetState();
}

class _BatchTransactionSheetState extends State<BatchTransactionSheet> {
  final Map<int, TextEditingController> _controllers = {};
  final _commonNoteCtrl = TextEditingController();
  final _defaultAmountCtrl = TextEditingController();
  
  DateTime _date = DateTime.now();
  String _type = 'deposit';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    for (final m in widget.members) {
      _controllers[m.id!] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _commonNoteCtrl.dispose();
    _defaultAmountCtrl.dispose();
    super.dispose();
  }

  void _applyDefaultAmount() {
    final val = _defaultAmountCtrl.text;
    if (val.isEmpty) return;
    setState(() {
      for (final ctrl in _controllers.values) {
        ctrl.text = val;
      }
    });
  }

  Future<void> _submit() async {
    final List<SavingModel> batch = [];
    final note = _commonNoteCtrl.text.trim();

    for (final m in widget.members) {
      final amount = parseFormattedAmount(_controllers[m.id!]!.text);
      if (amount != null && amount > 0) {
        batch.add(SavingModel(
          projectId: widget.project.id!,
          memberId: m.id!,
          amount: amount,
          type: _type,
          note: note.isEmpty ? 'Batch Transaction' : note,
          transactionDate: _date,
        ));
      }
    }

    if (batch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada transaksi untuk disimpan')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.repo.addSavingsBatch(batch);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil menyimpan ${batch.length} transaksi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(title: 'Tambah Transaksi Batch'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatePickerField(
                    label: 'Tanggal Transaksi',
                    date: _date,
                    onPick: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 12),
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
                  TextField(
                    controller: _commonNoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Umum (opsional)',
                      hintText: 'Misal: Simpanan Wajib Juni',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AmountInputField(
                          controller: _defaultAmountCtrl,
                          label: 'Set semua jumlah (Rp)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: IconButton.filledTonal(
                          onPressed: _applyDefaultAmount,
                          icon: const Icon(Icons.copy_all),
                          tooltip: 'Terapkan ke semua',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Daftar Member',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.members.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              m.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: AmountInputField(
                              controller: _controllers[m.id!]!,
                              label: 'Jumlah (Rp)',
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 100), // Space for button
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Semua Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
