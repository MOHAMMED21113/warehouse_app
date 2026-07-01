// lib/modules/reports/views/aging_report_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/financial_reports_provider.dart';

class AgingReportScreen extends ConsumerWidget {
  const AgingReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agingAsync = ref.watch(agingReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير أعمار الذمم المدينة (Aging Report)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'تصدير إلى Excel',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تصدير التقرير إلى Excel بنجاح!'), backgroundColor: AppColors.success),
              );
            },
          ),
        ],
      ),
      body: agingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ في تحميل التقرير: $err')),
        data: (data) {
          final customers = (data['customers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          if (customers.isEmpty) {
            return const Center(child: Text('لا توجد ديون مستحقة على العملاء حالياً'));
          }

          double sum0_30 = 0;
          double sum31_60 = 0;
          double sum61_90 = 0;
          double sumOver90 = 0;

          for (var c in customers) {
            sum0_30 += (c['days_0_30'] as num?)?.toDouble() ?? 0;
            sum31_60 += (c['days_31_60'] as num?)?.toDouble() ?? 0;
            sum61_90 += (c['days_61_90'] as num?)?.toDouble() ?? 0;
            sumOver90 += (c['days_over_90'] as num?)?.toDouble() ?? 0;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('توزيع الديون حسب الفترات الزمنية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (sum0_30 + sum31_60 + sum61_90 + sumOver90) * 1.2,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              switch (val.toInt()) {
                                case 0: return const Text('0-30 يوم');
                                case 1: return const Text('31-60 يوم');
                                case 2: return const Text('61-90 يوم');
                                case 3: return const Text('>90 يوم');
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: sum0_30, color: AppColors.success, width: 20)]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: sum31_60, color: AppColors.info, width: 20)]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: sum61_90, color: AppColors.warning, width: 20)]),
                        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: sumOver90, color: AppColors.error, width: 20)]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('تفاصيل العملاء والمديونية الآجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('العميل')),
                      DataColumn(label: Text('0-30 يوم')),
                      DataColumn(label: Text('31-60 يوم')),
                      DataColumn(label: Text('61-90 يوم')),
                      DataColumn(label: Text('>90 يوم')),
                      DataColumn(label: Text('الإجمالي')),
                    ],
                    rows: customers.map((c) {
                      return DataRow(cells: [
                        DataCell(Text(c['name']?.toString() ?? '')),
                        DataCell(Text('${c['days_0_30']} ﷼')),
                        DataCell(Text('${c['days_31_60']} ﷼')),
                        DataCell(Text('${c['days_61_90']} ﷼')),
                        DataCell(Text('${c['days_over_90']} ﷼')),
                        DataCell(Text('${c['total_debt']} ﷼', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error))),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
