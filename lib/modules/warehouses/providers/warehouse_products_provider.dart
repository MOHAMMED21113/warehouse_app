// lib/modules/warehouses/providers/warehouse_products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

final warehouseProductsProvider =
AutoDisposeAsyncNotifierProviderFamily<WarehouseProductsNotifier, List<Map<String, dynamic>>, int>(
  WarehouseProductsNotifier.new,
);

class WarehouseProductsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Map<String, dynamic>>, int> {
  @override
  Future<List<Map<String, dynamic>>> build(int warehouseId) async {
    final db = ref.read(databaseHelperProvider);
    return await db.getProductsWithStockForWarehouse(warehouseId);
  }

  Future<Map<String, dynamic>> transferProduct({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required num quantity,
  }) async {
    final db = ref.read(databaseHelperProvider);
    final result = await db.transferProductFixed(
      productId: productId,
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      quantity: quantity,
    );
    if (result['success'] == true) {
      ref.invalidateSelf();
    }
    return result;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}