import '../entities/task_entity.dart';
import '../repositories/task_repository.dart';

/// Use Case: جلب المهام المتأخرة (التي لم تُنجز وتاريخها قبل اليوم)
class GetOverdueTasksUseCase {
  final TaskRepository repository;

  GetOverdueTasksUseCase(this.repository);

  Future<List<TaskEntity>> call() async {
    return await repository.getOverdueTasks();
  }
}