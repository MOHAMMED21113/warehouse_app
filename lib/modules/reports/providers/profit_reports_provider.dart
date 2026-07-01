// lib/modules/reports/providers/profit_reports_provider.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';

class ProfitReportsState {
  final String filterPeriod; // 'week', 'month', 'year'
  final Map<String, double> kpis;
  final List<Map<String, dynamic>> trendData;
  final bool isLoading;
  final String? errorMessage;

  const ProfitReportsState({
    this.filterPeriod = 'month',
    this.kpis = const {},
    this.trendData = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  ProfitReportsState copyWith({
    String? filterPeriod,
    Map<String, double>? kpis,
    List<Map<String, dynamic>>? trendData,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfitReportsState(
      filterPeriod: filterPeriod ?? this.filterPeriod,
      kpis: kpis ?? this.kpis,
      trendData: trendData ?? this.trendData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final profitReportsProvider = AsyncNotifierProvider.autoDispose<ProfitReportsNotifier, ProfitReportsState>(
  ProfitReportsNotifier.new,
);

class ProfitReportsNotifier extends AutoDisposeAsyncNotifier<ProfitReportsState> {
  @override
  Future<ProfitReportsState> build() async {
    return await _fetchData('month'); // الافتراضي: هذا الشهر
  }

  Future<ProfitReportsState> _fetchData(String period) async {
    final db = ref.read(databaseHelperProvider);
    final now = DateTime.now();
    late DateTime start;
    final end = now;

    if (period == 'week') {
      start = now.subtract(const Duration(days: 6));
    } else if (period == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else { // year
      start = DateTime(now.year, 1, 1);
    }

    final startDateStr = DateFormat('yyyy-MM-dd').format(start);
    final endDateStr = DateFormat('yyyy-MM-dd').format(end);

    try {
      final kpis = await db.getFinancialKPIs(startDate: startDateStr, endDate: endDateStr);
      final trend = await db.getDailyProfitTrend(startDate: startDateStr, endDate: endDateStr);

      return ProfitReportsState(
        filterPeriod: period,
        kpis: kpis,
        trendData: trend,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error fetching profit reports: $e');
      return ProfitReportsState(
        filterPeriod: period,
        isLoading: false,
        errorMessage: 'عذراً، تعذر جلب التقرير بسبب حجم البيانات الكبير. حاول تقليل الفترة الزمنية.',
      );
    }
  }

  Future<void> setFilter(String period) async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchData(period));
  }

  Future<void> refresh() async {
    if (state.hasValue) {
      state = const AsyncValue.loading();
      state = AsyncValue.data(await _fetchData(state.value!.filterPeriod));
    }
  }
}