import '../repositories/task_repository.dart';

/// Use Case: حذف مهمة
class DeleteTaskUseCase {
  final TaskRepository repository;

  DeleteTaskUseCase(this.repository);

  Future<void> call(int id) async {
    await repository.deleteTask(id);
  }
}