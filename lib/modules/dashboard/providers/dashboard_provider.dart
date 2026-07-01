// lib/modules/dashboard/providers/dashboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

// 1. نموذج (Model) مخصص لحمل جميع بيانات لوحة التحكم
class DashboardData {
  final int totalProducts;
  final int totalSuppliers;
  final int totalCustomers;
  final double totalInventoryValue;
  final int lowStockCount;
  final int expiredCount;
  final double todaySales;
  final double monthSales;

  DashboardData({
    required this.totalProducts,
    required this.totalSuppliers,
    required this.totalCustomers,
    required this.totalInventoryValue,
    required this.lowStockCount,
    required this.expiredCount,
    required this.todaySales,
    required this.monthSales,
  });
}

// 2. المزود (Provider) الذي يجلب البيانات ويدمر نفسه عند الخروج (AutoDispose)
final dashboardProvider = AutoDisposeAsyncNotifierProvider<DashboardNotifier, DashboardData>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AutoDisposeAsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    return _fetchDashboardData();
  }

  Future<DashboardData> _fetchDashboardData() async {
    final db = ref.read(databaseHelperProvider);
    final cache = await db.getDashboardSummaryCache();

    return DashboardData(
      totalProducts: (cache['total_products'] as num?)?.toInt() ?? 0,
      totalSuppliers: (cache['total_suppliers'] as num?)?.toInt() ?? 0,
      totalCustomers: (cache['total_customers'] as num?)?.toInt() ?? 0,
      totalInventoryValue: (cache['total_inventory_value'] as num?)?.toDouble() ?? 0.0,
      lowStockCount: (cache['low_stock_count'] as num?)?.toInt() ?? 0,
      expiredCount: (cache['expired_products'] as num?)?.toInt() ?? 0,
      todaySales: (cache['today_sales'] as num?)?.toDouble() ?? 0.0,
      monthSales: (cache['month_sales'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // دالة لتحديث البيانات وإعادة حساب الكاش يدوياً من قاعدة البيانات
  Future<void> refreshDashboardSummary() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseHelperProvider);
      await db.updateDashboardSummary();
      return _fetchDashboardData();
    });
  }

  // دالة لتحديث البيانات يدوياً عند السحب (Pull to refresh)
  Future<void> refresh() async {
    await refreshDashboardSummary();
  }
}