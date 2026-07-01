import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/global_providers.dart';

class DashboardStats {
  final double todaySales;
  final double treasuryBalance;
  final double debtorsTotal;

  DashboardStats({
    required this.todaySales,
    required this.treasuryBalance,
    required this.debtorsTotal,
  });
}

final dashboardStatsProvider = AutoDisposeAsyncNotifierProvider<DashboardStatsNotifier, DashboardStats>(
  DashboardStatsNotifier.new,
);

class DashboardStatsNotifier extends AutoDisposeAsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    return _fetchStats();
  }

  Future<DashboardStats> _fetchStats() async {
    final db = ref.read(databaseHelperProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. مبيعات اليوم
    final salesResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_invoices WHERE date(date) = ?",
      [today],
    );
    final todaySales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. رصيد الخزينة (🚀 الطريقة الصحيحة: قراءة الرصيد المباشر من جدول الخزينة)
    final treasuryResult = await db.rawQuery(
      "SELECT balance FROM treasuries WHERE id = 1",
    );
    final treasuryBalance = treasuryResult.isNotEmpty ? (treasuryResult.first['balance'] as num).toDouble() : 0.0;

    // 3. إجمالي المدينين
    final debtorsResult = await db.rawQuery(
      "SELECT COALESCE(SUM(balance), 0) as total FROM customers WHERE balance > 0",
    );
    final debtorsTotal = (debtorsResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return DashboardStats(
      todaySales: todaySales,
      treasuryBalance: treasuryBalance,
      debtorsTotal: debtorsTotal,
    );
  }
}