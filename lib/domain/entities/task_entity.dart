/// نموذج المهمة (Task) - مطابق لنمط ProductEntity
/// يمثل بيانات المهمة في طبقة المجال (Domain)
class TaskEntity {
  final int? id;
  final String title;
  final String? description;
  final int taskType; // 0: تسليم, 1: إعادة تخزين, 2: عام
  final int priority; // 1: عادية, 2: متوسطة, 3: عاجلة
  final int status; // 0: مفتوحة, 1: قيد التنفيذ, 2: منجزة
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? recurrence;
  final int? parentTaskId;
  final String? relatedType; // 'sales_invoice', 'purchase_invoice', 'product', 'general'
  final int? relatedId;
  final int? assignedTo;
  final int? createdBy;
  final bool reminderSent;

  const TaskEntity({
    this.id,
    required this.title,
    this.description,
    required this.taskType,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.dueDate,
    this.completedAt,
    this.recurrence,
    this.parentTaskId,
    this.relatedType,
    this.relatedId,
    this.assignedTo,
    this.createdBy,
    this.reminderSent = false,
  });

  /// نسخة معدلة من المهمة
  TaskEntity copyWith({
    int? id,
    String? title,
    String? description,
    int? taskType,
    int? priority,
    int? status,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? completedAt,
    String? recurrence,
    int? parentTaskId,
    String? relatedType,
    int? relatedId,
    int? assignedTo,
    int? createdBy,
    bool? reminderSent,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      recurrence: recurrence ?? this.recurrence,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      relatedType: relatedType ?? this.relatedType,
      relatedId: relatedId ?? this.relatedId,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      reminderSent: reminderSent ?? this.reminderSent,
    );
  }

  /// تحويل المهمة إلى Map للتخزين في قاعدة البيانات
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

  // ==================== Getters مساعدة للواجهة ====================
  bool get isCompleted => status == 2;
  bool get isOpen => status == 0;
  bool get isOverdue => !isCompleted && dueDate != null && dueDate!.isBefore(DateTime.now());
  bool get isInvoiceTask => relatedType == 'sales_invoice' || relatedType == 'purchase_invoice';

  String get priorityLabel {
    switch (priority) {
      case 3: return 'عاجلة';
      case 2: return 'متوسطة';
      default: return 'عادية';
    }
  }

  String get taskTypeLabel {
    switch (taskType) {
      case 0: return 'تسليم بضاعة';
      case 1: return 'إعادة تخزين';
      default: return 'مهام عامة';
    }
  }

  String get statusLabel {
    switch (status) {
      case 0: return 'مفتوحة';
      case 1: return 'قيد التنفيذ';
      case 2: return 'منجزة';
      default: return 'غير معروف';
    }
  }
}