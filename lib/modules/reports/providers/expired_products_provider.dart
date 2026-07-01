// lib/modules/reports/providers/expired_products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class ExpiredProductsState {
  final List<Map<String, dynamic>> expiredProducts;
  final List<Map<String, dynamic>> expiringSoonProducts;
  const ExpiredProductsState({
    this.expiredProducts = const [],
    this.expiringSoonProducts = const [],
  });
}

final expiredProductsProvider =
AutoDisposeAsyncNotifierProvider<ExpiredProductsNotifier, ExpiredProductsState>(
  ExpiredProductsNotifier.new,
);

class ExpiredProductsNotifier extends AutoDisposeAsyncNotifier<ExpiredProductsState> {
  @override
  Future<ExpiredProductsState> build() async {
    return await _loadData();
  }

  Future<ExpiredProductsState> _loadData() async {
    final db = ref.read(databaseHelperProvider);
    final allProducts = await db.getAllProductsWithDetails();
    final now = DateTime.now();
    final expired = <Map<String, dynamic>>[];
    final expiringSoon = <Map<String, dynamic>>[];

    for (var product in allProducts) {
      final double currentStock = (product['current_stock'] as num?)?.toDouble() ?? 0.0;
      if (currentStock <= 0) continue;
      final expiry = product['expiry_date'];
      if (expiry != null) {
        try {
          final expiryDate = DateTime.parse(expiry);
          if (expiryDate.isBefore(now)) {
            expired.add(product);
          } else if (expiryDate.difference(now).inDays <= 7 &&
              expiryDate.difference(now).inDays >= 0) {
            expiringSoon.add(product);
          }
        } catch (_) {}
      }
    }
    return ExpiredProductsState(expiredProducts: expired, expiringSoonProducts: expiringSoon);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}