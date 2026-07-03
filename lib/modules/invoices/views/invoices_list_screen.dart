// lib/modules/invoices/views/invoices_list_screen.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/invoice_printer.dart';
import '../../../core/services/whatsapp_service.dart';
import '../providers/invoices_list_provider.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  final String type;
  const InvoicesListScreen({super.key, required this.type});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  int _expandedId = -1;
  Timer? _undoTimer;
  Map<String, dynamic>? _deletedInvoice;

  final _scrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool get _dark => ref.watch(themeModeProvider) == ThemeMode.dark;
  bool get _isSales => widget.type == 'sales';

  static const Color _salesAccent = Color(0xFF10B981);
  static const Color _purchaseAccent = Color(0xFFF59E0B);
  Color get _accentColor => _isSales ? _salesAccent : _purchaseAccent;

  Color get _cardBg => _dark ? AppColors.navyCard : Colors.white;
  Color get _cardBorder => _dark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
  Color get _textMain => _dark ? AppColors.textPrimary : AppColors.navy;
  Color get _textSub => _dark ? AppColors.textSecondary : const Color(0xFF475569);
  Color get _textHint => _dark ? AppColors.textHint : const Color(0xFF94A3B8);
  Color get _inputFill => _dark ? AppColors.navyLight : Colors.white;
  Color get _scaffoldBg => _dark ? AppColors.navy : const Color(0xFFF1F5F9);

  String _formatNumber(num value) => NumberFormat('#,##0.00', 'en_US').format(value);

  String _formatCompact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
    _searchController.addListener(() {
      ref.read(invoicesListProvider(widget.type).notifier).setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    if (_undoTimer != null && _undoTimer!.isActive && _deletedInvoice != null) {
      _undoTimer!.cancel();
      ref.read(invoicesListProvider(widget.type).notifier).deleteInvoice(_deletedInvoice!['id']);
    }
    _undoTimer?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(invoicesListProvider(widget.type).notifier).loadMoreInvoices();
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: bg, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickDateRange(InvoicesListState state) async {
    DateTime tempStart = state.dateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime tempEnd = state.dateRange?.end ?? DateTime.now();

    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: _accentColor.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: _textHint.withOpacity(0.5), borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text('تحديد نطاق التاريخ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تاريخ البدء:', style: TextStyle(color: _textSub, fontWeight: FontWeight.bold)),
                    Text(DateFormat('yyyy/MM/dd').format(tempStart), style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                  child: _NumericDatePicker(
                    initialDate: tempStart, textColor: _textMain, accentColor: _accentColor,
                    onDateTimeChanged: (newDate) {
                      setSheetState(() {
                        tempStart = newDate;
                        if (tempEnd.isBefore(tempStart)) tempEnd = tempStart;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تاريخ الانتهاء:', style: TextStyle(color: _textSub, fontWeight: FontWeight.bold)),
                    Text(DateFormat('yyyy/MM/dd').format(tempEnd), style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                  child: _NumericDatePicker(
                    initialDate: tempEnd, textColor: _textMain, accentColor: _accentColor,
                    onDateTimeChanged: (newDate) => setSheetState(() => tempEnd = newDate),
                  ),
                ),
                const SizedBox(height: 30),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(foregroundColor: _textSub, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: _cardBorder)),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (tempEnd.isBefore(tempStart)) {
                          _snack('تاريخ الانتهاء لا يمكن أن يكون قبل تاريخ البدء', AppColors.error);
                          return;
                        }
                        Navigator.pop(ctx, DateTimeRange(start: tempStart, end: tempEnd));
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('تطبيق الفلتر', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ]),
              ],
            ),
          );
        });
      },
    );

    if (result != null) {
      ref.read(invoicesListProvider(widget.type).notifier).setDateRange(result);
    }
  }

  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: _cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_forever_rounded, size: 36, color: AppColors.error)),
            const SizedBox(height: 14),
            Text('تأكيد الحذف النهائي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textMain)),
            const SizedBox(height: 6),
            Text('هل أنت متأكد من حذف ${invoice['invoice_number']}؟', style: TextStyle(fontSize: 13, color: _textSub)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), style: OutlinedButton.styleFrom(foregroundColor: _textSub, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: _cardBorder)), child: Text('إلغاء', style: TextStyle(color: _textSub)))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    _deletedInvoice = Map<String, dynamic>.from(invoice);
    ref.read(invoicesListProvider(widget.type).notifier).removeInvoiceLocally(invoice['id']);

    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 5), () async {
      if (_deletedInvoice != null) {
        try {
          await ref.read(invoicesListProvider(widget.type).notifier).deleteInvoice(_deletedInvoice!['id']);
        } catch (e) {
          debugPrint('خطأ أثناء الحذف: $e');
        }
        _deletedInvoice = null;
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حذف الفاتورة "${invoice['invoice_number']}"'),
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.navy,
        action: SnackBarAction(
          label: 'تراجع',
          textColor: AppColors.primary,
          onPressed: () {
            _undoTimer?.cancel();
            if (_deletedInvoice != null) {
              _deletedInvoice = null;
              ref.read(invoicesListProvider(widget.type).notifier).loadInitialInvoices();
            }
          },
        ),
      ),
    );
  }

  Future<void> _printInvoice(Map<String, dynamic> invoice) async {
    final printType = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('خيارات الطباعة', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.receipt_long_rounded, color: _accentColor)),
              title: Text('فاتورة تفصيلية (منتجات)', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
              subtitle: Text('ثابتة ومجمدة: طباعة المنتجات، الكميات، والأسعار الأصلية', style: TextStyle(color: _textHint, fontSize: 11, fontFamily: 'Cairo')),
              onTap: () => Navigator.pop(ctx, 1),
            ),
            Divider(color: _cardBorder),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary)),
              title: Text('كشف مالي (مدين ودائن)', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
              subtitle: Text('متحرك وحي: يتضمن الدفعات الجديدة، السندات، والرصيد المتبقي', style: TextStyle(color: _textHint, fontSize: 11, fontFamily: 'Cairo')),
              onTap: () => Navigator.pop(ctx, 2),
            ),
          ],
        ),
      ),
    );

    if (printType == null) return;

    try {
      final invoiceId = invoice['id'] as int;
      final notifier = ref.read(invoicesListProvider(widget.type).notifier);
      await notifier.loadInvoiceDetails(invoiceId, invoice);
      final state = ref.read(invoicesListProvider(widget.type));

      final items = state.invoiceItems[invoiceId] ?? [];
      final payments = state.invoicePayments[invoiceId] ?? [];

      final printItems = items.map((item) => {
        'product_name': item['product_name'] ?? '',
        'quantity': item['quantity'] ?? 0,
        'unit_price': _isSales ? (item['unit_price'] ?? 0) : (item['unit_cost'] ?? 0),
        'total': (item['quantity'] ?? 0) * (_isSales ? (item['unit_price'] ?? 0) : (item['unit_cost'] ?? 0)),
        'is_bonus': item['is_bonus'] ?? 0,
      }).toList();

      await InvoicePrinter.printSaleInvoice(
        invoice: invoice,
        items: printItems,
        payments: payments,
        printFinancialDetails: printType == 2,
        isSaleInvoice: _isSales,
        previousBalance: (invoice['previous_balance'] as num?)?.toDouble() ?? 0.0,
        // 🚀 نمرر الدفعة الأولى المأخوذة من قاعدة البيانات
        initialPaidAmount: (invoice['initial_paid_amount'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      _snack('خطأ في معالجة الطباعة: $e', AppColors.error);
    }
  }



  Future<void> _shareInvoice(Map<String, dynamic> invoice) async {
    try {
      final invoiceId = invoice['id'] as int;
      final notifier = ref.read(invoicesListProvider(widget.type).notifier);
      await notifier.loadInvoiceDetails(invoiceId, invoice);
      final state = ref.read(invoicesListProvider(widget.type));
      final items = state.invoiceItems[invoiceId] ?? [];

      final phone = invoice['customer_phone'] ?? invoice['supplier_phone'];
      if (phone != null && phone.toString().isNotEmpty) {
        final shareItems = items.map((item) => {
          'productName': item['product_name'] ?? '',
          'quantity': item['quantity'] ?? 0,
          'unitPrice': _isSales ? (item['unit_price'] ?? 0) : (item['unit_cost'] ?? 0),
        }).toList();

        double calcSubtotal = 0;
        for (var item in shareItems) {
          calcSubtotal += (item['quantity'] as num).toDouble() * (item['unitPrice'] as num).toDouble();
        }

        await WhatsAppService.sendInvoiceToWhatsApp(
          phoneNumber: phone.toString(),
          customerName: invoice['customer_name'] ?? invoice['supplier_name'] ?? 'عميل',
          invoiceNumber: invoice['invoice_number'] ?? '',
          date: invoice['date'] ?? DateTime.now().toIso8601String(),
          totalAmount: (invoice['total_amount'] ?? 0).toDouble(),
          paymentStatus: invoice['payment_status'] ?? 'كامل',
          paidAmount: (invoice['paid_amount'] ?? 0).toDouble(),
          items: shareItems,
          shopName: 'المخازن الذكية',
          subtotal: calcSubtotal,
          discountAmount: (invoice['discount_amount'] ?? 0).toDouble(),
          taxAmount: (invoice['tax_amount'] ?? 0).toDouble(),
          paymentType: invoice['payment_type'] ?? 'كاش',
          notes: invoice['notes']?.toString() ?? '',
        );
      } else {
        _snack('لا يوجد رقم هاتف مسجل لإرسال الفاتورة له', AppColors.warning);
      }
    } catch (e) {
      _snack('خطأ أثناء المشاركة: $e', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoicesListProvider(widget.type));

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: _buildAppBar(state),
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_accentColor)))
          : state.invoices.isEmpty
          ? _buildEmptyState()
          : _buildContent(state),
      bottomNavigationBar: state.isMultiSelectMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: _cardBg, border: Border(top: BorderSide(color: _cardBorder))),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => ref.read(invoicesListProvider(widget.type).notifier).selectAllInvoices(),
                    child: Text('تحديد الكل (${state.filteredInvoices.length})', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text('تصدير PDF (${state.selectedInvoiceIds.isNotEmpty ? state.selectedInvoiceIds.length : state.filteredInvoices.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final selectedIds = state.selectedInvoiceIds;
                      final toPrint = selectedIds.isNotEmpty
                          ? state.filteredInvoices.where((i) => selectedIds.contains(i['id'] as int)).toList()
                          : state.filteredInvoices;
                      if (toPrint.isEmpty) {
                        _snack('لا توجد فواتير للتصدير', AppColors.warning);
                        return;
                      }
                      await InvoicePrinter.printInvoicesReport(
                        invoices: toPrint,
                        reportTitle: _isSales ? 'تقرير مراجعة فواتير البيع' : 'تقرير مراجعة فواتير الشراء',
                        isSales: _isSales,
                        totalAmount: state.totalAmount,
                        paidAmount: state.paidAmount,
                        unpaidAmount: state.unpaidAmount,
                        personFilterName: state.selectedPersonName,
                        dateRangeStr: state.dateRange != null ? '${DateFormat('yyyy/MM/dd').format(state.dateRange!.start)} — ${DateFormat('yyyy/MM/dd').format(state.dateRange!.end)}' : null,
                      );
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(InvoicesListState state) {
    return AppBar(
      backgroundColor: _dark ? AppColors.navyMedium : AppColors.navy,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(_isSales ? 'فواتير البيع' : 'فواتير الشراء', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      actions: [
        IconButton(
          icon: Icon(state.isMultiSelectMode ? Icons.checklist_rtl_rounded : Icons.checklist_rounded, color: state.isMultiSelectMode ? _accentColor : AppColors.primary),
          tooltip: 'تحديد متعدد والتصدير',
          onPressed: () => ref.read(invoicesListProvider(widget.type).notifier).toggleMultiSelectMode(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded, color: AppColors.primary, size: 22),
          color: _dark ? AppColors.navyMedium : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) => ref.read(invoicesListProvider(widget.type).notifier).setSortMode(v),
          itemBuilder: (_) => [
            _sortMenuItem('الأحدث', Icons.arrow_downward_rounded, state.sortMode),
            _sortMenuItem('الأقدم', Icons.arrow_upward_rounded, state.sortMode),
            _sortMenuItem('الأعلى مبلغاً', Icons.trending_up_rounded, state.sortMode),
            _sortMenuItem('الأقل مبلغاً', Icons.trending_down_rounded, state.sortMode),
          ],
        ),
        IconButton(
          icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primary),
          onPressed: () {
            setState(() => _showSearch = !_showSearch);
            if (!_showSearch) {
              _searchController.clear();
            }
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, _accentColor.withOpacity(0.6), AppColors.navy]))),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String label, IconData icon, String currentSort) {
    final isActive = currentSort == label;
    return PopupMenuItem(
      value: label,
      child: Row(children: [
        Icon(icon, size: 18, color: isActive ? _accentColor : _textSub),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: isActive ? _accentColor : _textMain, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        if (isActive) ...[const Spacer(), Icon(Icons.check_rounded, size: 16, color: _accentColor)],
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _accentColor.withOpacity(0.08), shape: BoxShape.circle), child: Icon(_isSales ? Icons.sell_rounded : Icons.shopping_cart_rounded, size: 56, color: _accentColor.withOpacity(0.5))),
          const SizedBox(height: 20),
          Text('لا توجد فواتير بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
          const SizedBox(height: 6),
          Text(_isSales ? 'أنشئ فاتورة بيع جديدة للبدء' : 'سجّل فاتورة شراء جديدة للبدء', style: TextStyle(fontSize: 13, color: _textHint)),
          const SizedBox(height: 20),
          TextButton.icon(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: _accentColor, size: 18), label: Text('العودة', style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildContent(InvoicesListState state) {
    return Column(children: [
      if (_showSearch)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: _dark ? AppColors.navyMedium.withOpacity(0.5) : _accentColor.withOpacity(0.04),
          child: TextField(
            controller: _searchController, autofocus: true, style: TextStyle(color: _textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: _isSales ? 'بحث برقم الفاتورة أو اسم العميل...' : 'بحث برقم الفاتورة أو اسم المورد...',
              hintStyle: TextStyle(color: _textHint, fontSize: 13), prefixIcon: Icon(Icons.search_rounded, color: _textHint, size: 20),
              suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear_rounded, color: _textHint, size: 18), onPressed: () => _searchController.clear()) : null,
              filled: true, fillColor: _inputFill, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accentColor, width: 1.5)),
            ),
          ),
        ),

      _buildStatsBar(state),
      _buildFilterChips(state),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(Icons.receipt_long_rounded, size: 14, color: _textHint),
          const SizedBox(width: 6),
          Text('${state.filteredInvoices.length} فاتورة', style: TextStyle(fontSize: 12, color: _textSub, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('ترتيب: ${state.sortMode}', style: TextStyle(fontSize: 11, color: _textHint)),
        ]),
      ),

      Expanded(
        child: RefreshIndicator(
          onRefresh: () => ref.read(invoicesListProvider(widget.type).notifier).loadInitialInvoices(),
          color: _accentColor,
          backgroundColor: _cardBg,
          child: state.filteredInvoices.isEmpty
              ? ListView(children: [
            Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [Icon(Icons.filter_list_off_rounded, size: 40, color: _textHint), const SizedBox(height: 10), Text('لا توجد نتائج مطابقة للفلاتر', style: TextStyle(color: _textSub, fontWeight: FontWeight.w500))]))),
          ])
              : FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: state.filteredInvoices.length + 1,
              itemBuilder: (context, index) {
                if (index == state.filteredInvoices.length) {
                  return state.isLoadingMore
                      ? Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor)))
                      : const SizedBox.shrink();
                }
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + (index.clamp(0, 10) * 50)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(offset: Offset(0, 16 * (1 - value)), child: Opacity(opacity: value, child: child)),
                  child: _buildInvoiceCard(state.filteredInvoices[index], state),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildStatsBar(InvoicesListState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.3)), boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        _statItem('الإجمالي', _formatCompact(state.totalAmount), AppColors.primary, Icons.monetization_on_rounded), _statDivider(),
        _statItem('المدفوع', _formatCompact(state.paidAmount), AppColors.success, Icons.check_circle_rounded), _statDivider(),
        _statItem('الآجل', _formatCompact(state.unpaidAmount), AppColors.error, Icons.schedule_rounded), _statDivider(),
        _statItem('العدد', '${state.invoices.length}', _accentColor, Icons.receipt_rounded),
      ]),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Expanded(child: Column(children: [Icon(icon, size: 16, color: color), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54))]));
  }

  Widget _statDivider() => Container(width: 1, height: 36, color: AppColors.primary.withOpacity(0.2));

  Widget _buildFilterChips(InvoicesListState state) {
    final filters = ['الكل', 'مدفوع', 'جزئي', 'آجل'];
    final filterColors = {'الكل': AppColors.primary, 'مدفوع': AppColors.success, 'جزئي': _purchaseAccent, 'آجل': AppColors.error};
    final filterIcons = {'الكل': Icons.list_rounded, 'مدفوع': Icons.check_circle_rounded, 'جزئي': Icons.timelapse_rounded, 'آجل': Icons.warning_amber_rounded};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(children: [
        Row(children: [
          ...filters.map((f) {
            final isActive = state.activeFilter == f;
            final color = filterColors[f] ?? AppColors.primary;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: f != filters.last ? 6 : 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => ref.read(invoicesListProvider(widget.type).notifier).setFilter(f),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: isActive ? color.withOpacity(0.15) : _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? color.withOpacity(0.5) : _cardBorder, width: isActive ? 1.5 : 1)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
                        children: [Icon(filterIcons[f], size: 13, color: isActive ? color : _textHint), const SizedBox(width: 4), Flexible(child: Text(f, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? color : _textSub), overflow: TextOverflow.ellipsis))],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () => _pickDateRange(state),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: state.dateRange != null ? _accentColor.withOpacity(0.08) : _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: state.dateRange != null ? _accentColor.withOpacity(0.4) : _cardBorder)),
                child: Row(children: [
                  Icon(Icons.date_range_rounded, size: 16, color: state.dateRange != null ? _accentColor : _textHint),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.dateRange != null ? '${DateFormat('yyyy/MM/dd').format(state.dateRange!.start)} — ${DateFormat('yyyy/MM/dd').format(state.dateRange!.end)}' : 'فلترة بالتاريخ', style: TextStyle(fontSize: 12, color: state.dateRange != null ? _accentColor : _textHint, fontWeight: state.dateRange != null ? FontWeight.w600 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                  if (state.dateRange != null)
                    GestureDetector(onTap: () => ref.read(invoicesListProvider(widget.type).notifier).setDateRange(null), child: Icon(Icons.close_rounded, size: 16, color: _accentColor)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => _pickPersonFilter(state),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: state.selectedPersonId != null ? _accentColor.withOpacity(0.08) : _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: state.selectedPersonId != null ? _accentColor.withOpacity(0.4) : _cardBorder)),
                child: Row(children: [
                  Icon(Icons.person_search_rounded, size: 16, color: state.selectedPersonId != null ? _accentColor : _textHint),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.selectedPersonName ?? (_isSales ? 'تحديد العميل' : 'تحديد المورد'), style: TextStyle(fontSize: 12, color: state.selectedPersonId != null ? _accentColor : _textHint, fontWeight: state.selectedPersonId != null ? FontWeight.w600 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                  if (state.selectedPersonId != null)
                    GestureDetector(onTap: () => ref.read(invoicesListProvider(widget.type).notifier).setPersonFilter(null, null), child: Icon(Icons.close_rounded, size: 16, color: _accentColor)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _pickPersonFilter(InvoicesListState state) async {
    final persons = state.personsList;
    if (persons.isEmpty) {
      _snack(_isSales ? 'لا يوجد عملاء مسجلين' : 'لا يوجد موردين مسجلين', AppColors.warning);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (context, setSheetState) {
          final filtered = persons.where((p) {
            if (query.isEmpty) return true;
            return (p['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
            decoration: BoxDecoration(color: _cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: _accentColor.withOpacity(0.3))),
            child: Column(children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: _textHint.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text(_isSales ? 'تحديد العميل لعرض فواتيره' : 'تحديد المورد لعرض فواتيره', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
              const SizedBox(height: 12),
              TextField(
                style: TextStyle(color: _textMain),
                onChanged: (v) => setSheetState(() => query = v),
                decoration: InputDecoration(hintText: 'بحث بالاسم...', hintStyle: TextStyle(color: _textHint), prefixIcon: Icon(Icons.search, color: _textHint), filled: true, fillColor: _inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.clear_all_rounded, color: AppColors.error),
                title: Text('عرض فواتير الكل', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                onTap: () {
                  ref.read(invoicesListProvider(widget.type).notifier).setPersonFilter(null, null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return ListTile(
                      leading: Icon(Icons.person_rounded, color: _accentColor),
                      title: Text(p['name'] ?? '', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold)),
                      onTap: () {
                        ref.read(invoicesListProvider(widget.type).notifier).setPersonFilter(p['id'] as int, p['name'] as String);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice, InvoicesListState state) {
    final invoiceId = invoice['id'] as int;
    final isExpanded = _expandedId == invoiceId;

    final personName = _isSales ? (invoice['customer_name'] ?? '') : (invoice['supplier_name'] ?? '');
    final paymentStatus = invoice['payment_status']?.toString() ?? 'كامل';
    final paymentType = invoice['payment_type']?.toString() ?? 'كاش';
    final totalAmount = (invoice['total_amount'] ?? 0).toDouble();
    final paidAmt = (invoice['paid_amount'] ?? 0).toDouble();

    double cashAmount = invoice['cash_amount'] != null ? (invoice['cash_amount'] as num).toDouble() : (paymentType == 'كاش' ? paidAmt : 0.0);
    double transferAmount = invoice['transfer_amount'] != null ? (invoice['transfer_amount'] as num).toDouble() : (paymentType == 'حوالة' ? paidAmt : 0.0);

    Color statusColor; IconData statusIcon; String statusLabel;
    switch (paymentStatus) {
      case 'كامل': statusColor = AppColors.success; statusIcon = Icons.check_circle_rounded; statusLabel = 'مدفوع'; break;
      case 'جزئي': statusColor = _purchaseAccent; statusIcon = Icons.timelapse_rounded; statusLabel = 'جزئي'; break;
      default: statusColor = AppColors.error; statusIcon = Icons.schedule_rounded; statusLabel = 'آجل';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? _accentColor.withOpacity(0.5) : _cardBorder, width: isExpanded ? 1.5 : 1),
        boxShadow: isExpanded ? [BoxShadow(color: _accentColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(children: [
        InkWell(
          onTap: () {
            if (state.isMultiSelectMode) {
              ref.read(invoicesListProvider(widget.type).notifier).toggleInvoiceSelection(invoiceId);
            } else {
              setState(() => _expandedId = isExpanded ? -1 : invoiceId);
              if (!isExpanded) ref.read(invoicesListProvider(widget.type).notifier).loadInvoiceDetails(invoiceId, invoice);
            }
          },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (state.isMultiSelectMode) ...[
                      Checkbox(
                        value: state.selectedInvoiceIds.contains(invoiceId),
                        activeColor: _accentColor,
                        onChanged: (v) => ref.read(invoicesListProvider(widget.type).notifier).toggleInvoiceSelection(invoiceId),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(child: Text((invoice['invoice_number'] ?? '').toString().replaceAll('-', '\u2011'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _accentColor, letterSpacing: 0.3), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, size: 12, color: statusColor), const SizedBox(width: 4), Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor))])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)), child: Icon(_isSales ? Icons.person_rounded : Icons.business_rounded, color: _textSub, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(personName.isNotEmpty ? personName : 'عميل عام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textMain), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Row(children: [Icon(Icons.calendar_today_rounded, size: 12, color: _textHint), const SizedBox(width: 4), Text(invoice['date']?.toString().substring(0, 10) ?? '', style: TextStyle(fontSize: 11, color: _textSub))])])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('الإجمالي', style: TextStyle(fontSize: 10, color: _textHint)), Text('${_formatNumber(totalAmount)} ﷼', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15))]),
                  ],
                ),
                if (paidAmt > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withOpacity(0.15))),
                    child: Row(children: [Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.success), const SizedBox(width: 6), const Spacer(), if (cashAmount > 0) ...[Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('💵 نقداً: ${_formatNumber(cashAmount)}', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)))], if (cashAmount > 0 && transferAmount > 0) const SizedBox(width: 8), if (transferAmount > 0) ...[Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('🏦 حوالة: ${_formatNumber(transferAmount)}', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)))]]),
                  ),
                ],
                Align(alignment: Alignment.center, child: Padding(padding: const EdgeInsets.only(top: 8.0), child: AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.keyboard_arrow_down_rounded, color: _textHint, size: 24)))),
              ],
            ),
          ),
        ),
        AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, child: isExpanded ? _buildExpandedContent(invoice, invoiceId, state) : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> invoice, int invoiceId, InvoicesListState state) {
    final items = state.invoiceItems[invoiceId] ?? [];
    final hasLoadedPayments = state.invoicePayments.containsKey(invoiceId);
    final payments = state.invoicePayments[invoiceId] ?? [];

    double calculatedSubtotal = 0;
    for (var item in items) {
      double price = ((_isSales ? item['unit_price'] : item['unit_cost']) ?? 0).toDouble();
      int qty = (item['quantity'] ?? 0).toInt();
      calculatedSubtotal += (price * qty);
    }

    double subtotalVal = (invoice['subtotal'] ?? 0).toDouble();
    if (subtotalVal == 0) subtotalVal = calculatedSubtotal;
    double discountVal = (invoice['discount_amount'] ?? invoice['discount'] ?? 0).toDouble();
    double taxVal = (invoice['tax_amount'] ?? invoice['tax'] ?? 0).toDouble();
    double finalTotal = (invoice['total_amount'] ?? 0).toDouble();
    double paidAmount = (invoice['paid_amount'] ?? 0).toDouble();

    // ✅ التصحيح هنا: استخدم finalTotal بدلاً من totalAmount
    double remainingAmount = finalTotal - paidAmount;
    double cashAmount = invoice['cash_amount'] != null ? (invoice['cash_amount'] as num).toDouble() : (invoice['payment_type'] == 'كاش' ? paidAmount : 0.0);
    double transferAmount = invoice['transfer_amount'] != null ? (invoice['transfer_amount'] as num).toDouble() : (invoice['payment_type'] == 'حوالة' ? paidAmount : 0.0);

    String rawNotes = invoice['notes']?.toString() ?? '';
    List<String> noteParts = rawNotes.split(RegExp(r'[|\n]'));
    List<String> validNotes = [];
    for (var part in noteParts) {
      String cleanPart = part.trim();
      if (cleanPart.isNotEmpty && !cleanPart.contains('خصم') && !cleanPart.contains('الضريبة') && !cleanPart.contains('المجموع')) {
        cleanPart = cleanPart.replaceAll(RegExp(r'^[,]+|[,]+$'), '').trim();
        if (cleanPart.isNotEmpty && !RegExp(r'^[\d\s\.,]+$').hasMatch(cleanPart)) validNotes.add(cleanPart);
      }
    }
    String displayNotes = validNotes.join(' | ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: _cardBorder), const SizedBox(height: 12),
          // 1. معلومات أساسية وبيانات الدفع
          _CollapsibleSection(
            title: 'معلومات أساسية وبيانات الدفع',
            icon: Icons.info_outline_rounded,
            iconColor: _accentColor,
            borderColor: _cardBorder,
            headerBgColor: _inputFill,
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSales && invoice['customer_name'] != null) _buildDetailCard(icon: Icons.person_rounded, title: 'بيانات العميل', value: invoice['customer_name'].toString(), phone: invoice['customer_phone']?.toString()),
                if (!_isSales && invoice['supplier_name'] != null) _buildDetailCard(icon: Icons.business_rounded, title: 'بيانات المورد', value: invoice['supplier_name'].toString(), phone: invoice['supplier_phone']?.toString()),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                  child: Column(children: [
                    _buildDetailRow('طريقة الدفع الرئيسية', invoice['payment_type']?.toString() ?? 'كاش', Icons.payment_rounded, valueColor: _accentColor),
                    _buildDetailRow('حالة الفاتورة المحاسبية', invoice['payment_status']?.toString() ?? 'كامل', Icons.info_outline_rounded, valueColor: invoice['payment_status'] == 'كامل' ? AppColors.success : (invoice['payment_status'] == 'جزئي' ? _purchaseAccent : AppColors.error)),
                    _buildDetailRow('إجمالي المبلغ المسدد', '${_formatNumber(paidAmount)} ﷼', Icons.check_circle_outline_rounded, valueColor: AppColors.success),
                    if (cashAmount > 0) _buildDetailRow('المسدد نقداً (كاش)', '${_formatNumber(cashAmount)} ﷼', Icons.money_rounded, valueColor: Colors.green),
                    if (transferAmount > 0) _buildDetailRow('المسدد عبر (حوالة)', '${_formatNumber(transferAmount)} ﷼', Icons.account_balance_rounded, valueColor: Colors.blue),
                    if (remainingAmount > 0) _buildDetailRow('المبلغ المتبقي (آجل)', '${_formatNumber(remainingAmount)} ﷼', Icons.warning_amber_rounded, valueColor: AppColors.error),
                  ]),
                ),
              ],
            ),
          ),

          // 2. الأصناف والمجموع
          _CollapsibleSection(
            title: 'الأصناف والمنتجات (${items.length})',
            icon: Icons.inventory_2_outlined,
            iconColor: _accentColor,
            borderColor: _cardBorder,
            headerBgColor: _inputFill,
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_accentColor))))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: 600, decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.vertical(top: Radius.circular(11))),
                            child: Row(children: [Expanded(flex: 3, child: Text('الصنف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))), Expanded(flex: 1, child: Text('السعر', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))), Expanded(flex: 1, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))), Expanded(flex: 1, child: Text('بونص', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))), Expanded(flex: 2, child: Text('الإجمالي', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)))]),
                          ),
                          ...items.map((item) {
                            final price = ((_isSales ? item['unit_price'] : item['unit_cost']) ?? 0).toDouble();
                            final qty = (item['quantity'] ?? 0).toInt();
                            final isBonus = (item['is_bonus'] == 1 || item['is_bonus'] == '1');
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _cardBorder.withOpacity(0.3)))),
                              child: Row(children: [Expanded(flex: 3, child: Text(item['product_name']?.toString() ?? '', style: TextStyle(fontSize: 12, color: _textMain), overflow: TextOverflow.ellipsis)), Expanded(flex: 1, child: Text(_formatNumber(price), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _textSub))), Expanded(flex: 1, child: Text('$qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _textSub))), Expanded(flex: 1, child: Center(child: isBonus ? const Icon(Icons.card_giftcard_rounded, color: Colors.green, size: 16) : const Text('-'))), Expanded(flex: 2, child: Text(_formatNumber(price * qty), textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMain)))]),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                  child: Column(children: [
                    _buildDetailRow('المجموع الفرعي', '${_formatNumber(subtotalVal)} ﷼', Icons.receipt_long_outlined, valueColor: _textSub),
                    _buildDetailRow('الخصم', discountVal > 0 ? '-${_formatNumber(discountVal)} ﷼' : '0.00 ﷼', Icons.money_off_rounded, valueColor: discountVal > 0 ? AppColors.error : _textSub),
                    _buildDetailRow('الضريبة المضافة', taxVal > 0 ? '+${_formatNumber(taxVal)} ﷼' : '0.00 ﷼', Icons.account_balance_outlined, valueColor: taxVal > 0 ? _purchaseAccent : _textSub),
                    Divider(height: 16, color: AppColors.primary.withOpacity(0.3)),
                    _buildDetailRow('الإجمالي النهائي', '${_formatNumber(finalTotal)} ﷼', Icons.monetization_on_outlined, valueColor: AppColors.primary, isBold: true),
                  ]),
                ),
              ],
            ),
          ),

          // 3. سجل السندات
          _CollapsibleSection(
            title: 'سجل السندات وعمليات السداد (${payments.length})',
            icon: Icons.history_edu_rounded,
            iconColor: _accentColor,
            borderColor: _cardBorder,
            headerBgColor: _inputFill,
            initiallyExpanded: payments.isNotEmpty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasLoadedPayments) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.success))), const SizedBox(width: 8), Expanded(child: Text('جاري تحميل تفاصيل السندات التاريخية...', style: TextStyle(fontSize: 11, color: _textHint)))])),
                if (hasLoadedPayments && payments.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('✅ تم السداد المباشر (لا توجد سندات دفع منفصلة).', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold))),
                if (hasLoadedPayments && payments.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: 650,
                      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.vertical(top: Radius.circular(11))),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('رقم السند', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
                                Expanded(flex: 2, child: Text('التاريخ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
                                Expanded(flex: 3, child: Text('البيان', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
                                Expanded(flex: 2, child: Text('المبلغ المدفوع', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
                                Expanded(flex: 2, child: Text('المبلغ المتبقي', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary))),
                              ],
                            ),
                          ),
                          ...payments.map((p) {
                            final isDebit = (p['debit_amount'] as num?) != null && (p['debit_amount'] as num) > 0;
                            final amount = (isDebit ? p['debit_amount'] : p['credit_amount']) ?? p['amount'] ?? 0;
                            final remBalance = (p['remaining_balance'] as num?)?.toDouble() ?? 0.0;
                            final dateStr = p['date'] != null ? p['date'].toString().substring(0, 10) : '';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _cardBorder.withValues(alpha: 0.3)))),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(p['reference_number']?.toString() ?? p['voucher_number']?.toString() ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textMain))),
                                  Expanded(flex: 2, child: Text(dateStr, style: TextStyle(fontSize: 12, color: _textSub))),
                                  Expanded(flex: 3, child: Text(p['notes']?.toString() ?? '', style: TextStyle(fontSize: 12, color: _textSub))),
                                  Expanded(flex: 2, child: Text('${_formatNumber(amount)} ﷼', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success))),
                                  Expanded(flex: 2, child: Text('${_formatNumber(remBalance)} ﷼', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: remBalance > 0 ? AppColors.error : AppColors.success))),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. ملاحظات الفاتورة
          _CollapsibleSection(
            title: 'ملاحظات الفاتورة',
            icon: Icons.notes_rounded,
            iconColor: _accentColor,
            borderColor: _cardBorder,
            headerBgColor: _inputFill,
            initiallyExpanded: displayNotes.isNotEmpty,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
              child: Text(displayNotes.isNotEmpty ? displayNotes : 'لا توجد ملاحظات مسجلة على هذه الفاتورة.', style: TextStyle(fontSize: 12, color: displayNotes.isNotEmpty ? _textMain : _textHint)),
            ),
          ),

          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _buildActionButton(Icons.edit_outlined, 'تعديل', AppColors.primary, () => _editInvoice(invoice))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionButton(Icons.print_outlined, 'طباعة', _accentColor, () => _printInvoice(invoice))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionButton(Icons.share_outlined, 'واتساب', const Color(0xFF25D366), () => _shareInvoice(invoice))),
            const SizedBox(width: 6),
            Expanded(child: _buildActionButton(Icons.delete_outline_rounded, 'حذف', AppColors.error, () => _deleteInvoice(invoice))),
          ]),
        ],
      ),
    );
  }

  Future<void> _editInvoice(Map<String, dynamic> invoice) async {
    final notesController = TextEditingController(text: invoice['notes']?.toString() ?? '');
    final paidController = TextEditingController(text: (invoice['paid_amount'] ?? 0).toString());
    String selectedStatus = invoice['payment_status']?.toString() ?? 'كامل';
    final total = (invoice['total_amount'] ?? 0).toDouble();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('تعديل بيانات الفاتورة رقم ${invoice['invoice_number']}', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإجمالي: ${_formatNumber(total)} ﷼', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textMain),
                    decoration: InputDecoration(labelText: 'حالة السداد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: _inputFill),
                    items: ['كامل', 'جزئي', 'آجل'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: _textMain)))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedStatus = v;
                          if (v == 'كامل') paidController.text = total.toString();
                          if (v == 'آجل') paidController.text = '0';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textMain),
                    decoration: InputDecoration(labelText: 'المبلغ المدفوع', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: _inputFill),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: _textMain),
                    decoration: InputDecoration(labelText: 'الملاحظات', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: _inputFill),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: _textSub))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true) return;

    try {
      final db = ref.read(databaseHelperProvider);
      final newPaid = double.tryParse(paidController.text.trim()) ?? 0.0;
      final newNotes = notesController.text.trim();

      await db.updateInvoiceBasicInfo(
        invoiceId: invoice['id'] as int,
        isSale: _isSales,
        paidAmount: newPaid,
        paymentStatus: selectedStatus,
        notes: newNotes,
      );

      ref.read(invoicesListProvider(widget.type).notifier).loadInitialInvoices();
      _snack('تم حفظ تعديلات الفاتورة بنجاح', AppColors.success);
    } catch (e) {
      _snack('خطأ أثناء التعديل: $e', AppColors.error);
    }
  }

  Widget _buildDetailCard({required IconData icon, required String title, required String value, String? phone}) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _accentColor.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentColor.withOpacity(0.2))), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primary, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 10, color: _textHint)), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textMain)), if (phone != null && phone.isNotEmpty) Text('📞 $phone', style: TextStyle(fontSize: 10, color: _textSub))]))]));
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? valueColor, bool isBold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(icon, size: 15, color: valueColor ?? _textSub), const SizedBox(width: 6), Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: _textSub))), Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor ?? _textMain))]));
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 18), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))])));
  }
}

class _NumericDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateTimeChanged;
  final Color textColor;
  final Color accentColor;

  const _NumericDatePicker({required this.initialDate, required this.onDateTimeChanged, required this.textColor, required this.accentColor});

  @override
  State<_NumericDatePicker> createState() => _NumericDatePickerState();
}

class _NumericDatePickerState extends State<_NumericDatePicker> {
  late int day, month, year;
  late FixedExtentScrollController _dayController, _monthController, _yearController;

  @override
  void initState() {
    super.initState();
    day = widget.initialDate.day; month = widget.initialDate.month; year = widget.initialDate.year;
    _dayController = FixedExtentScrollController(initialItem: day - 1);
    _monthController = FixedExtentScrollController(initialItem: month - 1);
    _yearController = FixedExtentScrollController(initialItem: year - 2020);
  }

  @override
  void dispose() { _dayController.dispose(); _monthController.dispose(); _yearController.dispose(); super.dispose(); }

  int _getDaysInMonth(int y, int m) {
    if (m == 2) return ((y % 4 == 0) && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28;
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[m - 1];
  }

  void _updateDate() {
    int maxDays = _getDaysInMonth(year, month);
    if (day > maxDays) { day = maxDays; _dayController.animateToItem(day - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }
    widget.onDateTimeChanged(DateTime(year, month, day));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(color: widget.textColor, fontSize: 16, fontWeight: FontWeight.bold);
    return Row(
      children: [
        Expanded(child: CupertinoPicker(scrollController: _yearController, itemExtent: 40, selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: widget.accentColor.withOpacity(0.15)), onSelectedItemChanged: (i) { year = 2020 + i; _updateDate(); }, children: List.generate(20, (i) => Center(child: Text('${2020 + i}', style: textStyle))))),
        const Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
        Expanded(child: CupertinoPicker(scrollController: _monthController, itemExtent: 40, selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: widget.accentColor.withOpacity(0.15)), onSelectedItemChanged: (i) { month = i + 1; _updateDate(); }, children: List.generate(12, (i) => Center(child: Text((i + 1).toString().padLeft(2, '0'), style: textStyle))))),
        const Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
        Expanded(child: CupertinoPicker(scrollController: _dayController, itemExtent: 40, selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: widget.accentColor.withOpacity(0.15)), onSelectedItemChanged: (i) { day = i + 1; _updateDate(); }, children: List.generate(_getDaysInMonth(year, month), (i) => Center(child: Text((i + 1).toString().padLeft(2, '0'), style: textStyle))))),
      ],
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color headerBgColor;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? trailing;

  const _CollapsibleSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.headerBgColor,
    required this.child,
    this.initiallyExpanded = true,
    this.trailing,
  }) : super(key: key);

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.headerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: widget.iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.child,
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

