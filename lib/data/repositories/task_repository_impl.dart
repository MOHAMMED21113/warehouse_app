// lib/data/repositories/task_repository_impl.dart

import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_local_datasource.dart';

/// تطبيق مستودع المهام - مطابق لنمط ProductRepositoryImpl
class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDataSource dataSource;

  TaskRepositoryImpl(this.dataSource);

  @override
  Future<List<TaskEntity>> getTasks({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    return await dataSource.getTasks(
      status: status,
      relatedType: relatedType,
      relatedId: relatedId,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> getTasksCount({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
  }) async {
    return await dataSource.getTasksCount(
      status: status,
      relatedType: relatedType,
      relatedId: relatedId,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<TaskEntity?> getTaskById(int id) async {
    return await dataSource.getTaskById(id);
  }

  @override
  Future<List<TaskEntity>> getOverdueTasks() async {
    return await dataSource.getOverdueTasks();
  }

  @override
  Future<List<TaskEntity>> getTasksByStatus(int status) async {
    return await dataSource.getTasksByStatus(status);
  }

  @override
  Future<int> insertTask(TaskEntity task) async {
    return await dataSource.insertTask(task);
  }

  @override
  Future<void> updateTask(TaskEntity task) async {
    await dataSource.updateTask(task);
  }

  @override
  Future<void> updateTaskPartial(int id, Map<String, dynamic> data) async {
    await dataSource.updateTaskPartial(id, data);
  }

  @override
  Future<void> completeTask(int id) async {
    await dataSource.completeTask(id);
  }

  @override
  Future<void> deleteTask(int id) async {
    await dataSource.deleteTask(id);
  }

  @override
  Future<Map<String, dynamic>> recordInvoicePayment({
    required int taskId,
    required int invoiceId,
    required String invoiceType,
    required double amountPaid,
    String? newDueDate,
  }) async {
    return await dataSource.recordInvoicePayment(
      taskId: taskId,
      invoiceId: invoiceId,
      invoiceType: invoiceType,
      amountPaid: amountPaid,
      newDueDate: newDueDate,
    );
  }
}