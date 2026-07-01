// lib/modules/groups/providers/groups_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

/// Provider لإدارة حالة المجموعات، يقوم بجلب البيانات ويدمرها عند إغلاق الشاشة
final groupsProvider = AutoDisposeAsyncNotifierProvider<GroupsNotifier, List<Map<String, dynamic>>>(
  GroupsNotifier.new,
);

class GroupsNotifier extends AutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchGroups();
  }

  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    final db = ref.read(databaseHelperProvider);
    return await db.getAllGroups();
  }

  // دالة الإضافة
  Future<void> addGroup(Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.insertGroup(data);
    ref.invalidateSelf(); // إعادة بناء الشاشة تلقائياً
  }

  // دالة التعديل
  Future<void> updateGroup(int id, Map<String, dynamic> data) async {
    final db = ref.read(databaseHelperProvider);
    await db.updateGroup(id, data);
    ref.invalidateSelf();
  }

  // دالة الحذف
  Future<void> deleteGroup(int id) async {
    final db = ref.read(databaseHelperProvider);
    await db.deleteGroup(id);
    ref.invalidateSelf();
  }

  // فحص ما إذا كانت المجموعة تحتوي على فئات (لمنع الحذف العشوائي)
  Future<bool> hasCategories(int groupId) async {
    final db = ref.read(databaseHelperProvider);
    final categories = await db.getCategoriesByGroup(groupId);
    return categories.isNotEmpty;
  }
}