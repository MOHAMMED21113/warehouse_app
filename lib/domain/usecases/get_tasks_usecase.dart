import '../entities/task_entity.dart';
import '../repositories/task_repository.dart';

class GetTasksUseCase {
  final TaskRepository repository;

  GetTasksUseCase(this.repository);

  Future<List<TaskEntity>> call({
    int? status,
    String? relatedType,
    int? relatedId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    // 1. جلب البيانات من الـ Repository
    final tasks = await repository.getTasks(
      status: status,
      relatedType: relatedType,
      relatedId: relatedId,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );

    // 2. ترتيب تصاعدي حسب تاريخ الاستحقاق (الأقدم أولاً)
    // ملاحظة: تأكد من أن dueDate ليس null، وإلا استخدم createdAt كبديل
    tasks.sort((a, b) {
      final dateA = a.dueDate ?? a.createdAt;
      final dateB = b.dueDate ?? b.createdAt;
      return dateA.compareTo(dateB);
    });

    return tasks;
  }
}