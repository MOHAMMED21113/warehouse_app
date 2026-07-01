// lib/modules/subcategories/providers/subcategory_details_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

/// Provider مخصص لجلب منتجات صنف معين بناءً على الـ [subcategoryId]
final subcategoryProductsProvider = AutoDisposeAsyncNotifierProviderFamily<
    SubcategoryProductsNotifier, List<Map<String, dynamic>>, int>(
  SubcategoryProductsNotifier.new,
);

class SubcategoryProductsNotifier extends AutoDisposeFamilyAsyncNotifier<List<Map<String, dynamic>>, int> {
  @override
  Future<List<Map<String, dynamic>>> build(int arg) async {
    // arg هنا هو الـ subcategoryId
    return _fetchProducts(arg);
  }

  Future<List<Map<String, dynamic>>> _fetchProducts(int subcategoryId) async {
    final db = ref.read(databaseHelperProvider);
    return await db.getProductsBySubcategoryWithDetails(subcategoryId);
  }

  // دالة مساعدة لتحديث القائمة يدوياً (Pull to refresh)
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}