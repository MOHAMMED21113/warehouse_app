// lib/modules/reports/views/cash_flow_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  String _selectedFilterLabel = 'كل الفترات';

  void _setFilter(String label, String start, String end) {
    setState(() {
      _selectedFilterLabel = label;
      _startDate = start;
      _endDate = end;
    });
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: DateTime.tryParse(_startDate) ?? DateTime(now.year, 1, 1),
        end: DateTime.tryParse(_endDate) ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(picked.start);
      final endStr = DateFormat('yyyy-MM-dd').format(picked.end);
      _setFilter('فترة مخصصة', startStr, endStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filter = CashFlowFilter(startDate: _startDate, endDate: _endDate);
    final cashFlowAsync = ref.watch(cashFlowProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة التدفقات النقدية والسيولة'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🌟 شريط التصفية التفاعلي العصري المنسجم مع الثيم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'النطاق الزمني: $_selectedFilterLabel',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _selectCustomRange,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'تاريخ مخصص',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_calendar, size: 16, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الشهر الحالي', () {
                        final now = DateTime.now();
                        final start = DateFormat('yyyy-MM-01').format(now);
                        final end = DateFormat('yyyy-MM-dd').format(
                          DateTime(now.year, now.month + 1, 0),
                        );
                        _setFilter('الشهر الحالي', start, end);
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('السنة الحالية', () {
                        final now = DateTime.now();
                        _setFilter('السنة الحالية', '${now.year}-01-01', '${now.year}-12-31');
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('كل الفترات', () {
                        _setFilter('كل الفترات', '2020-01-01', '2030-12-31');
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📊 المحتوى الرئيسي
          Expanded(
            child: cashFlowAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحليل وتجميع حركات الخزينة والفواتير...',
                      style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 56),
                      const SizedBox(height: 16),
                      Text('حدث خطأ أثناء جلب التدفق النقدي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      Text(err.toString(), style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(cashFlowProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                final inflows = (data['total_inflows'] as num?)?.toDouble() ?? 0.0;
                final salesInflows = (data['sales_inflows'] as num?)?.toDouble() ?? 0.0;
                final voucherInflows = (data['voucher_inflows'] as num?)?.toDouble() ?? 0.0;

                final outflows = (data['total_outflows'] as num?)?.toDouble() ?? 0.0;
                final purchaseOutflows = (data['purchase_outflows'] as num?)?.toDouble() ?? 0.0;
                final voucherOutflows = (data['voucher_outflows'] as num?)?.toDouble() ?? 0.0;

                final netFlow = (data['net_cash_flow'] as num?)?.toDouble() ?? 0.0;

                return RefreshIndicator(
                  color: colorScheme.primary,
                  onRefresh: () async {
                    ref.invalidate(cashFlowProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 بطاقة Hero لملخص التدفق النقدي الصافي
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: netFlow >= 0
                                  ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
                                  : [AppColors.error, AppColors.error.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (netFlow >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  netFlow >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'صافي التدفق النقدي للفترة',
                                      style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${netFlow.toStringAsFixed(2)} ﷼',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      netFlow >= 0 ? 'فائض سيولة ممتاز في المستودع' : 'عجز مؤقت في التدفق النقدي',
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 📊 الرسم البياني التفاعلي الأنيق
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color ?? colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.bar_chart_rounded, color: colorScheme.primary, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'مقارنة التحصيلات والمصروفات',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 220,
                                child: _buildBarChart(inflows, outflows, netFlow, colorScheme),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 📈 بطاقة المقبوضات (التدفقات الداخلة)
                        _buildSectionCard(
                          title: 'المقبوضات والتدفقات الداخلة',
                          icon: Icons.south_west_rounded,
                          color: AppColors.success,
                          total: inflows,
                          theme: theme,
                          items: [
                            _buildDetailedItemRow(
                              title: 'التحصيلات ومبيعات الكاش',
                              value: salesInflows,
                              total: inflows,
                              color: AppColors.success,
                              theme: theme,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailedItemRow(
                              title: 'سندات القبض والإيرادات الأخرى',
                              value: voucherInflows,
                              total: inflows,
                              color: AppColors.primary,
                              theme: theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 📉 بطاقة المدفوعات (التدفقات الخارجة)
                        _buildSectionCard(
                          title: 'المدفوعات والتدفقات الخارجة',
                          icon: Icons.north_east_rounded,
                          color: AppColors.error,
                          total: outflows,
                          theme: theme,
                          items: [
                            _buildDetailedItemRow(
                              title: 'سداد الموردين ومشتريات الكاش',
                              value: purchaseOutflows,
                              total: outflows,
                              color: AppColors.error,
                              theme: theme,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailedItemRow(
                              title: 'سندات الصرف والمصروفات العامة',
                              value: voucherOutflows,
                              total: outflows,
                              color: AppColors.warning,
                              theme: theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedFilterLabel == label;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
    required double total,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} ﷼',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildDetailedItemRow({
    required String title,
    required double value,
    required double total,
    required Color color,
    required ThemeData theme,
  }) {
    final percentage = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${value.toStringAsFixed(2)} ﷼',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(double inflows, double outflows, double netFlow, ColorScheme colorScheme) {
    final maxY = [inflows, outflows, netFlow.abs()].reduce((a, b) => a > b ? a : b) * 1.25;
    final topLimit = maxY <= 0 ? 100.0 : maxY;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topLimit,
        minY: netFlow < 0 ? netFlow * 1.25 : 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: topLimit / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.onSurface.withValues(alpha: 0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppColors.navy,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label;
              switch (group.x.toInt()) {
                case 0:
                  label = 'المقبوضات';
                  break;
                case 1:
                  label = 'المدفوعات';
                  break;
                case 2:
                  label = 'الصافي';
                  break;
                default:
                  label = '';
              }
              return BarTooltipItem(
                '$label\n${rod.toY.toStringAsFixed(2)} ﷼',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('المقبوضات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                    );
                  case 1:
                    return const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('المدفوعات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                    );
                  case 2:
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('الصافي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: netFlow >= 0 ? AppColors.success : AppColors.error)),
                    );
                  default:
                    return const Text('');
                }
              },
            ),
          ),
        ),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: inflows,
                color: AppColors.success,
                width: 38,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: outflows,
                color: AppColors.error,
                width: 38,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: netFlow,
                color: netFlow >= 0 ? AppColors.success : AppColors.error,
                width: 38,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(netFlow >= 0 ? 8 : 0),
                  bottom: Radius.circular(netFlow < 0 ? 8 : 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
