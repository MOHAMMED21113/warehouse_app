import '../repositories/task_repository.dart';

/// Use Case: إكمال مهمة (تغيير الحالة إلى منجزة)
class CompleteTaskUseCase {
  final TaskRepository repository;

  CompleteTaskUseCase(this.repository);

  Future<void> call(int id) async {
    await repository.completeTask(id);
  }
}