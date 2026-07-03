// lib/modules/reports/providers/financial_reports_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

/// 🚀 كلاس فلترة التقارير مع تطبيق المساواة (Equality) لمنع حلقة التحميل اللانهائي في Riverpod
class CashFlowFilter {
  final String startDate;
  final String endDate;

  const CashFlowFilter({required this.startDate, required this.endDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashFlowFilter &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => startDate.hashCode ^ endDate.hashCode;
}

final agingReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getAgingReportData();
});

final cashFlowProvider = FutureProvider.family<Map<String, dynamic>, CashFlowFilter>((ref, filter) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getCashFlowStatement(
    startDate: filter.startDate,
    endDate: filter.endDate,
  );
});

final balanceSheetProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, asOfDate) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getBalanceSheet(asOfDate: asOfDate);
});
