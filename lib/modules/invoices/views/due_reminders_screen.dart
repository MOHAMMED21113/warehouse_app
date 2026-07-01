// lib/modules/invoices/views/due_reminders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/whatsapp_service.dart';
import '../providers/due_reminders_provider.dart';

class DueRemindersScreen extends ConsumerStatefulWidget {
  const DueRemindersScreen({super.key});

  @override
  ConsumerState<DueRemindersScreen> createState() =>
      _DueRemindersScreenState();
}

class _DueRemindersScreenState extends ConsumerState<DueRemindersScreen> {
  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _sendReminder(Map<String, dynamic> invoice) async {
    final notifier = ref.read(dueRemindersProvider.notifier);
    final customerName = invoice['customer_name'] ?? 'العميل الكريم';
    final customerPhone = invoice['customer_phone']?.toString() ?? '';
    final invoiceNumber = invoice['invoice_number'] ?? '';
    final totalAmount = (invoice['total_amount'] ?? 0).toDouble();
    final paidAmount = (invoice['paid_amount'] ?? 0).toDouble();
    final remainingAmount = totalAmount - paidAmount;
    final dueDate = invoice['due_date']?.toString() ?? '';

    if (customerPhone.isEmpty) {
      _snack('لا يوجد رقم هاتف مسجل لهذا العميل', AppColors.warning);
      return;
    }

    String formattedDueDate = dueDate;
    try {
      final date = DateTime.parse(dueDate);
      formattedDueDate = DateFormat('yyyy/MM/dd', 'ar').format(date);
    } catch (_) {}

    final message = '''
مرحباً عزيزي $customerName،

نود تذكيركم بلطف بقرب موعد استحقاق الدفعة المتبقية من الفاتورة التالية:

📄 رقم الفاتورة: $invoiceNumber
💰 إجمالي الفاتورة: ${totalAmount.toStringAsFixed(2)} ريال
💵 المبلغ المدفوع: ${paidAmount.toStringAsFixed(2)} ريال
⚠️ المبلغ المتبقي (المطلوب سداده): ${remainingAmount.toStringAsFixed(2)} ريال
📅 تاريخ الاستحقاق: $formattedDueDate

نأمل منكم التكرم بالسداد في أقرب وقت ممكن.
شاكرين ومقدرين لكم تعاونكم الدائم 🤝

مع أطيب التحيات،
المخازن الذكي
''';

    notifier.state = AsyncValue.data(
        notifier.state.value!.copyWith(sendingToId: invoice['id']));
    try {
      await WhatsAppService.sendInvoiceToWhatsApp(
        phoneNumber: customerPhone,
        customerName: customerName,
        invoiceNumber: invoiceNumber,
        date: DateTime.now().toIso8601String(),
        totalAmount: totalAmount,
        paymentStatus: invoice['payment_status'] ?? 'جزئي',
        paidAmount: paidAmount,
        items: [
          {
            'productName': 'المبلغ المتبقي المستحق',
            'quantity': 1,
            'unitPrice': remainingAmount,
          },
        ],
        shopName: 'المخازن الذكي - تذكير',
      );

      if (mounted) {
        _snack(
            '✅ تم إرسال تذكير واتساب إلى $customerName بنجاح',
            AppColors.success);
      }
    } catch (e) {
      _snack('❌ خطأ: $e', AppColors.error);
    } finally {
      notifier.state = AsyncValue.data(
          notifier.state.value!.copyWith(clearSendingToId: true));
    }
  }

  Future<void> _showReminderSettingsDialog() async {
    final controller = TextEditingController(
      text: ref
          .read(dueRemindersProvider)
          .value
          ?.reminderDaysBefore
          .toString() ??
          '3',
    );
    final formKey = GlobalKey<FormState>();
    final colors = _colors;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBg,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'إعدادات التذكير',
            style: TextStyle(
                color: colors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ]),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حدد عدد الأيام التي تريد أن يظهر فيها التذكير قبل موعد استحقاق الفاتورة',
                style: TextStyle(color: colors.textSub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.textMain),
                decoration: InputDecoration(
                  labelText: 'عدد الأيام',
                  hintText: 'مثال: 3',
                  suffixText: 'يوم',
                  prefixIcon: Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary),
                  filled: true,
                  fillColor: colors.inputFill,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'مطلوب';
                  final val = int.tryParse(v);
                  if (val == null || val < 1 || val > 30) {
                    return 'أدخل رقماً بين 1 و 30';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: colors.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final days = int.parse(controller.text.trim());
                Navigator.pop(ctx, days);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(dueRemindersProvider.notifier).setReminderDays(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(dueRemindersProvider);
    final colors = _colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'تذكير بالديون المتأخرة',
          style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.timer_rounded, color: AppColors.primary),
            onPressed: _showReminderSettingsDialog,
            tooltip: 'إعدادات التذكير',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.navy,
                AppColors.primary.withOpacity(0.6),
                AppColors.warning,
              ]),
            ),
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.primary))),
        error: (e, _) =>
            Center(child: Text('خطأ: $e', style: const TextStyle(color: AppColors.error))),
        data: (state) {
          if (state.invoices.isEmpty) {
            return _buildEmptyState(colors, state);
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(dueRemindersProvider),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.invoices.length,
              itemBuilder: (context, index) {
                return _buildInvoiceCard(
                    colors, state.invoices[index], state);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
      AppThemeColors colors, DueRemindersState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 80,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد فواتير مستحقة قريباً',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جميع الفواتير مدفوعة أو بعيدة الاستحقاق',
            style: TextStyle(fontSize: 14, color: colors.textSub),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'نطاق التذكير الحالي: ${state.reminderDaysBefore} أيام',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showReminderSettingsDialog,
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('تغيير عدد الأيام'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(AppThemeColors colors,
      Map<String, dynamic> invoice, DueRemindersState state) {
    final customerName =
        invoice['customer_name'] ?? 'عميل غير معروف';
    final customerPhone =
        invoice['customer_phone']?.toString() ?? '';
    final invoiceNumber = invoice['invoice_number'] ?? '';
    final totalAmount =
    (invoice['total_amount'] ?? 0).toDouble();
    final paidAmount =
    (invoice['paid_amount'] ?? 0).toDouble();
    final remainingAmount = totalAmount - paidAmount;
    final dueDate = invoice['due_date']?.toString() ?? '';
    final isSending = state.sendingToId == invoice['id'];

    int? daysLeft;
    Color dueDateColor = AppColors.warning;
    String dueDateLabel = '';

    if (dueDate.isNotEmpty) {
      try {
        final dueDateTime = DateTime.parse(dueDate);
        final now = DateTime.now();
        final difference = dueDateTime.difference(now).inDays;
        daysLeft = difference;

        if (difference < 0) {
          dueDateColor = AppColors.error;
          dueDateLabel = 'متأخرة بـ ${-difference} يوم';
        } else if (difference == 0) {
          dueDateColor = AppColors.error;
          dueDateLabel = 'اليوم (آخر موعد)';
        } else if (difference == 1) {
          dueDateColor = AppColors.error;
          dueDateLabel = 'غداً';
        } else {
          dueDateColor = AppColors.warning;
          dueDateLabel = 'متبقي $difference يوم';
        }
      } catch (_) {
        dueDateLabel = dueDate.substring(0, 10);
      }
    }

    String formattedDueDate = '';
    try {
      final date = DateTime.parse(dueDate);
      formattedDueDate =
          DateFormat('yyyy/MM/dd', 'ar').format(date);
    } catch (_) {
      formattedDueDate = dueDate;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: dueDateColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: dueDateColor.withOpacity(0.08),
                border: Border(
                    bottom: BorderSide(
                        color: colors.cardBorder)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: dueDateColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    daysLeft != null && daysLeft < 0
                        ? Icons.warning_amber_rounded
                        : Icons.timer_rounded,
                    color: dueDateColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فاتورة رقم: $invoiceNumber',
                        style: TextStyle(
                          color: colors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(
                          'تاريخ الاستحقاق: $formattedDueDate',
                          style: TextStyle(
                              color: colors.textSub,
                              fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        if (dueDateLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: dueDateColor
                                  .withOpacity(0.12),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Text(
                              dueDateLabel,
                              style: TextStyle(
                                color: dueDateColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withOpacity(0.1),
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: AppColors.primary,
                          size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: TextStyle(
                              color: colors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (customerPhone.isNotEmpty)
                            Text(
                              customerPhone,
                              style: TextStyle(
                                  color: colors.textSub,
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius:
                      BorderRadius.circular(12),
                      border: Border.all(
                          color: colors.cardBorder),
                    ),
                    child: Column(children: [
                      _infoRow(colors, 'إجمالي الفاتورة',
                          '${totalAmount.toStringAsFixed(2)} ريال',
                          AppColors.primary),
                      const SizedBox(height: 6),
                      _infoRow(colors, 'المبلغ المدفوع',
                          '${paidAmount.toStringAsFixed(2)} ريال',
                          AppColors.success),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      _infoRow(
                        colors,
                        'المبلغ المتبقي (المطلوب)',
                        '${remainingAmount.toStringAsFixed(2)} ريال',
                        AppColors.error,
                        bold: true,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isSending
                          ? null
                          : () => _sendReminder(invoice),
                      icon: isSending
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.whatshot,
                          size: 20),
                      label: Text(
                        isSending
                            ? 'جاري الإرسال...'
                            : 'إرسال تذكير واتساب',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(AppThemeColors colors, String label, String value,
      Color color,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSub, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}