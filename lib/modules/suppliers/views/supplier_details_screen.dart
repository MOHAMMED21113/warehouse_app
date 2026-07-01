// lib/modules/suppliers/views/supplier_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../loans/providers/loans_provider.dart';
import '../../loans/widgets/loan_card.dart';

class SupplierDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> supplier;
  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  ConsumerState<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends ConsumerState<SupplierDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _supplierLoans = [];
  bool _isLoadingLoans = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSupplierLoans();
  }

  Future<void> _loadSupplierLoans() async {
    setState(() => _isLoadingLoans = true);
    final db = ref.read(databaseHelperProvider);
    final loans = await db.getSupplierLoanHistory(widget.supplier['id'] as int);
    if (mounted) {
      setState(() {
        _supplierLoans = loans;
        _isLoadingLoans = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = (widget.supplier['balance'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier['name']?.toString() ?? 'تفاصيل المورد'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.business_outlined), text: 'المعلومات والرصيد'),
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'سلف المورد'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(balance),
          _buildLoansTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddLoanDialog,
              icon: const Icon(Icons.add),
              label: const Text('سلفة جديدة للمورد'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildInfoTab(double balance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.business, color: Colors.white),
                    ),
                    title: Text(widget.supplier['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(widget.supplier['phone']?.toString() ?? 'لا يوجد رقم هاتف'),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الرصيد التجاري للمورد:', style: TextStyle(fontSize: 16)),
                      Text(
                        '${balance.toStringAsFixed(2)} ﷼',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: balance > 0 ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab() {
    if (_isLoadingLoans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_supplierLoans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('لا توجد سلف مسجلة لهذا المورد', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddLoanDialog,
              icon: const Icon(Icons.add),
              label: const Text('إضافة أول سلفة'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSupplierLoans,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _supplierLoans.length,
        itemBuilder: (context, index) {
          final loan = _supplierLoans[index];
          return LoanCard(
            loan: loan,
            onPaymentPressed: () => _showPaymentDialog(loan),
          );
        },
      ),
    );
  }

  void _showAddLoanDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('إضافة سلفة للمورد: ${widget.supplier['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'مبلغ السلفة (﷼)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text) ?? 0.0;
              if (amt <= 0) return;
              await ref.read(loansProvider.notifier).addLoan({
                'loan_type': 'supplier',
                'party_id': widget.supplier['id'],
                'party_name': widget.supplier['name'],
                'amount': amt,
                'loan_date': DateTime.now().toIso8601String().substring(0, 10),
                'status': 'active',
                'notes': notesController.text,
                'reference_number': 'SUPP-LOAN-${DateTime.now().millisecondsSinceEpoch}',
              });
              if (mounted) {
                Navigator.pop(context);
                _loadSupplierLoans();
              }
            },
            child: const Text('حفظ السلفة'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Map<String, dynamic> loan) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('سداد دفعة للمورد سلفة #${loan['id']}'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'مبلغ السداد (﷼)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text) ?? 0.0;
              if (amt <= 0) return;
              await ref.read(loansProvider.notifier).makePayment(loan['id'] as int, amt, 'تحويل بنكي');
              if (mounted) {
                Navigator.pop(context);
                _loadSupplierLoans();
              }
            },
            child: const Text('تأكيد السداد'),
          ),
        ],
      ),
    );
  }
}
