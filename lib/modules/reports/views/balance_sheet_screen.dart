// lib/modules/reports/views/balance_sheet_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/financial_reports_provider.dart';

class BalanceSheetScreen extends ConsumerWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOfDate = DateTime.now().toIso8601String().substring(0, 10);
    final bsAsync = ref.watch(balanceSheetProvider(asOfDate));

    return Scaffold(
      appBar: AppBar(
        title: Text('الميزانية العمومية (كما في $asOfDate)'),
        centerTitle: true,
      ),
      body: bsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ في تحميل الميزانية: $err')),
        data: (data) {
          final assets = data['assets'] as Map<String, dynamic>? ?? {};
          final liab = data['liabilities'] as Map<String, dynamic>? ?? {};
          final equity = data['equity'] as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard('الأصول (Assets)', [
                  _row('النقد وما في حكمه (Cash)', (assets['cash'] as num?)?.toDouble() ?? 0),
                  _row('حسابات العملاء (Accounts Receivable)', (assets['accounts_receivable'] as num?)?.toDouble() ?? 0),
                  _row('المخزون السلعي (Inventory)', (assets['inventory'] as num?)?.toDouble() ?? 0),
                ], (assets['total'] as num?)?.toDouble() ?? 0, AppColors.success),
                const SizedBox(height: 16),
                _buildSectionCard('الخصوم والالتزامات (Liabilities)', [
                  _row('حسابات الموردين (Accounts Payable)', (liab['accounts_payable'] as num?)?.toDouble() ?? 0),
                  _row('سلف وقروض الموردين (Loans Payable)', (liab['loans'] as num?)?.toDouble() ?? 0),
                ], (liab['total'] as num?)?.toDouble() ?? 0, AppColors.error),
                const SizedBox(height: 16),
                _buildSectionCard('حقوق الملكية (Equity)', [
                  _row('الأرباح المحتجزة ورأس المال (Retained Earnings)', (equity['retained_earnings'] as num?)?.toDouble() ?? 0),
                ], (equity['total'] as num?)?.toDouble() ?? 0, AppColors.info),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String title, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${value.toStringAsFixed(2)} ﷼',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> rows, double total, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const Divider(),
            ...rows,
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('الإجمالي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Text('${total.toStringAsFixed(2)} ﷼', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
