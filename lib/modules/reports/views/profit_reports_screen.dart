// lib/modules/reports/views/profit_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // 💡 مكتبة الرسم البياني
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/profit_reports_provider.dart';

class ProfitReportsScreen extends ConsumerWidget {
  const ProfitReportsScreen({super.key});

  String _formatNum(double v) => NumberFormat('#,##0.00', 'en_US').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profitReportsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colors = AppThemeColors(isDark: isDark);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('التحليل المالي وذكاء الأعمال', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.success.withOpacity(0.6), AppColors.navy]))),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.success)),
        error: (err, _) => Center(child: Text('حدث خطأ في تحميل البيانات: $err', style: const TextStyle(color: AppColors.error))),
        data: (s) {
          if (s.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(s.errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(profitReportsProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(profitReportsProvider.notifier).refresh(),
            color: AppColors.success,
            child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilterChips(ref, s.filterPeriod, colors),
              const SizedBox(height: 20),

              // 1. بطاقات المؤشرات (KPIs)
              _buildKPICards(s.kpis, colors),
              const SizedBox(height: 24),

              // 2. الرسم البياني الخطي (مسار المبيعات)
              Text('مسار المبيعات (${s.filterPeriod == 'week' ? 'آخر 7 أيام' : s.filterPeriod == 'month' ? 'هذا الشهر' : 'هذا العام'})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textMain)),
              const SizedBox(height: 12),
              _buildLineChart(s.trendData, colors),
              const SizedBox(height: 24),

              // 3. المخطط الدائري (تحليل هيكل التكاليف والأرباح)
              Text('الهيكل المالي والنسب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textMain)),
              const SizedBox(height: 12),
              _buildPieChart(s.kpis, colors),
              const SizedBox(height: 30),
            ],
          ),
        );
        },
      ),
    );
  }

  // === 1. فلتر الفترات ===
  Widget _buildFilterChips(WidgetRef ref, String activeFilter, AppThemeColors colors) {
    return Row(
      children: [
        _filterBtn('week', 'آخر 7 أيام', activeFilter, ref, colors),
        const SizedBox(width: 8),
        _filterBtn('month', 'هذا الشهر', activeFilter, ref, colors),
        const SizedBox(width: 8),
        _filterBtn('year', 'هذا العام', activeFilter, ref, colors),
      ],
    );
  }

  Widget _filterBtn(String value, String label, String active, WidgetRef ref, AppThemeColors colors) {
    final isActive = value == active;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(profitReportsProvider.notifier).setFilter(value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.success.withOpacity(0.15) : colors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? AppColors.success : colors.cardBorder),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? AppColors.success : colors.textSub)),
        ),
      ),
    );
  }

  // === 2. بطاقات المؤشرات الرئيسية (KPIs) ===
  Widget _buildKPICards(Map<String, double> kpis, AppThemeColors colors) {
    return Column(
      children: [
        // صافي الربح (البطاقة الكبرى)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              const Text('صافي الأرباح (النهائي)', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${_formatNum(kpis['net_profit'] ?? 0)} ﷼', style: TextStyle(color: (kpis['net_profit'] ?? 0) >= 0 ? Colors.white : AppColors.error, fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // بطاقات المبيعات والتكاليف
        Row(
          children: [
            Expanded(child: _kpiCard('إجمالي المبيعات', kpis['total_sales'] ?? 0, Icons.trending_up_rounded, AppColors.success, colors)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('تكلفة البضاعة', kpis['total_cogs'] ?? 0, Icons.inventory_2_rounded, const Color(0xFFF97316), colors)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _kpiCard('المصروفات', kpis['total_expenses'] ?? 0, Icons.money_off_rounded, AppColors.error, colors)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('مرتجعات المبيعات', kpis['total_returns'] ?? 0, Icons.assignment_return_rounded, AppColors.warning, colors)),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String title, double value, IconData icon, Color color, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: colors.textSub), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text(_formatNum(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textMain)),
        ],
      ),
    );
  }

  // === 3. الرسم البياني الخطي (Line Chart) ===
  Widget _buildLineChart(List<Map<String, dynamic>> trendData, AppThemeColors colors) {
    if (trendData.isEmpty) {
      return Container(height: 200, decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)), alignment: Alignment.center, child: Text('لا توجد بيانات مبيعات لهذه الفترة', style: TextStyle(color: colors.textSub)));
    }

    // تجهيز نقاط الرسم
    List<FlSpot> spots = [];
    double maxY = 0;
    for (int i = 0; i < trendData.length; i++) {
      double sales = (trendData[i]['daily_sales'] as num).toDouble();
      if (sales > maxY) maxY = sales;
      spots.add(FlSpot(i.toDouble(), sales));
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY == 0 ? 1 : maxY / 4, getDrawingHorizontalLine: (value) => FlLine(color: colors.dividerColor, strokeWidth: 1)),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: trendData.length > 7 ? (trendData.length / 5).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < trendData.length) {
                    String date = trendData[idx]['day_date'].toString();
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(date.substring(8, 10), style: TextStyle(color: colors.textHint, fontSize: 10)));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(NumberFormat.compact().format(value), style: TextStyle(color: colors.textHint, fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: (trendData.length - 1).toDouble(),
          minY: 0, maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.success,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: trendData.length <= 15), // إظهار النقاط إذا كانت الأيام قليلة
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.3), AppColors.success.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === 4. المخطط الدائري (Pie Chart) ===
  Widget _buildPieChart(Map<String, double> kpis, AppThemeColors colors) {
    final double netProfit = kpis['net_profit'] ?? 0;
    final double cogs = kpis['total_cogs'] ?? 0;
    final double exp = kpis['total_expenses'] ?? 0;

    // إذا لم يكن هناك أي حركة مالية
    if (netProfit <= 0 && cogs == 0 && exp == 0) {
      return Container(height: 200, decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)), alignment: Alignment.center, child: Text('لا توجد بيانات كافية للهيكل المالي', style: TextStyle(color: colors.textSub)));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    if (netProfit > 0) PieChartSectionData(color: AppColors.primary, value: netProfit, title: 'ربح', radius: 40, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy)),
                    if (cogs > 0) PieChartSectionData(color: const Color(0xFFF97316), value: cogs, title: 'تكلفة', radius: 35, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (exp > 0) PieChartSectionData(color: AppColors.error, value: exp, title: 'مصروف', radius: 35, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _indicator('صافي الربح', AppColors.primary, colors),
              const SizedBox(height: 8),
              _indicator('تكلفة البضاعة', const Color(0xFFF97316), colors),
              const SizedBox(height: 8),
              _indicator('المصروفات', AppColors.error, colors),
            ],
          )
        ],
      ),
    );
  }

  Widget _indicator(String title, Color color, AppThemeColors colors) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 12, color: colors.textMain)),
      ],
    );
  }
}