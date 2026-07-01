// lib/modules/warehouses/providers/warehouses_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

final warehousesProvider = AutoDisposeAsyncNotifierProvider<WarehousesNotifier, List<Map<String, dynamic>>>(
  WarehousesNotifier.new,
);

class WarehousesNotifier extends AutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = ref.read(databaseHelperProvider);
    return await db.getAllWarehouses();
  }

  Future<void> addWarehouse(Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertWarehouse(data);
    ref.invalidateSelf();
  }

  Future<void> updateWarehouse(int id, Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.updateWarehouse(id, data);
    ref.invalidateSelf();
  }

  Future<void> deleteWarehouse(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteWarehouse(id);
    ref.invalidateSelf();
  }

  Future<void> setDefaultWarehouse(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.setDefaultWarehouse(id);
    ref.invalidateSelf();
  }
}