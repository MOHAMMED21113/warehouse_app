// lib/modules/groups/providers/categories_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

/// Provider لإدارة فئات مجموعة معينة بناءً على الـ [groupId]
final categoriesProvider = AutoDisposeAsyncNotifierProviderFamily<CategoriesNotifier, List<Map<String, dynamic>>, int>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AutoDisposeFamilyAsyncNotifier<List<Map<String, dynamic>>, int> {
  @override
  Future<List<Map<String, dynamic>>> build(int arg) async {
    // arg هو groupId
    return _fetchCategories(arg);
  }

  Future<List<Map<String, dynamic>>> _fetchCategories(int groupId) async {
    final db = ref.read(databaseHelperProvider);
    return await db.getCategoriesByGroup(groupId);
  }

  // دالة الإضافة
  Future<void> addCategory(Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertCategory(data);
    ref.invalidateSelf();
  }

  // دالة التعديل
  Future<void> updateCategory(int id, Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.updateCategory(id, data);
    ref.invalidateSelf();
  }

  // دالة الحذف
  Future<void> deleteCategory(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteCategory(id);
    ref.invalidateSelf();
  }

  // 🚀 حماية: التأكد من عدم وجود أصناف فرعية مرتبطة قبل الحذف
  Future<bool> hasSubcategories(int categoryId) async {
    final db = ref.read(databaseHelperProvider);
    final subcategories = await db.getSubcategoriesByCategory(categoryId);
    return subcategories.isNotEmpty;
  }
}