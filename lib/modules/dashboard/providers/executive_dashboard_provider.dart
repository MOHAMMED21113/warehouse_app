// lib/modules/dashboard/providers/executive_dashboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

final executiveDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final sales = await db.getSalesSummary();
  final topCust = await db.getTopCustomers(5);
  final loanStats = await db.getLoanStatistics();
  final variance = await db.getInventoryVarianceReport();

  return {
    'sales_summary': sales,
    'top_customers': topCust,
    'loan_stats': loanStats,
    'inventory_variance': variance,
  };
});
