// lib/modules/reports/providers/financial_reports_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

final agingReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getAgingReportData();
});

final cashFlowProvider = FutureProvider.family<Map<String, dynamic>, Map<String, String>>((ref, dates) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getCashFlowStatement(
    startDate: dates['startDate'] ?? '2020-01-01',
    endDate: dates['endDate'] ?? '2030-12-31',
  );
});

final balanceSheetProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, asOfDate) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getBalanceSheet(asOfDate: asOfDate);
});
