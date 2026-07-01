import '../entities/task_entity.dart';

/// واجهة مستودع المهام - مطابقة لنمط ProductRepository
abstract class TaskRepository {
  /// جلب المهام مع خيارات الفلترة
  Future<List<TaskEntity>> getTasks({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
    int? limit,
    int? offset,
  });

  /// جلب عدد المهام حسب الفلتر
  Future<int> getTasksCount({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
  });

  /// جلب مهمة بواسطة المعرف
  Future<TaskEntity?> getTaskById(int id);

  /// جلب المهام المتأخرة
  Future<List<TaskEntity>> getOverdueTasks();

  /// جلب المهام حسب الحالة (0 مفتوحة, 2 منجزة)
  Future<List<TaskEntity>> getTasksByStatus(int status);

  /// إضافة مهمة جديدة
  Future<int> insertTask(TaskEntity task);

  /// تحديث مهمة بالكامل
  Future<void> updateTask(TaskEntity task);

  /// تحديث جزئي للمهمة (تغيير بعض الحقول فقط)
  Future<void> updateTaskPartial(int id, Map<String, dynamic> data);

  /// إكمال مهمة (تغيير الحالة إلى منجزة)
  Future<void> completeTask(int id);

  /// حذف مهمة
  Future<void> deleteTask(int id);

  /// تسجيل دفعة مالية من خلال مهمة فاتورة
  Future<Map<String, dynamic>> recordInvoicePayment({
    required int taskId,
    required int invoiceId,
    required String invoiceType,
    required double amountPaid,
    String? newDueDate,
  });
}