// lib/modules/warehouses/views/damaged_products_screen.dart
// ✅ تصميم فاخر Premium Navy/Gold — محول إلى Riverpod بالكامل
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/invoice_printer.dart';
import '../providers/damaged_products_provider.dart';

class DamagedProductsScreen extends ConsumerStatefulWidget {
  const DamagedProductsScreen({super.key});

  @override
  ConsumerState<DamagedProductsScreen> createState() => _DamagedProductsScreenState();
}

class _DamagedProductsScreenState extends ConsumerState<DamagedProductsScreen> {
  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.toString().trim().isEmpty || dateString == 'غير محدد') {
      return 'غير محدد';
    }
    try {
      if (dateString is DateTime) {
        return "${dateString.year}-${dateString.month.toString().padLeft(2, '0')}-${dateString.day.toString().padLeft(2, '0')}";
      }
      String str = dateString.toString();
      if (str.contains('T')) return str.split('T')[0];
      if (str.contains(' ')) return str.split(' ')[0];
      return str;
    } catch (_) {
      return dateString.toString();
    }
  }

  void _snack(String title, String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text('$title: $msg')),
        ]),
        backgroundColor: (error ? AppColors.error : AppColors.success).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final s = ref.read(damagedProductsProvider).value!;
    DateTime tempStart = s.startDate ?? DateTime.now();
    DateTime tempEnd = s.endDate ?? DateTime.now();
    bool isSelectingStart = true;
    final colors = _colors;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: 480,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: colors.cardBorder, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text('تحديد فترة التقرير', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textMain)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheetState(() => isSelectingStart = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelectingStart ? AppColors.error.withOpacity(0.1) : Colors.transparent,
                        border: Border.all(color: isSelectingStart ? AppColors.error : colors.cardBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(children: [
                        Text('من تاريخ', style: TextStyle(color: isSelectingStart ? AppColors.error : colors.textSub, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_formatDate(tempStart), style: TextStyle(color: isSelectingStart ? AppColors.error : colors.textMain, fontWeight: FontWeight.w900, fontSize: 16)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheetState(() => isSelectingStart = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !isSelectingStart ? AppColors.error.withOpacity(0.1) : Colors.transparent,
                        border: Border.all(color: !isSelectingStart ? AppColors.error : colors.cardBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(children: [
                        Text('إلى تاريخ', style: TextStyle(color: !isSelectingStart ? AppColors.error : colors.textSub, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_formatDate(tempEnd), style: TextStyle(color: !isSelectingStart ? AppColors.error : colors.textMain, fontWeight: FontWeight.w900, fontSize: 16)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: colors.cardBorder.withOpacity(0.5)))),
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: colors.scaffoldBg == AppColors.navy ? Brightness.dark : Brightness.light,
                      textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: colors.textMain, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    child: CupertinoDatePicker(
                      key: ValueKey<bool>(isSelectingStart),
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: isSelectingStart ? tempStart : tempEnd,
                      minimumDate: DateTime(2020),
                      maximumDate: DateTime.now().add(const Duration(days: 365)),
                      onDateTimeChanged: (DateTime newDate) {
                        setSheetState(() {
                          if (isSelectingStart) {
                            tempStart = newDate;
                            if (tempEnd.isBefore(tempStart)) tempEnd = tempStart;
                          } else {
                            tempEnd = newDate;
                            if (tempStart.isAfter(tempEnd)) tempStart = tempEnd;
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    ref.read(damagedProductsProvider.notifier).setDateRange(tempStart, tempEnd);
                    Navigator.pop(ctx);
                  },
                  child: const Text('حسناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleReturnToInventory(int id) async {
    final colors = _colors;
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'return_confirm',
      pageBuilder: (context, anim1, anim2) => AlertDialog(
        backgroundColor: colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colors.cardBorder)),
        title: Row(children: [
          Icon(Icons.settings_backup_restore_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 10),
          Text('تأكيد الإرجاع', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 18)),
        ]),
        content: Text('هل أنت متأكد من إلغاء هذه العملية وإرجاع الكمية إلى المخزون الفعلي؟ سيتم حذف هذا السجل نهائياً.',
            style: TextStyle(color: colors.textMain, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: TextStyle(color: colors.textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، أرجع للمخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      transitionBuilder: (context, anim1, anim2, child) => Transform.scale(scale: anim1.value, child: Opacity(opacity: anim1.value, child: child)),
    );

    if (confirm == true) {
      final success = await ref.read(damagedProductsProvider.notifier).returnToInventory(id);
      _snack(success ? 'نجاح' : 'خطأ', success ? 'تم إرجاع الكمية للمخزون بنجاح' : 'فشل عملية الإرجاع', error: !success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(damagedProductsProvider);
    final colors = _colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.error)),
        error: (err, _) => Center(child: Text('خطأ: $err', style: const TextStyle(color: AppColors.error))),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(damagedProductsProvider),
          color: AppColors.error,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildSliverAppBar(colors, s),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: s.filteredLog.isEmpty ? SliverFillRemaining(child: _buildEmptyState(colors, s)) : _buildContent(colors, s),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(AppThemeColors colors, DamagedProductsState s) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: colors.appBarBg,
      foregroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), onPressed: () => Navigator.pop(context)),
      title: const Text('سجل التوالف والتسويات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'تصدير إلى Excel',
          icon: const Icon(Icons.table_view_rounded, size: 22),
          onPressed: () {
            if (s.filteredLog.isEmpty) { _snack('تنبيه', 'لا توجد بيانات للتصدير', error: true); return; }
            InvoicePrinter.exportToExcel(s.filteredLog);
            _snack('تصدير إكسل', 'جاري تجهيز وتصدير سجل التوالف...');
          },
        ),
        IconButton(
          tooltip: 'تصفية بالتاريخ',
          icon: Icon(s.startDate == null ? Icons.filter_alt_outlined : Icons.filter_alt, size: 22, color: s.startDate != null ? AppColors.primary : null),
          onPressed: _selectDateRange,
        ),
        if (s.startDate != null)
          IconButton(tooltip: 'إلغاء التصفية', icon: const Icon(Icons.clear_rounded, size: 22), onPressed: () => ref.read(damagedProductsProvider.notifier).clearFilter()),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors.scaffoldBg == AppColors.navy ? [AppColors.navy, AppColors.navyMedium] : [AppColors.navy, AppColors.navyMedium], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic,
                  builder: (_, val, child) => Opacity(opacity: val, child: Transform.scale(scale: 0.85 + (0.15 * val), child: child)),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.error.withOpacity(0.12), AppColors.error.withOpacity(0.04)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.error.withOpacity(0.25))),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.trending_down_rounded, color: AppColors.error, size: 20), const SizedBox(width: 8), Text('إجمالي الخسائر (للفترة المحددة)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12))]),
                      const SizedBox(height: 10),
                      FittedBox(child: Text('${NumberFormat('#,##0.00', 'en').format(s.totalLoss)} ﷼', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Text('عدد العمليات: ${s.filteredLog.length}', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppThemeColors colors, DamagedProductsState s) {
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 14),
        ...s.filteredLog.asMap().entries.map((e) {
          final i = e.key;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 300 + (i.clamp(0, 8) * 50)), curve: Curves.easeOutCubic,
            builder: (_, val, child) => Transform.translate(offset: Offset(25 * (1 - val), 0), child: Opacity(opacity: val, child: child)),
            child: _buildDamagedCard(colors, e.value),
          );
        }),
      ]),
    );
  }

  Widget _buildEmptyState(AppThemeColors colors, DamagedProductsState s) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(gradient: RadialGradient(colors: [AppColors.success.withOpacity(0.12), AppColors.success.withOpacity(0.03)]), shape: BoxShape.circle), child: Icon(Icons.verified_rounded, size: 56, color: AppColors.success.withOpacity(0.5))),
        const SizedBox(height: 20),
        Text(s.startDate != null ? 'لا توجد سجلات في هذا التاريخ' : 'سجل التوالف فارغ 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textMain)),
        const SizedBox(height: 6),
        Text('لا توجد أي خسائر مسجلة حتى الآن', style: TextStyle(color: colors.textSub, fontSize: 13)),
      ]),
    );
  }

  Widget _buildDamagedCard(AppThemeColors colors, Map<String, dynamic> item) {
    final name = item['product_name'] ?? 'منتج غير معروف';
    final qty = item['quantity'] ?? 0;
    final loss = (item['total_loss'] as num?)?.toDouble() ?? 0.0;
    final reason = item['reason'] ?? 'لا يوجد';
    final invNum = item['invoice_number'] ?? 'N/A';
    final String moveDateStr = _formatDate(item['move_date']);
    final String expiryDateStr = _formatDate(item['expiry_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.cardBorder)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(width: 5, decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.error, AppColors.error], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('فاتورة: $invNum', style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold))),
                    const Spacer(),
                    Text('نقل: $moveDateStr', style: TextStyle(fontSize: 10, color: colors.textHint)),
                    const SizedBox(width: 8),
                    IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.error, size: 20), onPressed: () => _handleReturnToInventory(item['id']), tooltip: 'إرجاع للمخزون'),
                  ]),
                  const SizedBox(height: 10),
                  Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textMain)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.report_problem_rounded, size: 14, color: colors.textSub), const SizedBox(width: 4),
                    Text('المستودع: ${item['warehouse_name'] ?? 'غير معروف'}', style: TextStyle(fontSize: 11, color: colors.textSub)),
                    const Spacer(), Text('انتهاء: $expiryDateStr', style: TextStyle(fontSize: 10, color: colors.textSub)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withOpacity(0.1))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الكمية', style: TextStyle(fontSize: 10, color: colors.textHint)), const SizedBox(height: 2), Text('$qty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textMain))]),
                      Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text('التكلفة', style: TextStyle(fontSize: 10, color: colors.textHint)), const SizedBox(height: 2), Text('${item['unit_cost']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textMain))]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('قيمة الخسارة', style: TextStyle(fontSize: 10, color: AppColors.error.withOpacity(0.7))), const SizedBox(height: 2), Text('${NumberFormat('#,##0.00', 'en').format(loss)} ﷼', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.error))]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: Text('بواسطة: ${item['moved_by_name'] ?? 'غير محدد'}', style: TextStyle(fontSize: 11, color: colors.textHint))), Text('السبب: $reason', style: TextStyle(fontSize: 11, color: colors.textHint))]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => InvoicePrinter.printDamagedInvoice(item),
                        icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('طباعة إشعار التوالف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(foregroundColor: colors.textMain, side: BorderSide(color: colors.cardBorder), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}