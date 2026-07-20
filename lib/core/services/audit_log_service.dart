// lib/core/services/audit_log_service.dart

import 'dart:convert';
import '../../database/database_helper.dart';

class AuditLogService {
  final DatabaseHelper dbHelper;
  AuditLogService(this.dbHelper);

  Future<void> logAction(String action, String tableName, int recordId, Map<String, dynamic>? oldValue, Map<String, dynamic>? newValue) async {
    await dbHelper.logAuditAction(
      action: action,
      tableName: tableName,
      recordId: recordId,
      oldValue: oldValue != null ? jsonEncode(oldValue) : null,
      newValue: newValue != null ? jsonEncode(newValue) : null,
    );
  }

  Future<List<Map<String, dynamic>>> getAuditLog({String? tableName, String? action, String? user, String? startDate, String? endDate, int limit = 50, int offset = 0}) async {
    final db = await dbHelper.database;
    String query = "SELECT * FROM audit_log WHERE 1=1";
    List<dynamic> args = [];

    if (tableName != null && tableName.isNotEmpty && tableName != 'all') {
      query += " AND table_name = ?";
      args.add(tableName);
    }
    if (action != null && action.isNotEmpty && action != 'all') {
      query += " AND action = ?";
      args.add(action);
    }
    if (startDate != null && startDate.isNotEmpty) {
      query += " AND substr(timestamp, 1, 10) >= ?";
      args.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      query += " AND substr(timestamp, 1, 10) <= ?";
      args.add(endDate);
    }

    query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?";
    args.add(limit);
    args.add(offset);
    return await db.rawQuery(query, args);
  }

  /// جلب أسماء الجداول الفريدة المسجلة في السجل
  Future<List<String>> getUniqueTables() async {
    final db = await dbHelper.database;
    final res = await db.rawQuery("SELECT DISTINCT table_name FROM audit_log WHERE table_name IS NOT NULL ORDER BY table_name ASC");
    return res.map((e) => e['table_name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
}
