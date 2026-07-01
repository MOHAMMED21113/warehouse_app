// lib/modules/accounting/views/financial_vouchers_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/widgets/transaction_guard.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/invoice_printer.dart';
import '../../../database/database_helper.dart';
import '../providers/financial_vouchers_provider.dart';

class FinancialVouchersScreen extends ConsumerStatefulWidget {
  const FinancialVouchersScreen({super.key});

  @override
  ConsumerState<FinancialVouchersScreen> createState() =>
      _FinancialVouchersScreenState();
}

class _FinancialVouchersScreenState
    extends ConsumerState<FinancialVouchersScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  AppThemeColors get _c =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── فلترة + بحث ───
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    // 1. فلترة حسب التبويب
    List<Map<String, dynamic>> result;
    if (_tabCtrl.index == 0) {
      result = all;
    } else {
      final t = _tabCtrl.index == 1 ? 'payment' : 'receipt';
      result = all.where((v) => v['type'] == t).toList();
    }

    // 2. فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      result = result.where((v) {
        final name = (v['category_name'] ?? '').toString().toLowerCase();
        final number = (v['voucher_number'] ?? '').toString().toLowerCase();
        final notes = (v['notes'] ?? '').toString().toLowerCase();
        final amount = v['amount'].toString();
        return name.contains(_searchQuery) ||
            number.contains(_searchQuery) ||
            notes.contains(_searchQuery) ||
            amount.contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  double _sum(List<Map<String, dynamic>> list, String type) => list
      .where((v) => v['type'] == type)
      .fold(0.0, (s, v) => s + (v['amount'] as num).toDouble());

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  //  الشاشة الرئيسية
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financialVouchersProvider);
    final c = _c;

    if (state.isLoading && state.vouchers.isEmpty) {
      return Scaffold(
        backgroundColor: c.scaffoldBg,
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final vouchers = state.vouchers;
    final expense = _sum(vouchers, 'payment');
    final income = _sum(vouchers, 'receipt');
    final net = income - expense;
    final filtered = _applyFilters(vouchers);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      floatingActionButton: _isSelectionMode ? null : _fab(c),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _appBar(c, expense, income, net, vouchers.length, filtered),
        ],
        body: Column(
          children: [
            _tabs(c, vouchers),
            _searchBar(c),
            // شريط الإجراءات في وضع التحديد
            if (_isSelectionMode) _selectionBar(c, filtered),
            Expanded(
              child: filtered.isEmpty
                  ? _empty(c)
                  : RefreshIndicator(
                onRefresh: () => ref
                    .read(financialVouchersProvider.notifier)
                    .loadAllData(),
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _card(c, filtered[i], state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  1) الشريط العلوي
  // ═══════════════════════════════════════════════════════════════════
  SliverAppBar _appBar(AppThemeColors c, double expense, double income,
      double net, int count, List<Map<String, dynamic>> filtered) {
    final pos = net >= 0;
    final netClr = pos ? AppColors.success : AppColors.error;

    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: c.appBarBg,
      foregroundColor: AppColors.primary,
      leading: _isSelectionMode
          ? IconButton(
        icon: const Icon(Icons.close_rounded, size: 22),
        onPressed: _exitSelectionMode,
      )
          : IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: _isSelectionMode
          ? Text('تم تحديد ${_selectedIds.length}',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16))
          : const Text('المصروفات والإيرادات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      centerTitle: true,
      actions: [
        if (!_isSelectionMode) ...[
          // زر تصدير
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined, size: 22),
            color: c.cardBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'pdf_all') _exportAllPdf(c, filtered);
              if (val == 'excel_all') _exportExcel(filtered);
              if (val == 'select') {
                setState(() => _isSelectionMode = true);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pdf_all',
                child: Row(children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Text('تصدير الكل PDF',
                      style: TextStyle(color: c.textMain, fontSize: 13)),
                ]),
              ),
              PopupMenuItem(
                value: 'excel_all',
                child: Row(children: [
                  Icon(Icons.table_chart_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Text('تصدير الكل Excel',
                      style: TextStyle(color: c.textMain, fontSize: 13)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'select',
                child: Row(children: [
                  Icon(Icons.checklist_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text('تحديد للطباعة',
                      style: TextStyle(color: c.textMain, fontSize: 13)),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () =>
                ref.read(financialVouchersProvider.notifier).loadAllData(),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.navyMedium],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                netClr.withOpacity(0.15),
                                netClr.withOpacity(0.05)
                              ]),
                              borderRadius: BorderRadius.circular(18),
                              border:
                              Border.all(color: netClr.withOpacity(0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    pos
                                        ? Icons.arrow_circle_up_rounded
                                        : Icons.arrow_circle_down_rounded,
                                    color: netClr,
                                    size: 22),
                                const SizedBox(height: 4),
                                Text('الصافي',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color:
                                        Colors.white.withOpacity(0.6))),
                                FittedBox(
                                  child: Text(
                                    '${pos ? '+' : ''}${NumberFormat('#,##0', 'en').format(net)}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: netClr),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: netClr.withOpacity(0.15),
                                      borderRadius:
                                      BorderRadius.circular(6)),
                                  child: Text(pos ? 'ربح ↑' : 'خسارة ↓',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: netClr)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _miniStat('إجمالي الإيرادات', income,
                                  AppColors.success, Icons.trending_up_rounded),
                              const SizedBox(height: 6),
                              _miniStat('إجمالي المصروفات', expense,
                                  AppColors.error, Icons.trending_down_rounded),
                              const SizedBox(height: 6),
                              _miniStat(
                                  'عدد السندات',
                                  count.toDouble(),
                                  AppColors.info,
                                  Icons.receipt_long_rounded,
                                  isCount: true),
                            ],
                          ),
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
    );
  }

  Widget _miniStat(String label, double val, Color clr, IconData ico,
      {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: clr.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: clr.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(ico, size: 13, color: clr),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 10, color: clr.withOpacity(0.8)),
                overflow: TextOverflow.ellipsis),
          ),
          Text(
            isCount
                ? '${val.toInt()}'
                : NumberFormat('#,##0', 'en').format(val),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: clr),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  2) تبويبات + بحث
  // ═══════════════════════════════════════════════════════════════════
  Widget _tabs(AppThemeColors c, List<Map<String, dynamic>> all) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: TabBar(
        controller: _tabCtrl,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.primary.withOpacity(0.08)
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: c.textHint,
        dividerColor: Colors.transparent,
        labelStyle:
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          _tabLabel('الكل', all.length, AppColors.primary,
              Icons.receipt_long_rounded),
          _tabLabel(
              'مصروفات',
              all.where((v) => v['type'] == 'payment').length,
              AppColors.error,
              Icons.trending_down_rounded),
          _tabLabel(
              'إيرادات',
              all.where((v) => v['type'] == 'receipt').length,
              AppColors.success,
              Icons.trending_up_rounded),
        ],
      ),
    );
  }

  Widget _tabLabel(String text, int n, Color clr, IconData ico) {
    return Tab(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ico, size: 13, color: clr),
          const SizedBox(width: 3),
          Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11))),
          if (n > 0) ...[
            const SizedBox(width: 3),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: clr.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$n',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: clr)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchBar(AppThemeColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cardBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: c.textMain, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم، رقم السند، الملاحظات...',
          hintStyle: TextStyle(color: c.textHint, fontSize: 12),
          prefixIcon:
          Icon(Icons.search_rounded, color: c.textHint, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded,
                color: c.textHint, size: 18),
            onPressed: () => _searchCtrl.clear(),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  شريط الإجراءات (وضع التحديد)
  // ═══════════════════════════════════════════════════════════════════
  Widget _selectionBar(AppThemeColors c, List<Map<String, dynamic>> filtered) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // تحديد الكل
          InkWell(
            onTap: () {
              setState(() {
                if (_selectedIds.length == filtered.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.clear();
                  for (final v in filtered) {
                    _selectedIds.add(v['id'] as int);
                  }
                }
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _selectedIds.length == filtered.length
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text('الكل',
                    style: TextStyle(
                        color: c.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),
          // طباعة PDF المحدد
          if (_selectedIds.isNotEmpty) ...[
            _exportBtn(Icons.picture_as_pdf_rounded, AppColors.error,
                'PDF', () {
                  final selected = filtered
                      .where((v) => _selectedIds.contains(v['id']))
                      .toList();
                  _exportAllPdf(c, selected);
                }),
            const SizedBox(width: 8),
            _exportBtn(Icons.table_chart_rounded, AppColors.success,
                'Excel', () {
                  final selected = filtered
                      .where((v) => _selectedIds.contains(v['id']))
                      .toList();
                  _exportExcel(selected);
                }),
          ],
        ],
      ),
    );
  }

  Widget _exportBtn(
      IconData ico, Color clr, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: clr.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: clr.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ico, color: clr, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: clr,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  3) كارت السند — مطابق للصورة
  // ═══════════════════════════════════════════════════════════════════
  Widget _card(AppThemeColors c, Map<String, dynamic> v,
      FinancialVouchersState state) {
    final isPay = v['type'] == 'payment';
    final amt = (v['amount'] as num).toDouble();
    final date = DateTime.parse(v['date'].toString());
    final clr = isPay ? AppColors.error : AppColors.success;
    final lbl = isPay ? 'صرف (سحب) ↑' : 'قبض (إيداع) ↓';
    final voucherNum = v['voucher_number'] ?? '';
    final typeName = isPay ? 'سند صرف' : 'سند قبض';
    final catName = v['category_name'] ?? 'بند غير معروف';
    final isSelected = _selectedIds.contains(v['id']);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() => _isSelectionMode = true);
        }
        _toggleSelection(v['id'] as int);
      },
      onTap: _isSelectionMode
          ? () => _toggleSelection(v['id'] as int)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _isSelectionMode && isSelected
              ? clr.withOpacity(0.04)
              : c.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isSelected ? clr.withOpacity(0.4) : c.cardBorder,
              width: isSelected ? 1.5 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ─── المحتوى ───
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ═══ الصف الأول: شارة النوع + التاريخ والوقت ═══
                      Row(
                        children: [
                          // Checkbox في وضع التحديد
                          if (_isSelectionMode) ...[
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? clr : c.textHint,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          // شارة النوع
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: clr.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: clr.withOpacity(0.2)),
                            ),
                            child: Text(lbl,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: clr)),
                          ),
                          const Spacer(),
                          // التاريخ
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: c.textHint),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy/MM/dd', 'en').format(date),
                            style:
                            TextStyle(fontSize: 11, color: c.textSub),
                          ),
                          const SizedBox(width: 8),
                          // الوقت
                          Icon(Icons.access_time_rounded,
                              size: 12, color: c.textHint),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('hh:mm a', 'en').format(date),
                            style:
                            TextStyle(fontSize: 11, color: c.textSub),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ═══ الصف الثاني: رقم السند + اسم البند ═══
                      Text(
                        '$typeName رقم: $voucherNum  -  $catName',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: c.textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // ═══ الصف الثالث: المبلغ بارز ═══
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${isPay ? '-' : '+'} ${NumberFormat('#,##0.00', 'en').format(amt)} ريال',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: clr),
                        ),
                      ),

                      // ═══ الملاحظات ═══
                      if (v['notes'] != null &&
                          v['notes'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: c.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(v['notes'],
                              style: TextStyle(
                                  fontSize: 11, color: c.textSub),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],

                      // ═══ أزرار التحكم ═══
                      if (!_isSelectionMode) ...[
                        const SizedBox(height: 10),
                        Divider(height: 1, color: c.cardBorder),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _actionBtn(Icons.print_rounded,
                                AppColors.info, 'طباعة', () {
                                  _printSingleVoucher(c, v);
                                }),
                            const SizedBox(width: 8),
                            _actionBtn(Icons.edit_rounded,
                                AppColors.primary, 'تعديل', () {
                                  _openEditSheet(c, v);
                                }),
                            const SizedBox(width: 8),
                            _actionBtn(Icons.delete_outline_rounded,
                                AppColors.error, 'حذف', () {
                                  _confirmDelete(c, v['id'],
                                      v['category_name'] ?? '');
                                }),
                            const Spacer(),
                            // رقم السند المختصر
                            Text(
                              voucherNum,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: c.textHint,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // ─── الشريط اللوني الجانبي ───
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [clr, clr.withOpacity(0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData ico, Color clr, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: clr.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ico, color: clr, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: clr,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  4) حالة فارغة
  // ═══════════════════════════════════════════════════════════════════
  Widget _empty(AppThemeColors c) {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 52, color: c.textHint.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text('لا توجد نتائج لـ "$_searchQuery"',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.textMain)),
              const SizedBox(height: 6),
              Text('جرّب كلمة بحث مختلفة',
                  style: TextStyle(fontSize: 13, color: c.textSub)),
            ],
          ),
        ),
      );
    }

    final tab = _tabCtrl.index;
    final data = [
      {'t': 'لا توجد سندات', 's': 'اضغط + لإضافة سند جديد', 'i': Icons.receipt_long_outlined, 'c': AppColors.primary},
      {'t': 'لا توجد مصروفات', 's': 'أضف سند صرف جديد', 'i': Icons.money_off_rounded, 'c': AppColors.error},
      {'t': 'لا توجد إيرادات', 's': 'أضف سند قبض جديد', 'i': Icons.account_balance_wallet_outlined, 'c': AppColors.success},
    ][tab];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  (data['c'] as Color).withOpacity(0.12),
                  (data['c'] as Color).withOpacity(0.03)
                ]),
                shape: BoxShape.circle,
              ),
              child: Icon(data['i'] as IconData,
                  size: 52, color: (data['c'] as Color).withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(data['t'] as String,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textMain)),
            const SizedBox(height: 6),
            Text(data['s'] as String,
                style: TextStyle(fontSize: 13, color: c.textSub)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  5) زر الإضافة
  // ═══════════════════════════════════════════════════════════════════
  Widget _fab(AppThemeColors c) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight]),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAddSheet(c),
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppColors.navy, size: 22),
                SizedBox(width: 6),
                Text('سند جديد',
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

  // ═══════════════════════════════════════════════════════════════════
  //  6) العمليات: إضافة / تعديل / حذف
  // ═══════════════════════════════════════════════════════════════════
  void _openAddSheet(AppThemeColors c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => _AddVoucherSheet(
        colors: c,
        isEditMode: false,
        onSave: (type, catId, amount, notes) async {
          final r = await ref
              .read(financialVouchersProvider.notifier)
              .addVoucher(categoryId: catId, type: type, amount: amount, notes: notes);
          if (r['success'] == true) {
            _successOverlay(c, type, isEdit: false);
          } else {
            _snack('خطأ: ${r['error']}', AppColors.error);
          }
        },
      ),
    );
  }

  void _openEditSheet(AppThemeColors c, Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => _AddVoucherSheet(
        colors: c,
        isEditMode: true,
        initialData: v,
        onSave: (type, catId, amount, notes) async {
          final r = await ref
              .read(financialVouchersProvider.notifier)
              .updateVoucher(voucherId: v['id'], categoryId: catId, amount: amount, notes: notes);
          if (r['success'] == true) {
            _successOverlay(c, type, isEdit: true);
          } else {
            _snack('خطأ: ${r['error']}', AppColors.error);
          }
        },
      ),
    );
  }

  void _confirmDelete(AppThemeColors c, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: AppColors.error),
          const SizedBox(width: 8),
          Text('تأكيد الحذف',
              style: TextStyle(color: c.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text(
            'هل أنت متأكد من حذف السند التابع لـ "$name"؟\nسيتم استرجاع تأثيره على الخزينة.',
            style: TextStyle(color: c.textSub, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: c.textSub)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final r = await ref
                  .read(financialVouchersProvider.notifier)
                  .deleteVoucher(id);
              if (r['success'] == true) {
                _snack('تم الحذف بنجاح ✅', AppColors.success);
              } else {
                _snack('خطأ: ${r['error']}', AppColors.error);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color clr) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: clr,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _successOverlay(AppThemeColors c, String type, {bool isEdit = false}) {
    final isPay = type == 'payment';
    final clr = isPay ? AppColors.error : AppColors.success;
    final lbl = isEdit ? 'تم التعديل' : (isPay ? 'تم تسجيل المصروف' : 'تم تسجيل الإيراد');

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'success',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, a1, __, child) => Transform.scale(
        scale: Curves.easeOutBack.transform(a1.value),
        child: Opacity(opacity: a1.value, child: child),
      ),
      pageBuilder: (ctx, _, __) {
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: clr.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: clr.withOpacity(0.15), blurRadius: 30, spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, __) => Transform.scale(
                    scale: v,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [clr, clr.withOpacity(0.7)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: clr.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('$lbl بنجاح! ✨',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textMain),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  7) طباعة PDF — سند واحد (شكل محاسبي رسمي كلاسيكي)
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _printSingleVoucher(AppThemeColors c, Map<String, dynamic> v) async {
    await InvoicePrinter.printFinancialVoucher(v);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  8) تصدير PDF — تقرير شامل (جدول محاسبي)
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _exportAllPdf(AppThemeColors c, List<Map<String, dynamic>> vouchers) async {
    if (vouchers.isEmpty) {
      _snack('لا توجد سندات للتصدير', AppColors.error);
      return;
    }

    final ttf = await PdfGoogleFonts.cairoRegular();
    final ttfBold = await PdfGoogleFonts.cairoBold();

    final totalExp = vouchers
        .where((v) => v['type'] == 'payment')
        .fold(0.0, (s, v) => s + (v['amount'] as num).toDouble());
    final totalInc = vouchers
        .where((v) => v['type'] == 'receipt')
        .fold(0.0, (s, v) => s + (v['amount'] as num).toDouble());
    final net = totalInc - totalExp;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('تقرير السندات المالية',
                    style: pw.TextStyle(font: ttfBold, fontSize: 18)),
                pw.Text(DateFormat('yyyy/MM/dd  hh:mm a', 'en').format(DateTime.now()),
                    style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 2, color: PdfColors.blueGrey800),
            pw.SizedBox(height: 10),
            // ملخص
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfSummaryBox(ttf, ttfBold, 'الإيرادات', totalInc, PdfColors.green),
                _pdfSummaryBox(ttf, ttfBold, 'المصروفات', totalExp, PdfColors.red),
                _pdfSummaryBox(ttf, ttfBold, 'الصافي', net, net >= 0 ? PdfColors.green : PdfColors.red),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerStyle: pw.TextStyle(font: ttfBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: pw.TextStyle(font: ttf, fontSize: 9),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.all(5),
            headers: ['#', 'رقم السند', 'النوع', 'البند', 'المبلغ', 'التاريخ', 'الوقت', 'ملاحظات'],
            data: vouchers.asMap().entries.map((e) {
              final i = e.key + 1;
              final v = e.value;
              final isPay = v['type'] == 'payment';
              final date = DateTime.parse(v['date'].toString());
              return [
                '$i',
                v['voucher_number'] ?? '',
                isPay ? 'صرف' : 'قبض',
                v['category_name'] ?? '',
                NumberFormat('#,##0.00', 'en').format((v['amount'] as num).toDouble()),
                DateFormat('yyyy/MM/dd', 'en').format(date),
                DateFormat('hh:mm a', 'en').format(date),
                v['notes'] ?? '',
              ];
            }).toList(),
          ),
        ],
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('عدد السندات: ${vouchers.length}', style: pw.TextStyle(font: ttf, fontSize: 9)),
            pw.Text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                style: pw.TextStyle(font: ttf, fontSize: 9)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  pw.Widget _pdfSummaryBox(pw.Font ttf, pw.Font ttfBold, String label, double val, PdfColor clr) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: clr),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(NumberFormat('#,##0.00', 'en').format(val),
              style: pw.TextStyle(font: ttfBold, fontSize: 12, color: clr)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  9) تصدير Excel
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _exportExcel(List<Map<String, dynamic>> vouchers) async {
    if (vouchers.isEmpty) {
      _snack('لا توجد سندات للتصدير', AppColors.error);
      return;
    }

    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['السندات المالية'];
      excel.delete('Sheet1');

      // الهيدر
      final headerStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#0A1628'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: xl.HorizontalAlign.Center,
        fontSize: 12,
      );

      final headers = ['#', 'رقم السند', 'النوع', 'البند', 'المبلغ', 'التاريخ', 'الوقت', 'ملاحظات'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // البيانات
      for (var i = 0; i < vouchers.length; i++) {
        final v = vouchers[i];
        final isPay = v['type'] == 'payment';
        final date = DateTime.parse(v['date'].toString());
        final amt = (v['amount'] as num).toDouble();

        final row = i + 1;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(v['voucher_number'] ?? '');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(isPay ? 'سند صرف' : 'سند قبض');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(v['category_name'] ?? '');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.DoubleCellValue(amt);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(DateFormat('yyyy/MM/dd', 'en').format(date));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(DateFormat('hh:mm a', 'en').format(date));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(v['notes'] ?? '');

        // تلوين صف المصروفات
        if (isPay) {
          for (var col = 0; col < headers.length; col++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle =
                xl.CellStyle(backgroundColorHex: xl.ExcelColor.fromHexString('#FFF0F0'));
          }
        }
      }

      // صف الإجماليات
      final totalRow = vouchers.length + 2;
      final totalExp = vouchers.where((v) => v['type'] == 'payment').fold(0.0, (s, v) => s + (v['amount'] as num).toDouble());
      final totalInc = vouchers.where((v) => v['type'] == 'receipt').fold(0.0, (s, v) => s + (v['amount'] as num).toDouble());

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow)).value = xl.TextCellValue('إجمالي المصروفات:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow)).value = xl.DoubleCellValue(totalExp);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow + 1)).value = xl.TextCellValue('إجمالي الإيرادات:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow + 1)).value = xl.DoubleCellValue(totalInc);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow + 2)).value = xl.TextCellValue('الصافي:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow + 2)).value = xl.DoubleCellValue(totalInc - totalExp);

      // حفظ ومشاركة
      final dir = await getTemporaryDirectory();
      final fileName = 'سندات_مالية_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      await Share.shareXFiles([XFile(filePath)], text: 'تقرير السندات المالية');

      _snack('تم تصدير Excel بنجاح ✅', AppColors.success);
    } catch (e) {
      debugPrint('Excel export error: $e');
      _snack('خطأ في التصدير: $e', AppColors.error);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
//  نافذة إضافة / تعديل السند (Bottom Sheet)
// ══════════════════════════════════════════════════════════════════════
class _AddVoucherSheet extends ConsumerStatefulWidget {
  final AppThemeColors colors;
  final bool isEditMode;
  final Map<String, dynamic>? initialData;
  final void Function(String type, int catId, double amount, String notes) onSave;

  const _AddVoucherSheet({
    required this.colors,
    required this.onSave,
    this.isEditMode = false,
    this.initialData,
  });

  @override
  ConsumerState<_AddVoucherSheet> createState() => _AddVoucherSheetState();
}

class _AddVoucherSheetState extends ConsumerState<_AddVoucherSheet> {
  String _type = 'payment';
  int? _catId;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.initialData != null) {
      _type = widget.initialData!['type'];
      _catId = widget.initialData!['category_id'];
      _amountCtrl.text = widget.initialData!['amount'].toString();
      _notesCtrl.text = widget.initialData!['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Color get _activeClr => _type == 'payment' ? AppColors.error : AppColors.success;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _catId == null) {
      if (_catId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('يرجى اختيار البند المالي', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
          margin: const EdgeInsets.all(16),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
      return;
    }
    setState(() => _saving = true);
    widget.onSave(_type, _catId!, double.parse(_amountCtrl.text.trim()), _notesCtrl.text.trim());
    Navigator.pop(context);
  }

  Future<void> _addCategory(String name) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dbType = _type == 'payment' ? 'expense' : 'income';
      await db.insert('financial_categories', {'name': name, 'type': dbType});
      await ref.read(financialVouchersProvider.notifier).loadAllData();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _deleteCategory(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('financial_categories', where: 'id = ?', whereArgs: [id]);
      if (_catId == id) setState(() => _catId = null);
      await ref.read(financialVouchersProvider.notifier).loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('لا يمكن حذف البند لأنه مستخدم في سندات', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _editCategory(int id, String newName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('financial_categories', {'name': newName}, where: 'id = ?', whereArgs: [id]);
      await ref.read(financialVouchersProvider.notifier).loadAllData();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final state = ref.watch(financialVouchersProvider);
    final cats = _type == 'payment' ? state.expenseCategories : state.incomeCategories;

    if (_catId != null && !cats.any((x) => x['id'] == _catId)) _catId = null;

    final selectedName = _catId != null
        ? cats.firstWhere((x) => x['id'] == _catId, orElse: () => {'name': ''})['name']
        : null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _activeClr.withOpacity(0.3), width: 1.5)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(widget.isEditMode ? Icons.edit_note_rounded : Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(widget.isEditMode ? 'تعديل السند' : 'تسجيل سند مالي',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textMain)),
                    ]),
                    const SizedBox(height: 24),

                    // نوع السند
                    Row(children: [
                      Expanded(child: _typeBtn('مصروف (صرف)', 'payment', AppColors.error, Icons.trending_down_rounded, c)),
                      const SizedBox(width: 10),
                      Expanded(child: _typeBtn('إيراد (قبض)', 'receipt', AppColors.success, Icons.trending_up_rounded, c)),
                    ]),
                    const SizedBox(height: 18),

                    // اختيار البند
                    InkWell(
                      onTap: () => _showCategoryPicker(c, cats),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: c.inputFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _catId == null ? c.cardBorder : _activeClr, width: _catId == null ? 1 : 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.category_rounded, color: AppColors.primary, size: 19),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _catId == null ? 'اختر بند الحساب *' : selectedName ?? '',
                              style: TextStyle(color: _catId == null ? c.textSub : c.textMain, fontWeight: _catId == null ? FontWeight.normal : FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // المبلغ
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _activeClr),
                      decoration: InputDecoration(
                        labelText: 'المبلغ *',
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.primary, size: 19),
                        suffixText: 'ريال',
                        suffixStyle: TextStyle(color: c.textSub, fontSize: 12),
                        filled: true, fillColor: c.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _activeClr, width: 1.5)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'قيمة غير صحيحة';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ملاحظات
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: TextStyle(color: c.textMain, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'البيان / الملاحظات (اختياري)',
                        prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.primary, size: 19),
                        filled: true, fillColor: c.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _activeClr, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // زر الحفظ
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded),
                        label: Text(widget.isEditMode ? 'تحديث السند' : 'حفظ السند',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _activeClr,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(String lbl, String val, Color clr, IconData ico, AppThemeColors c) {
    final sel = _type == val;
    return GestureDetector(
      onTap: () => setState(() { _type = val; _catId = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? clr.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: sel ? clr : c.cardBorder, width: sel ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ico, color: sel ? clr : c.textHint, size: 16),
          const SizedBox(width: 6),
          Text(lbl, style: TextStyle(color: sel ? clr : c.textSub, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
  }

  void _showCategoryPicker(AppThemeColors c, List<Map<String, dynamic>> cats) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('اختر بند الحساب', style: TextStyle(color: c.textMain, fontSize: 16, fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            onPressed: () => _showCatInput(c),
          ),
        ]),
        content: Consumer(
          builder: (context, ref, _) {
            final st = ref.watch(financialVouchersProvider);
            final list = _type == 'payment' ? st.expenseCategories : st.incomeCategories;
            return SizedBox(
              width: double.maxFinite,
              height: 320,
              child: list.isEmpty
                  ? Center(child: Text('لا توجد بنود، اضغط + للإضافة', style: TextStyle(color: c.textSub)))
                  : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                itemCount: list.length,
                separatorBuilder: (_, __) => Divider(color: c.cardBorder, height: 1),
                itemBuilder: (_, i) {
                  final cat = list[i];
                  final sel = _catId == cat['id'];
                  return ListTile(
                    tileColor: sel ? _activeClr.withOpacity(0.08) : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.label_rounded, color: sel ? _activeClr : c.textHint, size: 20),
                    title: Text(cat['name'], style: TextStyle(color: sel ? _activeClr : c.textMain, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 16), onPressed: () => _showCatInput(c, cat: cat)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                        onPressed: () {
                          showDialog(context: context, builder: (d) => AlertDialog(
                            backgroundColor: c.cardBg,
                            title: Text('حذف "${cat['name']}"؟', style: TextStyle(color: c.textMain, fontSize: 15)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d), child: Text('إلغاء', style: TextStyle(color: c.textSub))),
                              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () { Navigator.pop(d); _deleteCategory(cat['id']); },
                                  child: const Text('حذف', style: TextStyle(color: Colors.white))),
                            ],
                          ));
                        },
                      ),
                    ]),
                    onTap: () { setState(() => _catId = cat['id']); Navigator.pop(ctx); },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCatInput(AppThemeColors c, {Map<String, dynamic>? cat}) {
    final ctrl = TextEditingController(text: cat != null ? cat['name'] : '');
    final fk = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(cat != null ? 'تعديل البند' : 'بند جديد', style: TextStyle(color: c.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: fk,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(color: c.textMain),
            decoration: InputDecoration(
              labelText: 'اسم البند',
              labelStyle: TextStyle(color: c.textSub),
              filled: true, fillColor: c.inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _activeClr, width: 1.5)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(color: c.textSub))),
          ElevatedButton(
            onPressed: () {
              if (fk.currentState!.validate()) {
                Navigator.pop(ctx);
                if (cat != null) { _editCategory(cat['id'], ctrl.text.trim()); }
                else { _addCategory(ctrl.text.trim()); }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _activeClr, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}