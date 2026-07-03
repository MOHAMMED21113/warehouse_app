// lib/modules/loans/views/loans_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/loan_print_service.dart';
import '../providers/loans_provider.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة سلف العملاء والموردين', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'قيد التشغيل'),
            Tab(text: 'منتهية'),
            Tab(text: 'متأخرة'),
          ],
        ),
      ),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ في التحميل: $err')),
        data: (loans) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildLoansList(loans.where((l) => l['status'] != 'paid').toList()),
              _buildLoansList(loans.where((l) => l['status'] == 'paid').toList()),
              _buildLoansList(_filterOverdue(loans)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLoanDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('سلفة جديدة'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  List<Map<String, dynamic>> _filterOverdue(List<Map<String, dynamic>> loans) {
    final now = DateTime.now();
    return loans.where((l) {
      if (l['status'] == 'paid') return false;
      final due = l['due_date']?.toString();
      if (due == null || due.isEmpty) return false;
      try {
        return DateTime.parse(due).isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Widget _buildLoansList(List<Map<String, dynamic>> loans) {
    if (loans.isEmpty) {
      return const Center(
        child: Text('لا توجد سلف مسجلة في هذه القائمة', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return _buildLoanCard(loan);
      },
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final status = loan['status']?.toString() ?? 'active';
    final rem = (loan['remaining_balance'] as num?)?.toDouble() ?? 0.0;
    final total = (loan['amount'] as num?)?.toDouble() ?? 0.0;
    final type = loan['loan_type']?.toString() == 'customer' ? 'عميل' : 'مورد';

    Color cardBorder;
    if (status == 'paid') {
      cardBorder = AppColors.success;
    } else if (rem > 0) {
      cardBorder = AppColors.warning;
    } else {
      cardBorder = AppColors.error;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${loan['party_name']} ($type)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.print_rounded, color: AppColors.primary),
                  onPressed: () => _printLoanVoucher(loan),
                  tooltip: 'طباعة إذن السلفة',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ الأصلي: ${total.toStringAsFixed(2)} ﷼'),
                Text(
                  'المتبقي: ${rem.toStringAsFixed(2)} ﷼',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rem > 0 ? AppColors.error : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('تاريخ السلفة: ${loan['loan_date'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (loan['due_date'] != null)
              Text('تاريخ الاستحقاق: ${loan['due_date']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            if (rem > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context, loan),
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('سداد دفعة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddLoanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddLoanDialog(),
    );
  }

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (_) => _PaymentDialog(loan: loan),
    );
  }

  Future<void> _printLoanVoucher(Map<String, dynamic> loan) async {
    await LoanPrintService.printLoanVoucher(loan);
  }
}

class _AddLoanDialog extends ConsumerStatefulWidget {
  const _AddLoanDialog();

  @override
  ConsumerState<_AddLoanDialog> createState() => _AddLoanDialogState();
}

class _AddLoanDialogState extends ConsumerState<_AddLoanDialog> {
  String _loanType = 'customer';
  Map<String, dynamic>? _selectedParty;
  final _partySearchController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showDropdownList = false;

  @override
  void dispose() {
    _partySearchController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partyAsync = ref.watch(_loanType == 'customer' ? customersProvider : suppliersProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _loanType == 'customer' ? Icons.person_add_alt_1_rounded : Icons.local_shipping_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          const Text('إضافة سلفة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. نوع السلفة (SegmentedButton)
              const Text('1. نوع السلفة والطرف:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'customer', label: Text('سلفة عميل'), icon: Icon(Icons.person_outline_rounded)),
                  ButtonSegment(value: 'supplier', label: Text('سلفة مورد'), icon: Icon(Icons.store_outlined)),
                ],
                selected: {_loanType},
                onSelectionChanged: (set) {
                  setState(() {
                    _loanType = set.first;
                    _selectedParty = null;
                    _partySearchController.clear();
                    _showDropdownList = false;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.primary.withValues(alpha: 0.15);
                    return null;
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 2. اختيار الطرف (Searchable Dropdown)
              _buildSearchablePartyField(partyAsync),

              // 3. بطاقة تفاصيل الطرف (تظهر تلقائياً بعد الاختيار)
              if (_selectedParty != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedParty!['name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(child: Text('  الهاتف: ${_selectedParty!['phone']?.toString() ?? 'غير مسجل'}', style: const TextStyle(fontSize: 13))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(' الرصيد الحالي: ${_selectedParty!['balance'] ?? 0} ﷼', textAlign: TextAlign.left, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.warning))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('  العنوان: ${_selectedParty!['address']?.toString() ?? 'غير مسجل'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 4. المبلغ
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: '2. مبلغ السلفة (﷼)',
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.success),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // 5. تاريخ الاستحقاق
              TextField(
                controller: _dueDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '3. تاريخ الاستحقاق (اختياري)',
                  prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                  suffixIcon: _dueDateController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _dueDateController.clear()))
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() => _dueDateController.text = picked.toIso8601String().substring(0, 10));
                  }
                },
              ),
              const SizedBox(height: 12),

              // 6. تفاصيل إضافية / ملاحظات
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '4. تفاصيل إضافية / ملاحظات',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes_rounded)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final amt = double.tryParse(_amountController.text) ?? 0.0;
            if (amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من الصفر')));
              return;
            }
            if (_selectedParty == null && _partySearchController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار أو كتابة اسم الطرف')));
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            try {
              await ref.read(loansProvider.notifier).addLoan({
                'loan_type': _loanType,
                'party_id': _selectedParty?['id'] ?? 1,
                'party_name': _selectedParty?['name'] ?? _partySearchController.text.trim(),
                'amount': amt,
                'loan_date': DateTime.now().toIso8601String().substring(0, 10),
                'due_date': _dueDateController.text.isNotEmpty ? _dueDateController.text : null,
                'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                'status': 'active',
                'reference_number': 'LOAN-${DateTime.now().millisecondsSinceEpoch}',
              });
              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('تم حفظ السلفة بنجاح'), backgroundColor: AppColors.success));
              }
            } catch (e) {
              if (mounted) {
                final msg = e.toString().replaceAll('Exception: ', '');
                messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
              }
            }
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('حفظ السلفة'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSearchablePartyField(AsyncValue<List<Map<String, dynamic>>> partyAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _partySearchController,
          decoration: InputDecoration(
            labelText: _loanType == 'customer' ? 'ابحث عن اسم العميل...' : 'ابحث عن اسم المورد...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
            suffixIcon: _selectedParty != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                    onPressed: () => setState(() {
                      _selectedParty = null;
                      _partySearchController.clear();
                    }),
                  )
                : IconButton(
                    icon: Icon(_showDropdownList ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded),
                    onPressed: () => setState(() => _showDropdownList = !_showDropdownList),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) {
            if (!_showDropdownList) {
              setState(() => _showDropdownList = true);
            } else {
              setState(() {});
            }
          },
          onTap: () => setState(() => _showDropdownList = true),
        ),
        if (_showDropdownList && _selectedParty == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: partyAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (err, _) => Center(child: Padding(padding: const EdgeInsets.all(8), child: Text('خطأ: $err'))),
              data: (list) {
                final query = _partySearchController.text.trim().toLowerCase();
                final filtered = list.where((item) {
                  final name = (item['name'] ?? '').toString().toLowerCase();
                  return name.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لم يتم العثور على أطراف مطابقة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(_loanType == 'customer' ? Icons.person : Icons.local_shipping, color: AppColors.primary, size: 18),
                      ),
                      title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('الهاتف: ${item['phone'] ?? 'غير مسجل'}', style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        setState(() {
                          _selectedParty = item;
                          _partySearchController.text = item['name']?.toString() ?? '';
                          _showDropdownList = false;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PaymentDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> loan;
  const _PaymentDialog({required this.loan});

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  final _amountController = TextEditingController();
  String _method = 'نقدي';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('سداد دفعة لسلفة #${widget.loan['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'مبلغ السداد (﷼)',
                prefixIcon: const Icon(Icons.payment_rounded, color: AppColors.success),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _method,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'نقدي', child: Text('نقدي (Cash)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'تحويل', child: Text('تحويل بنكي (Bank Transfer)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'شيك', child: Text('شيك (Check)', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) => setState(() => _method = val!),
              decoration: InputDecoration(
                labelText: 'طريقة الدفع',
                prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.info),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
        ElevatedButton.icon(
          onPressed: () async {
            final amt = double.tryParse(_amountController.text) ?? 0.0;
            if (amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من الصفر')));
              return;
            }
            await ref.read(loansProvider.notifier).makePayment(widget.loan['id'], amt, _method);
            if (mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('تأكيد السداد'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}
