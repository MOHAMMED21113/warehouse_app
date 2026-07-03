// lib/modules/tasks/views/tasks_screen.dart
// ✅ النسخة الفاخرة - تم حل مشكلة الـ Overflow هندسياً مع الحفاظ على الهوية البصرية
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/invoice_printer.dart';
import '../../../domain/entities/task_entity.dart';
import '../providers/task_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;

  AppThemeColors get _colorsRead =>
      AppThemeColors(isDark: ref.read(themeModeProvider) == ThemeMode.dark);

  // ✅ دالة مساعدة لعرض الرسائل
  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ✅ دالة مساعدة لتنسيق الأرقام
  String _formatNumber(num value) {
    return NumberFormat('#,##0.00', 'en_US').format(value);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic);
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colors = AppThemeColors(isDark: isDark);
    final asyncState = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: asyncState.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
        error: (err, _) => Center(
            child: Text('خطأ: $err', style: TextStyle(color: colors.textMain))),
        data: (state) {
          return NestedScrollView(
            headerSliverBuilder: (ctx, inner) =>
            [_buildSliverAppBar(state, colors, isDark)],
            body: Column(
              children: [
                _buildFilterTabs(state, colors, isDark),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildTaskList(state.openTasks, 'open', colors, isDark),
                      _buildTaskList(
                          state.completedTasks, 'completed', colors, isDark),
                      _buildTaskList(
                          state.overdueTasks, 'overdue', colors, isDark),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  // ==================== SliverAppBar ====================
  Widget _buildSliverAppBar(
      TaskState state, AppThemeColors colors, bool isDark) {
    final total = state.openTasks.length +
        state.completedTasks.length +
        state.overdueTasks.length;
    final completed = state.completedTasks.length;
    final progress = total > 0 ? completed / total : 0.0;

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      floating: false,
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            size: 20, color: AppColors.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('إدارة المهام',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: AppColors.primary)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              size: 22, color: AppColors.primary),
          onPressed: () => ref.invalidate(taskProvider),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: FadeTransition(
          opacity: _headerFade,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.navy,
                  AppColors.navyMedium,
                  AppColors.navyLight
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 55, 16, 12),
                child: Row(
                  children: [
                    _buildProgressRing(progress, completed, total, isDark),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatsGrid(state, isDark)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== حلقة التقدم ====================
  Widget _buildProgressRing(
      double progress, int completed, int total, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        width: 95,
        height: 95,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 2),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              valueColor:
              AlwaysStoppedAnimation(Colors.white.withOpacity(0.08)),
              strokeCap: StrokeCap.round,
            ),
            CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).toInt()}%',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10)
                      ],
                    ),
                  ),
                  Text(
                    '$completed/$total',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== شبكة الإحصائيات ====================
  Widget _buildStatsGrid(TaskState state, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(children: [
          Expanded(
              child: _miniStat('مفتوحة', '${state.openTasks.length}',
                  AppColors.info, Icons.pending_actions_rounded, isDark)),
          const SizedBox(width: 8),
          Expanded(
              child: _miniStat('منجزة', '${state.completedTasks.length}',
                  AppColors.success, Icons.check_circle_rounded, isDark)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _miniStat('متأخرة', '${state.overdueTasks.length}',
                  AppColors.error, Icons.alarm_off_rounded, isDark)),
          const SizedBox(width: 8),
          Expanded(
              child: _miniStat(
                  'الإجمالي',
                  '${state.openTasks.length + state.completedTasks.length + state.overdueTasks.length}',
                  AppColors.primary,
                  Icons.assignment_rounded,
                  isDark)),
        ]),
      ],
    );
  }

  Widget _miniStat(
      String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== تبويبات الفلترة ====================
  Widget _buildFilterTabs(TaskState state, AppThemeColors colors, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary.withOpacity(isDark ? 0.25 : 0.15),
            AppColors.primary.withOpacity(isDark ? 0.08 : 0.04),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor:
        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          _tabChip('مفتوحة', state.openTasks.length, AppColors.info,
              Icons.pending_actions_rounded),
          _tabChip('منجزة', state.completedTasks.length, AppColors.success,
              Icons.task_alt_rounded),
          _tabChip('متأخرة', state.overdueTasks.length, AppColors.error,
              Icons.alarm_off_rounded),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int count, Color color, IconData icon) {
    return Tab(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.25))),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== قائمة المهام ====================
  Widget _buildTaskList(
      List<TaskEntity> tasks, String type, AppThemeColors colors, bool isDark) {
    if (tasks.isEmpty) return _buildEmptyState(type, colors, isDark);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      physics: const BouncingScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 350 + (i.clamp(0, 8) * 60)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(30 * (1 - value), 0),
            child: Opacity(opacity: value, child: child),
          ),
          child: _buildTaskCard(tasks[i], type, i, colors, isDark),
        );
      },
    );
  }

  // ==================== بطاقة المهمة ====================
  Widget _buildTaskCard(TaskEntity task, String type, int index,
      AppThemeColors colors, bool isDark) {
    final priority = task.priority;
    final isCompleted = task.isCompleted;
    final isOverdue = type == 'overdue' && !isCompleted;
    final bool isInvoiceTask = task.isInvoiceTask;

    Color pColor;
    String pLabel;
    IconData pIcon;
    List<Color> pGradient;
    switch (priority) {
      case 3:
        pColor = AppColors.error;
        pLabel = 'عاجلة';
        pIcon = Icons.bolt_rounded;
        pGradient = [AppColors.error, AppColors.error.withOpacity(0.7)];
        break;
      case 2:
        pColor = AppColors.primary;
        pLabel = 'متوسطة';
        pIcon = Icons.star_rounded;
        pGradient = [AppColors.primary, AppColors.primary.withOpacity(0.7)];
        break;
      default:
        pColor = AppColors.success;
        pLabel = 'عادية';
        pIcon = Icons.check_circle_outline_rounded;
        pGradient = [AppColors.success, AppColors.success.withOpacity(0.7)];
    }

    String timeLabel = '';
    Color timeColor =
    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    IconData timeIcon = Icons.schedule_rounded;
    if (task.dueDate != null && !isCompleted) {
      final diff = task.dueDate!.difference(DateTime.now()).inDays;
      if (diff < 0) {
        timeLabel = 'متأخر ${-diff} يوم';
        timeColor = AppColors.error;
        timeIcon = Icons.warning_rounded;
      } else if (diff == 0) {
        timeLabel = 'اليوم!';
        timeColor = AppColors.warning;
        timeIcon = Icons.alarm_rounded;
      } else if (diff == 1) {
        timeLabel = 'غداً';
        timeColor = AppColors.warning;
        timeIcon = Icons.upcoming_rounded;
      } else if (diff <= 7) {
        timeLabel = 'بعد $diff أيام';
        timeColor = AppColors.info;
      } else {
        timeLabel = 'بعد $diff يوم';
        timeColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      }
    }

    final Color cardBg = isDark ? AppColors.navyCard : Colors.white;
    final Color cardBorder =
    isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
    final Color titleColor =
    isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color hintColor =
    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Dismissible(
      key: Key('task_${task.id}_${task.status}'),
      background: _swipeBg(AppColors.success, Icons.check_rounded, 'إكمال ✓',
          Alignment.centerRight, isDark),
      secondaryBackground: _swipeBg(AppColors.error, Icons.delete_rounded,
          'حذف', Alignment.centerLeft, isDark),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          if (!isCompleted) {
            ref.read(taskProvider.notifier).completeTask(task.id!);
          }
          return false;
        }
        return await _showDeleteConfirm(task.title);
      },
      onDismissed: (_) => ref.read(taskProvider.notifier).deleteTask(task.id!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isOverdue ? AppColors.error.withOpacity(0.4) : cardBorder,
              width: isOverdue ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCompleted
                          ? [
                        AppColors.success,
                        AppColors.success.withOpacity(0.5)
                      ]
                          : pGradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDetails(task),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: isCompleted
                                  ? null
                                  : () => ref
                                  .read(taskProvider.notifier)
                                  .completeTask(task.id!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(top: 1, left: 10),
                                decoration: BoxDecoration(
                                  gradient: isCompleted
                                      ? LinearGradient(colors: [
                                    AppColors.success.withOpacity(0.2),
                                    AppColors.success.withOpacity(0.1)
                                  ])
                                      : null,
                                  color: isCompleted
                                      ? null
                                      : (isDark
                                      ? AppColors.navy
                                      : const Color(0xFFF8FAFC)),
                                  border: Border.all(
                                      color: isCompleted
                                          ? AppColors.success
                                          : (isDark
                                          ? AppColors.navyBorder
                                          : const Color(0xFFCBD5E1)),
                                      width: 2),
                                  shape: BoxShape.circle,
                                ),
                                child: isCompleted
                                    ? const Icon(Icons.check_rounded,
                                    size: 16, color: AppColors.success)
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isCompleted
                                                ? hintColor
                                                : (isOverdue
                                                ? AppColors.error
                                                : titleColor),
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: hintColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            pColor.withOpacity(
                                                isDark ? 0.2 : 0.12),
                                            pColor.withOpacity(
                                                isDark ? 0.08 : 0.04),
                                          ]),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                          border: Border.all(
                                              color: pColor.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(pIcon,
                                                size: 11, color: pColor),
                                            const SizedBox(width: 3),
                                            Text(pLabel,
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: pColor)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (task.description != null &&
                                      task.description!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(task.description!,
                                        style: TextStyle(
                                            color: subColor,
                                            fontSize: 12,
                                            height: 1.4),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 10),
                                  if (isInvoiceTask && !isCompleted) ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            AppColors.primary.withOpacity(
                                                isDark ? 0.2 : 0.12),
                                            AppColors.primary.withOpacity(
                                                isDark ? 0.08 : 0.04),
                                          ]),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                              color: AppColors.primary
                                                  .withOpacity(0.5),
                                              width: 1),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () =>
                                                _showTaskPaymentDialog(task),
                                            borderRadius:
                                            BorderRadius.circular(10),
                                            child: Padding(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 9),
                                              child: Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                      Icons.payments_rounded,
                                                      size: 18,
                                                      color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    task.relatedType ==
                                                        'sales_invoice'
                                                        ? 'تحصيل الدفعة 💰'
                                                        : 'سداد الدفعة 💸',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                        FontWeight.bold,
                                                        color:
                                                        AppColors.primary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Row(
                                    children: [
                                      _iconLabel(
                                        isOverdue
                                            ? Icons.timer_off_rounded
                                            : Icons.event_rounded,
                                        task.dueDate != null
                                            ? DateFormat('d/M/yyyy')
                                            .format(task.dueDate!)
                                            : 'بدون موعد',
                                        isOverdue ? AppColors.error : hintColor,
                                      ),
                                      if (timeLabel.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              timeColor.withOpacity(0.15),
                                              timeColor.withOpacity(0.05),
                                            ]),
                                            borderRadius:
                                            BorderRadius.circular(6),
                                            border: Border.all(
                                                color: timeColor
                                                    .withOpacity(0.25)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(timeIcon,
                                                  size: 10, color: timeColor),
                                              const SizedBox(width: 3),
                                              Text(timeLabel,
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: timeColor)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (!isInvoiceTask) ...[
                                        _actionBtn(
                                            Icons.edit_rounded,
                                            AppColors.primary.withOpacity(
                                                isDark ? 0.15 : 0.08),
                                            AppColors.primary,
                                                () => _openForm(task: task)),
                                        const SizedBox(width: 6),
                                      ],
                                      _actionBtn(
                                          Icons.delete_outline_rounded,
                                          AppColors.error.withOpacity(
                                              isDark ? 0.12 : 0.06),
                                          AppColors.error,
                                              () => _confirmDelete(
                                              task.id!, task.title)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconLabel(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: fg.withOpacity(0.15))),
        child: Icon(icon, color: fg, size: 15),
      ),
    );
  }

  Widget _swipeBg(
      Color color, IconData icon, String label, Alignment align, bool isDark) {
    final isRight = align == Alignment.centerRight;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [color.withOpacity(0.2), color.withOpacity(0.05)]
              : [color.withOpacity(0.12), Colors.white.withOpacity(0.6)],
          begin: isRight ? Alignment.centerRight : Alignment.centerLeft,
          end: isRight ? Alignment.centerLeft : Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      alignment: align,
      padding: EdgeInsets.only(right: isRight ? 24 : 0, left: isRight ? 0 : 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isRight) Icon(icon, color: color, size: 22),
          if (!isRight) const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          if (isRight) const SizedBox(width: 6),
          if (isRight) Icon(icon, color: color, size: 22),
        ],
      ),
    );
  }

  // ==================== حالة فارغة ====================
  Widget _buildEmptyState(String type, AppThemeColors colors, bool isDark) {
    IconData icon;
    String title;
    String sub;
    Color color;
    switch (type) {
      case 'completed':
        icon = Icons.emoji_events_rounded;
        title = 'لا توجد مهام منجزة بعد';
        sub = 'أكمل مهامك المفتوحة وستظهر هنا';
        color = AppColors.success;
        break;
      case 'overdue':
        icon = Icons.celebration_rounded;
        title = '🎉 ممتاز! لا متأخرات';
        sub = 'جميع مهامك في الموعد';
        color = AppColors.success;
        break;
      default:
        icon = Icons.add_task_rounded;
        title = 'لا توجد مهام مفتوحة';
        sub = 'اضغط + لإضافة مهمة جديدة';
        color = AppColors.primary;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.02)]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text(sub,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ==================== FAB ====================
  Widget _buildFAB(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight]),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 5))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openForm(),
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppColors.navy, size: 22),
                SizedBox(width: 6),
                Text('مهمة جديدة',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== فتح النموذج ====================
  void _openForm({TaskEntity? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => _TaskFormSheet(
        isDark: ref.watch(themeModeProvider) == ThemeMode.dark,
        task: task,
        onSaved: (isEdit) async {
          _showSuccessOverlay(isEdit);
        },
      ),
    );
  }

  // ==================== نافذة نجاح الحفظ ====================
  void _showSuccessOverlay(bool isEdit) {
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'success',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, a1, a2, child) => Transform.scale(
        scale: Curves.easeOutBack.transform(a1.value),
        child: Opacity(opacity: a1.value, child: child),
      ),
      pageBuilder: (ctx, _, __) {
        Timer(const Duration(milliseconds: 1800), () {
          if (ctx.mounted && Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });
        return Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.navyCard : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.success.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, val, __) => Transform.scale(
                    scale: val,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppColors.success, Color(0xFF34D399)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 42),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEdit ? 'تم التحديث بنجاح! ✨' : 'تم الحفظ بنجاح! 🎉',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isEdit ? 'تم تحديث بيانات المهمة' : 'تمت إضافة المهمة الجديدة',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== تفاصيل المهمة ====================
  void _showDetails(TaskEntity task) {
    final isCompleted = task.isCompleted;
    final priority = task.priority;
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    Color pColor;
    String pLabel;
    switch (priority) {
      case 3:
        pColor = AppColors.error;
        pLabel = 'عاجلة 🔴';
        break;
      case 2:
        pColor = AppColors.primary;
        pLabel = 'متوسطة ⭐';
        break;
      default:
        pColor = AppColors.success;
        pLabel = 'عادية 🟢';
    }

    String tLabel;
    IconData tIcon;
    switch (task.taskType) {
      case 0:
        tLabel = 'تسليم بضاعة 🚚';
        tIcon = Icons.local_shipping_rounded;
        break;
      case 1:
        tLabel = 'إعادة تخزين 📦';
        tIcon = Icons.inventory_rounded;
        break;
      default:
        tLabel = 'مهام عامة 📝';
        tIcon = Icons.assignment_rounded;
    }

    final Color sheetBg = isDark ? AppColors.navyCard : Colors.white;
    final Color titleColor =
    isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color borderColor =
    isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
    final Color descBg = isDark ? AppColors.navy : const Color(0xFFF8FAFC);

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
              top: BorderSide(
                  color: AppColors.primary.withOpacity(0.35), width: 1.5)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary.withOpacity(0.18),
                            AppColors.primary.withOpacity(0.06)
                          ]),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.assignment_rounded,
                          color: AppColors.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(task.title,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: titleColor))),
                ]),
                if (task.description != null &&
                    task.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: descBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor)),
                    child: Text(task.description!,
                        style: TextStyle(
                            fontSize: 13, height: 1.6, color: subColor)),
                  ),
                ],
                const SizedBox(height: 16),
                _detailLine(
                    Icons.event_rounded,
                    'الاستحقاق',
                    task.dueDate != null
                        ? DateFormat('d MMM yyyy', 'ar').format(task.dueDate!)
                        : 'غير محدد',
                    titleColor,
                    subColor),
                _detailLine(Icons.flag_rounded, 'الأولوية', pLabel, titleColor,
                    subColor,
                    valueColor: pColor),
                _detailLine(tIcon, 'النوع', tLabel, titleColor, subColor),
                _detailLine(Icons.info_outline_rounded, 'الحالة',
                    isCompleted ? 'منجزة ✅' : 'مفتوحة ⏳', titleColor, subColor,
                    valueColor:
                    isCompleted ? AppColors.success : AppColors.info),
                const SizedBox(height: 22),
                Row(children: [
                  if (!isCompleted) ...[
                    Expanded(
                      child: _gradientButton(
                          'إكمال المهمة',
                          Icons.check_rounded,
                          [AppColors.success, const Color(0xFF34D399)],
                          Colors.white, () {
                        Navigator.pop(context);
                        ref.read(taskProvider.notifier).completeTask(task.id!);
                      }),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: subColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: borderColor),
                      ),
                      child: const Text('إغلاق',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailLine(IconData icon, String label, String value,
      Color titleColor, Color subColor,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: subColor)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? titleColor)),
        ],
      ),
    );
  }

  Widget _gradientButton(String label, IconData icon, List<Color> colorsList,
      Color fg, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: colorsList),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: colorsList.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== تأكيد الحذف ====================
  Future<bool> _showDeleteConfirm(String title) async {
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    final Color dialogBg = isDark ? AppColors.navyCard : Colors.white;
    final Color subColor =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الحذف',
            style:
            TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content:
        Text('هل تريد حذف "$title"؟', style: TextStyle(color: subColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: subColor))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('حذف',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _confirmDelete(int id, String title) async {
    final confirmed = await _showDeleteConfirm(title);
    if (confirmed && mounted) {
      ref.read(taskProvider.notifier).deleteTask(id);
    }
  }

  // ==================== نافذة السداد الذكي ====================
  void _showTaskPaymentDialog(TaskEntity task) async {
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    final Color dialogBg = isDark ? AppColors.navyCard : Colors.white;
    final Color titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color inputFill = isDark ? AppColors.navy : const Color(0xFFF8FAFC);

    // جلب بيانات الفاتورة
    final db = ref.read(databaseHelperProvider);
    Map<String, dynamic>? invoiceData;
    double remainingAmount = 0.0;
    double totalAmount = 0.0;
    String invoiceNumber = '';

    if (task.relatedType == 'sales_invoice' || task.relatedType == 'purchase_invoice') {
      try {
        if (task.relatedType == 'sales_invoice') {
          invoiceData = await db.getSaleInvoiceById(task.relatedId!);
        } else {
          invoiceData = await db.getPurchaseInvoiceById(task.relatedId!);
        }
        if (invoiceData != null) {
          totalAmount = (invoiceData['total_amount'] as num?)?.toDouble() ?? 0.0;
          final paid = (invoiceData['paid_amount'] as num?)?.toDouble() ?? 0.0;
          remainingAmount = totalAmount - paid;
          invoiceNumber = invoiceData['invoice_number'] ?? '';
        }
      } catch (e) {
        _snack('خطأ في جلب بيانات الفاتورة', AppColors.error);
        return;
      }
    }

    if (remainingAmount <= 0) {
      _snack('هذه الفاتورة مسددة بالكامل', AppColors.warning);
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final dueDateController = TextEditingController();
    DateTime? selectedDueDate = invoiceData?['due_date'] != null
        ? DateTime.tryParse(invoiceData!['due_date'])
        : null;

    bool isFullPayment = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  task.relatedType == 'sales_invoice'
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  task.relatedType == 'sales_invoice'
                      ? 'تحصيل دفعة'
                      : 'سداد دفعة',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: titleColor),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عرض المتبقي الحالي
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المبلغ المتبقي:', style: TextStyle(color: subColor)),
                          Text(
                            '${_formatNumber(remainingAmount)} ريال',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // حقل المبلغ المدفوع
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: titleColor),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع *',
                        labelStyle: TextStyle(color: subColor),
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            color: AppColors.primary),
                        suffixText: 'ريال',
                        suffixStyle: TextStyle(color: subColor),
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'رقم غير صحيح';
                        if (val > remainingAmount) return 'المبلغ يتجاوز المتبقي';
                        return null;
                      },
                      onChanged: (v) {
                        final val = double.tryParse(v) ?? 0;
                        setDialogState(() {
                          isFullPayment = val >= remainingAmount;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // حقل تاريخ الاستحقاق الجديد (يظهر فقط إذا كان المبلغ المدفوع أقل من المتبقي)
                    if (!isFullPayment) ...[
                      GestureDetector(
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDueDate = picked;
                              dueDateController.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selectedDueDate != null ? AppColors.primary : AppColors.cardColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dueDateController.text.isEmpty
                                      ? 'تحديد تاريخ الاستحقاق الجديد (اختياري)'
                                      : dueDateController.text,
                                  style: TextStyle(
                                    color: dueDateController.text.isEmpty
                                        ? subColor
                                        : AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (selectedDueDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedDueDate = null;
                                      dueDateController.clear();
                                    });
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: AppColors.error, size: 16),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يمكنك تحديث تاريخ استحقاق المبلغ المتبقي',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: TextStyle(color: subColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final amount = double.parse(amountController.text.trim());

                  Navigator.pop(ctx);

                  final result = await ref.read(taskProvider.notifier).recordInvoicePayment(
                    taskId: task.id!,
                    invoiceId: task.relatedId!,
                    invoiceType: task.relatedType!,
                    amountPaid: amount,
                    newDueDate: selectedDueDate?.toIso8601String(),
                  );

                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تسجيل الدفعة والسند بنجاح ✅'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    // ✅ طباعة السند فوراً باستخدام رقم السند من النتيجة
                    try {
                      final voucherNumber = result['voucherNumber'];
                      if (voucherNumber != null && voucherNumber.isNotEmpty) {
                        final db = ref.read(databaseHelperProvider);
                        final voucherData = await db.rawQuery(
                          'SELECT * FROM financial_vouchers WHERE voucher_number = ?',
                          [voucherNumber],
                        );
                        if (voucherData.isNotEmpty) {
                          await InvoicePrinter.printFinancialVoucher(voucherData.first);
                        } else {
                          _snack('تم التسجيل، لكن لم يتم العثور على السند للطباعة', AppColors.warning);
                        }
                      } else {
                        _snack('تم التسجيل، يمكنك طباعة السند من قائمة السندات المالية', AppColors.info);
                      }
                    } catch (e) {
                      _snack('تم التسجيل، لكن فشلت طباعة السند: $e', AppColors.warning);
                    }
                  } else {
                    _snack('فشل التسجيل: ${result['message']}', AppColors.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('تأكيد السداد',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      amountController.dispose();
      dueDateController.dispose();
    });
  }
}

// ==============================================================================
// نموذج إضافة/تعديل المهمة
// ==============================================================================
class _TaskFormSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final TaskEntity? task;
  final void Function(bool isEdit)? onSaved;

  const _TaskFormSheet({
    required this.isDark,
    this.task,
    this.onSaved,
  });

  @override
  ConsumerState<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<_TaskFormSheet> {
  late TextEditingController titleCtrl, descCtrl, dueDateCtrl;
  DateTime? selectedDate;
  int priority = 1;
  int taskType = 2;
  bool _isSaving = false;

  Color get _cardBorder =>
      widget.isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
  Color get _inputFill =>
      widget.isDark ? AppColors.navy : const Color(0xFFF8FAFC);
  Color get _textMain =>
      widget.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSub =>
      widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    titleCtrl = TextEditingController(text: t?.title ?? '');
    descCtrl = TextEditingController(text: t?.description ?? '');
    dueDateCtrl = TextEditingController(
        text: t?.dueDate != null
            ? DateFormat('yyyy-MM-dd').format(t!.dueDate!)
            : '');
    selectedDate = t?.dueDate;
    priority = t?.priority ?? 1;
    taskType = t?.taskType ?? 2;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    dueDateCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: _textSub, fontSize: 13),
    prefixIcon: Icon(icon, color: AppColors.primary, size: 19),
    filled: true,
    fillColor: _inputFill,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cardBorder, width: 0.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );

  void _showSnackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (titleCtrl.text.trim().isEmpty) {
      _showSnackError('يرجى كتابة عنوان المهمة');
      return;
    }
    setState(() => _isSaving = true);

    final isEdit = widget.task != null;

    final data = {
      'title': titleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'task_type': taskType,
      'priority': priority,
      'status': widget.task?.status ?? 0,
      'created_at': widget.task?.createdAt.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'due_date': selectedDate?.toIso8601String(),
      'related_type': 'general',
      'related_id': 0,
    };

    try {
      if (isEdit) {
        await ref
            .read(taskProvider.notifier)
            .updateTask(widget.task!.id!, data);
      } else {
        await ref.read(taskProvider.notifier).addTask(data);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved?.call(isEdit);
      }
    } catch (e) {
      if (mounted) _showSnackError('حدث خطأ أثناء الحفظ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    return Container(
      constraints:
      BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.navyCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
            top: BorderSide(
                color: AppColors.primary.withOpacity(0.35), width: 1.5)),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const SizedBox(height: 12),
      Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: (widget.isDark ? Colors.white : Colors.black)
                .withOpacity(0.15),
            borderRadius: BorderRadius.circular(2)),
      ),
      Flexible(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
              top: 20,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withOpacity(0.18),
                    AppColors.primary.withOpacity(0.06)
                  ]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_task_rounded,
                    color: AppColors.primary,
                    size: 20),
              ),
              const SizedBox(width: 10),
              Text(isEdit ? 'تعديل المهمة' : 'مهمة جديدة',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _textMain)),
            ]),
            const SizedBox(height: 24),
            TextField(
                controller: titleCtrl,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _textMain,
                    fontSize: 14),
                decoration: _decor('عنوان المهمة *', Icons.title_rounded)),
            const SizedBox(height: 14),
            TextField(
                controller: descCtrl,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(fontSize: 13, color: _textMain),
                decoration:
                _decor('التفاصيل (اختياري)', Icons.subject_rounded)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                      builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                  primary: AppColors.primary,
                                  surface: AppColors.navyCard,
                                  onSurface: Colors.white)),
                          child: child!),
                    );
                    if (d != null) {
                      setState(() {
                        selectedDate = d;
                        dueDateCtrl.text =
                            DateFormat('yyyy-MM-dd').format(d);
                      });
                    }
                  },
                  child: AbsorbPointer(
                      child: TextField(
                          controller: dueDateCtrl,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _textMain),
                          decoration: _decor(
                              'الاستحقاق', Icons.calendar_month_rounded))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: priority,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary, size: 20),
                  dropdownColor:
                  widget.isDark ? AppColors.navyCard : Colors.white,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _textMain,
                      fontFamily: 'Cairo'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('عادية 🟢')),
                    DropdownMenuItem(value: 2, child: Text('متوسطة ⭐')),
                    DropdownMenuItem(value: 3, child: Text('عاجلة 🔴')),
                  ],
                  onChanged: (v) => setState(() => priority = v ?? 1),
                  decoration: _decor('الأولوية', Icons.flag_rounded),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: taskType,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary, size: 20),
              dropdownColor:
              widget.isDark ? AppColors.navyCard : Colors.white,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _textMain,
                  fontFamily: 'Cairo'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('تسليم بضاعة 🚚')),
                DropdownMenuItem(value: 1, child: Text('إعادة تخزين 📦')),
                DropdownMenuItem(value: 2, child: Text('مهام عامة 📝')),
              ],
              onChanged: (v) => setState(() => taskType = v ?? 2),
              decoration: _decor('نوع المهمة', Icons.category_rounded),
            ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _textSub,
                          side: BorderSide(color: _cardBorder, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: Text('إلغاء',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textSub)),
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _isSaving
                          ? null
                          : const LinearGradient(colors: [
                        AppColors.primary,
                        AppColors.primaryLight
                      ]),
                      color: _isSaving ? _cardBorder : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isSaving
                          ? null
                          : [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSaving ? null : _save,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.navy))
                              : Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(
                                  isEdit
                                      ? Icons.save_rounded
                                      : Icons.add_task_rounded,
                                  size: 18,
                                  color: AppColors.navy),
                              const SizedBox(width: 6),
                              Text(
                                  isEdit
                                      ? 'حفظ التعديلات'
                                      : 'إضافة المهمة',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: AppColors.navy)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ],
      ),
    );
  }
}