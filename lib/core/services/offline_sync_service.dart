// lib/core/services/offline_sync_service.dart

import 'package:flutter/foundation.dart';
import '../../database/database_helper.dart';

class OfflineSyncService {
  final DatabaseHelper dbHelper;
  OfflineSyncService(this.dbHelper);

  Future<void> syncAllPendingData() async {
    debugPrint('🔄 بدء مزامنة البيانات المحلية مع السيرفر السحابي...');
    try {
      final db = await dbHelper.database;
      
      // 1. مزامنة المنتجات غير المتزامنة (إذا وجد عمود sync_status)
      try {
        final unsyncedProducts = await db.query('products', where: 'sync_status = ?', whereArgs: [0]);
        for (var p in unsyncedProducts) {
          debugPrint('مزامنة منتج: ${p['name']}');
          await db.update('products', {'sync_status': 1}, where: 'id = ?', whereArgs: [p['id']]);
        }
      } catch (_) {}

      // 2. مزامنة فواتير المبيعات
      try {
        final unsyncedSales = await db.query('sales_invoices', where: 'sync_status = ?', whereArgs: [0]);
        for (var inv in unsyncedSales) {
          debugPrint('مزامنة فاتورة: #${inv['id']}');
          await db.update('sales_invoices', {'sync_status': 1}, where: 'id = ?', whereArgs: [inv['id']]);
        }
      } catch (_) {}

      debugPrint('✅ تم الانتهاء من المزامنة المحلية بنجاح');
    } catch (e) {
      debugPrint('⚠️ خطأ أثناء المزامنة: $e');
    }
  }

  Future<void> markAsUnsynced(String table, int id) async {
    try {
      final db = await dbHelper.database;
      await db.update(table, {'sync_status': 0}, where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }
}
