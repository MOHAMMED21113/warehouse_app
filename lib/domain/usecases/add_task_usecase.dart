import '../entities/task_entity.dart';
import '../repositories/task_repository.dart';

/// Use Case: إضافة مهمة جديدة
class AddTaskUseCase {
  final TaskRepository repository;

  AddTaskUseCase(this.repository);

  Future<int> call(TaskEntity task) async {
    return await repository.insertTask(task);
  }
}