// lib/modules/reports/views/cash_flow_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/financial_reports_provider.dart';

class CashFlowScreen extends ConsumerStatefulWidget {
  const CashFlowScreen({super.key});

  @override
  ConsumerState<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends ConsumerState<CashFlowScreen> {
  String _startDate = '2020-01-01';
  String _endDate = '2030-12-31';

  @override
  Widget build(BuildContext context) {
    final cashFlowAsync = ref.watch(cashFlowProvider({'startDate': _startDate, 'endDate': _endDate}));

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة التدفقات النقدية (Cash Flow Statement)'),
        centerTitle: true,
      ),
      body: cashFlowAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ في تحميل التدفق النقدي: $err')),
        data: (data) {
          final inflows = (data['total_inflows'] as num?)?.toDouble() ?? 0.0;
          final outflows = (data['total_outflows'] as num?)?.toDouble() ?? 0.0;
          final netFlow = (data['net_cash_flow'] as num?)?.toDouble() ?? 0.0;

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
                        _itemRow('إجمالي التدفقات الداخلة (المقبوضات والمبيعات النقدية):', inflows, AppColors.success),
                        const Divider(),
                        _itemRow('إجمالي التدفقات الخارجة (المدفوعات والمشتريات النقدية):', outflows, AppColors.error),
                        const Divider(),
                        _itemRow('صافي التدفق النقدي للفترة:', netFlow, netFlow >= 0 ? AppColors.success : AppColors.error, isBold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('الرسم البياني للتدفق النقدي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            const FlSpot(0, 0),
                            FlSpot(1, inflows),
                            FlSpot(2, outflows),
                            FlSpot(3, netFlow),
                          ],
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _itemRow(String title, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(
            '${value.toStringAsFixed(2)} ﷼',
            style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
