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

  Future<List<Map<String, dynamic>>> getAuditLog({String? tableName, String? user, String? startDate, String? endDate}) async {
    final db = await dbHelper.database;
    String query = "SELECT * FROM audit_log WHERE 1=1";
    List<dynamic> args = [];

    if (tableName != null && tableName.isNotEmpty && tableName != 'all') {
      query += " AND table_name = ?";
      args.add(tableName);
    }
    if (startDate != null && startDate.isNotEmpty) {
      query += " AND substr(timestamp, 1, 10) >= ?";
      args.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      query += " AND substr(timestamp, 1, 10) <= ?";
      args.add(endDate);
    }

    query += " ORDER BY timestamp DESC LIMIT 500";
    return await db.rawQuery(query, args);
  }
}
