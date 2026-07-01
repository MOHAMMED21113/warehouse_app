import '../../domain/entities/task_entity.dart';
import '../../database/database_helper.dart';
import '../models/task_model.dart';

/// مصدر بيانات محلي للمهام - مطابق لنمط ProductLocalDataSource
class TaskLocalDataSource {
  final DatabaseHelper db;

  TaskLocalDataSource(this.db);

  // ==================== جلب المهام مع فلترة ====================
  Future<List<TaskEntity>> getTasks({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    String sql = '''
      SELECT * FROM tasks
      WHERE 1=1
    ''';
    List<Object?> args = [];

    if (status != null) {
      sql += ' AND status = ?';
      args.add(status);
    }
    if (relatedType != null && relatedType.isNotEmpty) {
      sql += ' AND related_type = ?';
      args.add(relatedType);
    }
    if (relatedId != null) {
      sql += ' AND related_id = ?';
      args.add(relatedId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql += ' AND (title LIKE ? OR description LIKE ?)';
      final q = '%$searchQuery%';
      args.addAll([q, q]);
    }

    sql += ' ORDER BY priority DESC, created_at DESC';

    if (limit != null) {
      sql += ' LIMIT ?';
      args.add(limit);
    }
    if (offset != null) {
      sql += ' OFFSET ?';
      args.add(offset);
    }

    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => TaskModel.fromMap(m)).toList();
  }

  // ==================== عدد المهام حسب الفلتر ====================
  Future<int> getTasksCount({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
  }) async {
    String sql = '''
      SELECT COUNT(*) as count FROM tasks
      WHERE 1=1
    ''';
    List<Object?> args = [];

    if (status != null) {
      sql += ' AND status = ?';
      args.add(status);
    }
    if (relatedType != null && relatedType.isNotEmpty) {
      sql += ' AND related_type = ?';
      args.add(relatedType);
    }
    if (relatedId != null) {
      sql += ' AND related_id = ?';
      args.add(relatedId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql += ' AND (title LIKE ? OR description LIKE ?)';
      final q = '%$searchQuery%';
      args.addAll([q, q]);
    }

    final result = await db.rawQuery(sql, args);
    return (result.first['count'] as int?) ?? 0;
  }

  // ==================== جلب مهمة بواسطة المعرف ====================
  Future<TaskEntity?> getTaskById(int id) async {
    final maps = await db.rawQuery('SELECT * FROM tasks WHERE id = ?', [id]);
    if (maps.isEmpty) return null;
    return TaskModel.fromMap(maps.first);
  }

  // ==================== جلب المهام المتأخرة ====================
  Future<List<TaskEntity>> getOverdueTasks() async {
    final maps = await db.getOverdueTasks();
    return maps.map((m) => TaskModel.fromMap(m)).toList();
  }

  // ==================== جلب المهام حسب الحالة ====================
  Future<List<TaskEntity>> getTasksByStatus(int status) async {
    final maps = await db.getTasksByStatus(status);
    return maps.map((m) => TaskModel.fromMap(m)).toList();
  }

  // ==================== إضافة مهمة ====================
  Future<int> insertTask(TaskEntity task) async {
    final model = TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      taskType: task.taskType,
      priority: task.priority,
      status: task.status,
      createdAt: task.createdAt,
      dueDate: task.dueDate,
      completedAt: task.completedAt,
      recurrence: task.recurrence,
      parentTaskId: task.parentTaskId,
      relatedType: task.relatedType,
      relatedId: task.relatedId,
      assignedTo: task.assignedTo,
      createdBy: task.createdBy,
      reminderSent: task.reminderSent,
    );
    return await db.insertTask(model.toMap());
  }

  // ==================== تحديث مهمة ====================
  Future<void> updateTask(TaskEntity task) async {
    final model = TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      taskType: task.taskType,
      priority: task.priority,
      status: task.status,
      createdAt: task.createdAt,
      dueDate: task.dueDate,
      completedAt: task.completedAt,
      recurrence: task.recurrence,
      parentTaskId: task.parentTaskId,
      relatedType: task.relatedType,
      relatedId: task.relatedId,
      assignedTo: task.assignedTo,
      createdBy: task.createdBy,
      reminderSent: task.reminderSent,
    );
    await db.updateTask(task.id!, model.toMap());
  }

  // ==================== تحديث جزئي (هام: لا تكتب فوق القيم الموجودة بقيم فارغة) ====================
  Future<void> updateTaskPartial(int id, Map<String, dynamic> data) async {
    // إزالة المفاتيح التي قيمتها null لتجنب الكتابة فوق القيم الموجودة
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.removeWhere((key, value) => value == null);
    if (cleanData.isNotEmpty) {
      await db.updateTask(id, cleanData);
    }
  }

  // ==================== إكمال المهمة ====================
  Future<void> completeTask(int id) async {
    await db.updateTask(id, {
      'status': 2,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================== حذف المهمة ====================
  Future<void> deleteTask(int id) async {
    await db.deleteTask(id);
  }

  // ==================== تسجيل دفعة مالية من مهمة فاتورة ====================
  Future<Map<String, dynamic>> recordInvoicePayment({
    required int taskId,
    required int invoiceId,
    required String invoiceType,
    required double amountPaid,
    String? newDueDate,
  }) async {
    return await db.recordInvoicePaymentFromTask(
      taskId: taskId,
      invoiceId: invoiceId,
      invoiceType: invoiceType,
      amountPaid: amountPaid,
      newDueDate: newDueDate,
    );
  }
}