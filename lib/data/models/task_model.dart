import '../../domain/entities/task_entity.dart';

/// نموذج المهمة (TaskModel) - مطابق لنمط ProductModel
/// يمتد من TaskEntity ويضيف دوال التحويل من/إلى Map
class TaskModel extends TaskEntity {
  const TaskModel({
    super.id,
    required super.title,
    super.description,
    required super.taskType,
    required super.priority,
    required super.status,
    required super.createdAt,
    super.dueDate,
    super.completedAt,
    super.recurrence,
    super.parentTaskId,
    super.relatedType,
    super.relatedId,
    super.assignedTo,
    super.createdBy,
    super.reminderSent,
  });

  /// إنشاء TaskModel من Map (قاعدة البيانات)
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      taskType: map['task_type'] as int? ?? 2,
      priority: map['priority'] as int? ?? 1,
      status: map['status'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String) ?? DateTime.now(),
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) : null,
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'].toString()) : null,
      recurrence: map['recurrence'] as String?,
      parentTaskId: map['parent_task_id'] as int?,
      relatedType: map['related_type'] as String?,
      relatedId: map['related_id'] as int?,
      assignedTo: map['assigned_to'] as int?,
      createdBy: map['created_by'] as int?,
      reminderSent: (map['reminder_sent'] as int? ?? 0) == 1,
    );
  }

  /// تحويل Model إلى Map (للتخزين)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'task_type': taskType,
      'priority': priority,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'recurrence': recurrence,
      'parent_task_id': parentTaskId,
      'related_type': relatedType,
      'related_id': relatedId,
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'reminder_sent': reminderSent ? 1 : 0,
    };
  }
}