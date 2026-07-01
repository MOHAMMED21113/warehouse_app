import '../repositories/task_repository.dart';

/// Use Case: تحديث جزئي للمهمة (تغيير بعض الحقول فقط)
class UpdateTaskPartialUseCase {
  final TaskRepository repository;

  UpdateTaskPartialUseCase(this.repository);

  Future<void> call(int id, Map<String, dynamic> data) async {
    await repository.updateTaskPartial(id, data);
  }
}