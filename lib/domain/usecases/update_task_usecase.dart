import '../entities/task_entity.dart';
import '../repositories/task_repository.dart';

/// Use Case: تحديث مهمة بالكامل
class UpdateTaskUseCase {
  final TaskRepository repository;

  UpdateTaskUseCase(this.repository);

  Future<void> call(TaskEntity task) async {
    await repository.updateTask(task);
  }
}