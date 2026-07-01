// lib/modules/subcategories/providers/subcategories_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart'; // نفترض وجود databaseHelperProvider هنا

// 1. مزود لجلب قائمة الفئات (Categories) لاستخدامها في الـ Dropdown
final categoriesListProvider = AutoDisposeFutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return await db.getAllCategories();
});

// 2. مزود إدارة حالة الأصناف (Subcategories) - يعتمد على معرف الفئة (categoryId)
final subcategoriesProvider = AutoDisposeAsyncNotifierProviderFamily<SubcategoriesNotifier, List<Map<String, dynamic>>, int?>(
  SubcategoriesNotifier.new,
);

class SubcategoriesNotifier extends AutoDisposeFamilyAsyncNotifier<List<Map<String, dynamic>>, int?> {

  @override
  Future<List<Map<String, dynamic>>> build(int? categoryId) async {
    // هذه الدالة تُستدعى تلقائياً عند فتح الشاشة لجلب البيانات
    return _fetchSubcategories(categoryId);
  }

  Future<List<Map<String, dynamic>>> _fetchSubcategories(int? categoryId) async {
    final db = ref.read(databaseHelperProvider);
    if (categoryId != null) {
      return await db.getSubcategoriesByCategoryWithCount(categoryId);
    } else {
      return await db.getAllSubcategoriesWithCount();
    }
  }

  // دالة الإضافة
  Future<void> addSubcategory(Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertSubcategory(data);
    // السطر السحري: نأمر Riverpod بإعادة جلب البيانات وتحديث الشاشة تلقائياً
    ref.invalidateSelf();
  }

  // دالة التعديل
  Future<void> updateSubcategory(int id, Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.updateSubcategory(id, data);
    ref.invalidateSelf();
  }

  // دالة الحذف
  Future<void> deleteSubcategory(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteSubcategory(id);
    ref.invalidateSelf();
  }

  // التأكد من عدم ارتباط منتجات قبل الحذف (للـ UI)
  Future<bool> hasProducts(int subcategoryId) async {
    final db = ref.read(databaseHelperProvider);
    final products = await db.getProductsBySubcategory(subcategoryId);
    return products.isNotEmpty;
  }
}