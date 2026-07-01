// lib/modules/tasks/providers/task_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../domain/entities/task_entity.dart';
import '../../../domain/usecases/add_task_usecase.dart';
import '../../../domain/usecases/complete_task_usecase.dart';
import '../../../domain/usecases/delete_task_usecase.dart';
import '../../../domain/usecases/get_overdue_tasks_usecase.dart';
import '../../../domain/usecases/get_tasks_usecase.dart';
import '../../../domain/usecases/update_task_partial_usecase.dart';

class TaskState {
  final List<TaskEntity> openTasks;
  final List<TaskEntity> completedTasks;
  final List<TaskEntity> overdueTasks;
  final bool isLoading;
  final String? error;

  const TaskState({
    this.openTasks = const [],
    this.completedTasks = const [],
    this.overdueTasks = const [],
    this.isLoading = false,
    this.error,
  });

  TaskState copyWith({
    List<TaskEntity>? openTasks,
    List<TaskEntity>? completedTasks,
    List<TaskEntity>? overdueTasks,
    bool? isLoading,
    String? error,
  }) {
    return TaskState(
      openTasks: openTasks ?? this.openTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      overdueTasks: overdueTasks ?? this.overdueTasks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

final taskProvider = AutoDisposeAsyncNotifierProvider<TaskNotifier, TaskState>(
  TaskNotifier.new,
);

class TaskNotifier extends AutoDisposeAsyncNotifier<TaskState> {
  @override
  Future<TaskState> build() async {
    return await _loadAllTasks();
  }

  Future<TaskState> _loadAllTasks() async {
    final getTasksUseCase = ref.watch(getTasksUseCaseProvider);
    final getOverdueTasksUseCase = ref.watch(getOverdueTasksUseCaseProvider);

    try {
      final openTasks = await getTasksUseCase(status: 0);
      final completedTasks = await getTasksUseCase(status: 2);
      final overdueTasks = await getOverdueTasksUseCase();

      return TaskState(
        openTasks: openTasks,
        completedTasks: completedTasks,
        overdueTasks: overdueTasks,
      );
    } catch (e) {
      return TaskState(error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = AsyncValue.loading();
    try {
      final newState = await _loadAllTasks();
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // ✅ دوال CRUD (كل دالة تستخدم ref.watch للـ UseCase المناسب)
  Future<void> addTask(Map<String, dynamic> data) async {
    final addTaskUseCase = ref.watch(addTaskUseCaseProvider);
    try {
      final task = TaskEntity(
        title: data['title'] as String,
        description: data['description'] as String?,
        taskType: data['task_type'] as int? ?? 2,
        priority: data['priority'] as int? ?? 1,
        status: data['status'] as int? ?? 0,
        createdAt: data['created_at'] != null
            ? DateTime.parse(data['created_at'] as String)
            : DateTime.now(),
        dueDate: data['due_date'] != null
            ? DateTime.tryParse(data['due_date'] as String)
            : null,
        relatedType: data['related_type'] as String?,
        relatedId: data['related_id'] as int?,
        assignedTo: data['assigned_to'] as int?,
        createdBy: data['created_by'] as int?,
      );
      await addTaskUseCase(task);
      await refresh();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateTask(int id, Map<String, dynamic> data) async {
    final updateTaskPartialUseCase = ref.watch(updateTaskPartialUseCaseProvider);
    try {
      await updateTaskPartialUseCase(id, data);
      await refresh();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> completeTask(int id) async {
    final completeTaskUseCase = ref.watch(completeTaskUseCaseProvider);
    try {
      await completeTaskUseCase(id);
      await refresh();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteTask(int id) async {
    final deleteTaskUseCase = ref.watch(deleteTaskUseCaseProvider);
    try {
      await deleteTaskUseCase(id);
      await refresh();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>> recordInvoicePayment({
    required int taskId,
    required int invoiceId,
    required String invoiceType,
    required double amountPaid,
    String? newDueDate,
  }) async {
    final db = ref.read(databaseHelperProvider);
    return await db.recordInvoicePaymentFromTask(
      taskId: taskId,
      invoiceId: invoiceId,
      invoiceType: invoiceType,
      amountPaid: amountPaid,
      newDueDate: newDueDate,
    );
  }
}