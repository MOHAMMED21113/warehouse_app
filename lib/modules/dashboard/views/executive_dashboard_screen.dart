// lib/modules/dashboard/views/executive_dashboard_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/executive_dashboard_provider.dart';

class ExecutiveDashboardScreen extends ConsumerWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(executiveDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم التنفيذية (Executive Dashboard)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ في تحميل مؤشرات الأداء: $err')),
        data: (data) {
          final sales = data['sales_summary'] as Map<String, dynamic>? ?? {};
          final topCust = (data['top_customers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final loans = data['loan_stats'] as Map<String, dynamic>? ?? {};

          final totalSales = (sales['total_sales'] as num?)?.toDouble() ?? 0.0;
          final totalProfit = (sales['total_profit'] as num?)?.toDouble() ?? 0.0;
          final activeLoans = (loans['total_remaining'] as num?)?.toDouble() ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(executiveDashboardProvider),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مؤشرات الأداء الرئيسية (KPIs)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _kpiCard('إجمالي المبيعات', '${totalSales.toStringAsFixed(0)} ﷼', Icons.trending_up, AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _kpiCard('إجمالي الأرباح', '${totalProfit.toStringAsFixed(0)} ﷼', Icons.monetization_on, AppColors.info)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _kpiCard('السلف المتبقية', '${activeLoans.toStringAsFixed(0)} ﷼', Icons.account_balance_wallet, AppColors.warning)),
                      const SizedBox(width: 12),
                      Expanded(child: _kpiCard('حالة النظام', 'جاهز ومتزامن', Icons.verified, AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('توزيع المبيعات والأرباح (Pie Chart)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(value: totalProfit > 0 ? totalProfit : 30, color: AppColors.success, title: 'ربح', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          PieChartSectionData(value: totalSales > totalProfit ? (totalSales - totalProfit) : 70, color: AppColors.primary, title: 'تكلفة', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('أفضل العملاء مساهمة في المبيعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...topCust.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.star, color: Colors.amber)),
                          title: Text(c['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text('${c['total_spent']} ﷼', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success)),
                        ),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.4))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
