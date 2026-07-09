// lib/modules/dashboard/providers/executive_dashboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

final executiveDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final results = await Future.wait([
    db.getSalesSummary(),
    db.getTopCustomers(5),
    db.getLoanStatistics(),
    db.getInventoryVarianceReport(),
  ]);

  return {
    'sales_summary': results[0],
    'top_customers': results[1],
    'loan_stats': results[2],
    'inventory_variance': results[3],
  };
});
