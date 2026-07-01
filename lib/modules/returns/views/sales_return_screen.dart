// lib/modules/returns/views/sales_return_screen.dart
import 'package:flutter/material.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/transaction_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../database/database_helper.dart';

class SalesReturnScreen extends ConsumerStatefulWidget {
  const SalesReturnScreen({super.key});

  @override
  ConsumerState<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends ConsumerState<SalesReturnScreen>
    with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _invoiceNumberController = TextEditingController();
  final _invoiceFocusNode = FocusNode();
  final _notesController = TextEditingController();

  // ==================== State Variables ====================

  bool _isLoading = false;
  Map<String, dynamic>? _invoiceData;
  List<Map<String, dynamic>> _returnItems = [];
  String _selectedRefundType = 'كاش';
  double _totalRefund = 0.0;


  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _invoiceFocusNode.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== دوال مساعدة ====================

  void _snack(String msg, Color bg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        backgroundColor: bg.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _confirmRow(
      String label, String value, Color subColor, Color mainColor,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: subColor, fontSize: 13)),
        Text(value,
            style: TextStyle(color: valueColor ?? mainColor, fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  // ==================== 1. البحث عن الفاتورة ====================

  Future<void> _searchInvoice() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final invoiceNumber = _invoiceNumberController.text.trim();

    if (invoiceNumber.isEmpty) {_snack('يرجى إدخال رقم فاتورة المبيعات', AppColors.warning);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final invoice = await db.getSaleInvoiceByNumber(invoiceNumber);
      if (invoice == null) {
        _snack('لم يتم العثور على فاتورة بهذا الرقم', AppColors.warning);

        setState(() {
          _invoiceData = null;
          _returnItems.clear();
          _totalRefund = 0;
        });

        return;
      }

      final items = (invoice['items'] as List).map((item) {
        return {
          'productId': item['product_id'],
          'productName': item['product_name'] ?? 'منتج غير معروف',
          'returnedQty': 0,
          'unitCost': (item['cost_price'] as num?)?.toDouble() ?? 0.0,
          'unitPrice': (item['unit_price'] as num?)?.toDouble() ?? 0.0,
          'maxQty': (item['quantity'] as num).toInt(),
        };
      }).toList();

      setState(() {
        _invoiceData = invoice;
        _returnItems = items;

        _calculateTotalRefund();
      });
    } catch (e) {
      _snack('حدث خطأ: $e', AppColors.warning);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== 2. تحديث الكمية (أزرار + و -) ====================

  void _incrementQty(int index) {
    setState(() {
      final item = _returnItems[index];

      if (item['returnedQty'] < item['maxQty']) {
        item['returnedQty']++;

        _calculateTotalRefund();
      }
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final item = _returnItems[index];

      if (item['returnedQty'] > 0) {
        item['returnedQty']--;

        _calculateTotalRefund();
      }
    });
  }

  // ==================== 3. حساب الإجمالي ====================

  void _calculateTotalRefund() {
    double total = 0;

    for (var item in _returnItems) {
      final qty = item['returnedQty'] as int;
      final price = item['unitPrice'] as double;
      total += (qty * price);
    }

    _totalRefund = double.parse(total.toStringAsFixed(2));
  }

  // ==================== 4. حفظ المرتجع ====================

  Future<void> _saveReturn(Color cardBg, Color textMain, Color textSub) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final hasItems =
        _returnItems.any((item) => (item['returnedQty'] as int) > 0);

    if (!hasItems) {
      _snack('يرجى تحديد كمية لمرتجع واحد على الأقل', AppColors.warning);

      return;
    }

    if (_totalRefund <= 0) {
      _snack('قيمة المرتجع يجب أن تكون أكبر من صفر', AppColors.warning);

      return;
    }

    final invoice = _invoiceData!;

    // نافذة التأكيد قبل الحفظ

    final authenticated = await TransactionGuard.check(
      context: context,
      ref: ref,
    );
    if (!authenticated) {
      _snack('? �� ����� ����١ ��� ������ ������', AppColors.warning);
      return;
    }
    final itemsToReturn = _returnItems
        .where((item) => (item['returnedQty'] as int) > 0)
        .map((item) => {
              'productId': item['productId'],
              'quantity': item['returnedQty'],
              'unitCost': item['unitCost'],
              'unitPrice': item['unitPrice'],
            })
        .toList();

    setState(() => _isLoading = true);

    try {
      final result = await db.processSalesReturn(
        originalInvoiceId: invoice['id'],
        customerId: invoice['customer_id'],
        returnItems: itemsToReturn,
        totalRefund: _totalRefund,
        refundType: _selectedRefundType,
        notes: _notesController.text.trim(),
      );

      if (result['success'] == true) {
        _snack(' تم تسجيل مرتجع المبيعات بنجاح (رقم: ${result['returnNumber']})', AppColors.success);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context); // العودة بعد النجاح
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      _snack(' خطأ: $e', AppColors.warning);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== بناء الواجهة ====================

  @override
  Widget build(BuildContext context) {
    // 🚀 جلب الثيم عبر Riverpod

    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cardBg = isDark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppColors.darkTextPrimary : AppColors.navy;
    final textSub = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final textHint = isDark ? AppColors.darkTextHint : const Color(0xFF94A3B8);
    final inputFill = isDark ? AppColors.navyLight : Colors.white;
    final scaffoldBg = isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.navyMedium : AppColors.navy,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.primary),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: FinancialColors.sales, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('مرتجع مبيعات',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
              height: 2,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                AppColors.navy,
                AppColors.primary.withOpacity(0.6),
                    FinancialColors.sales
              ]))),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(FinancialColors.sales)))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildSearchCard(
                        cardBg, cardBorder, textMain, textHint, inputFill),
                    if (_invoiceData != null) ...[
                      const SizedBox(height: 16),
                      _buildInvoiceDetailsCard(textMain, textSub),
                      const SizedBox(height: 16),
                      _buildReturnItemsCard(
                          cardBg, cardBorder, textMain, textSub, inputFill),
                      const SizedBox(height: 16),
                      _buildRefundTypeCard(
                          cardBg, cardBorder, textMain, textHint, inputFill),
                      const SizedBox(height: 16),
                      _buildTotalAndSaveCard(cardBg, textMain, textSub),
                    ]
                  ],
                ),
              ),
            ),
    );
  }

  // ==================== بطاقات الواجهة (مع تمرير الألوان) ====================

  Widget _buildSearchCard(Color cardBg, Color cardBorder, Color textMain,
      Color textHint, Color inputFill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('البحث عن فاتورة المبيعات الأصلية',
            style: TextStyle(
                color: textMain, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _invoiceNumberController,
              focusNode: _invoiceFocusNode,
              style: TextStyle(color: textMain),
              decoration: InputDecoration(
                hintText: 'رقم الفاتورة (مثال: SO-2026...)',
                hintStyle: TextStyle(color: textHint, fontSize: 13),
                filled: true,
                fillColor: inputFill,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: FinancialColors.sales, width: 2)),
              ),
              onSubmitted: (_) => _searchInvoice(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _searchInvoice,
            style: ElevatedButton.styleFrom(
                backgroundColor: FinancialColors.sales,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Icon(Icons.search_rounded),
          ),
        ]),
      ]),
    );
  }

  Widget _buildInvoiceDetailsCard(Color textMain, Color textSub) {
    final inv = _invoiceData!;

    final customerName = inv.containsKey('customer_name')
        ? inv['customer_name']
        : 'عميل غير معروف';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: FinancialColors.sales.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FinancialColors.sales.withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.receipt_rounded, color: FinancialColors.sales, size: 20),
          const SizedBox(width: 8),
          Text('بيانات الفاتورة المرجعية',
              style: TextStyle(
                  color: textMain, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const Divider(height: 20),
        _confirmRow('رقم الفاتورة', inv['invoice_number'] ?? '', textSub, textMain),
        _confirmRow('عميل', customerName ?? '', textSub, textMain),
        _confirmRow('تاريخ الفاتورة', inv['date'] != null ? DateFormat('yyyy/MM/dd').format(DateTime.parse(inv['date'])) : '', textSub, textMain),
        _confirmRow('إجمالي الفاتورة', '${(inv['total_amount'] as num).toStringAsFixed(2)} ﷼', textSub, textMain, bold: true, valueColor: FinancialColors.sales),
      ]),
    );
  }

  Widget _buildReturnItemsCard(Color cardBg, Color cardBorder, Color textMain,
      Color textSub, Color inputFill) {
    return Container(
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: cardBorder))),
          child: Row(children: [
            const Icon(Icons.assignment_return_rounded,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Text('المنتجات المرتجعة (تحديد الكميات)',
                style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _returnItems.length,
          separatorBuilder: (_, __) => const Divider(height: 24),
          itemBuilder: (ctx, i) {
            final item = _returnItems[i];

            final maxQty = item['maxQty'] as int;

            final currentReturnQty = item['returnedQty'] as int;

            final unitPrice = item['unitPrice'] as double;

            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 1,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['productName'] ?? '',
                          style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(' سعر البيع: $unitPrice  ﷼ ', style: TextStyle(color: textSub, fontSize: 12)),
                      Text(' الكمية المباعة الأصلية: $maxQty ', style: TextStyle(color: textSub, fontSize: 12)),
                    ]),
              ),
              Expanded(
                flex: 1,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder)),
                        child: FittedBox(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded,
                                  size: 18, color: AppColors.warning),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: currentReturnQty > 0
                                  ? () => _decrementQty(i)
                                  : null,
                            ),
                            Text('$currentReturnQty',
                                style: TextStyle(
                                    color: textMain,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.add_rounded,
                                  size: 18, color: AppColors.success),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: currentReturnQty < maxQty
                                  ? () => _incrementQty(i)
                                  : null,
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(' الإجمالي: ${_totalRefund.toStringAsFixed(2)}  ﷼ ',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ]),
              ),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _buildRefundTypeCard(Color cardBg, Color cardBorder, Color textMain,
      Color textHint, Color inputFill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('طريقة استرداد المبلغ إلى العميل',
            style: TextStyle(
                color: textMain, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: RadioListTile<String>(
              title: Text('كاش (للخزينة)',
                  style: TextStyle(
                      color: textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              value: 'كاش',
              groupValue: _selectedRefundType,
              activeColor: FinancialColors.sales,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _selectedRefundType = v!),
            ),
          ),
          Expanded(
            child: RadioListTile<String>(
              title: Text('آجل (خصم ديون)',
                  style: TextStyle(
                      color: textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              value: 'آجل',
              groupValue: _selectedRefundType,
              activeColor: FinancialColors.sales,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _selectedRefundType = v!),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: TextStyle(color: textMain),
          decoration: InputDecoration(
            hintText: 'سبب الإرجاع أو ملاحظات إضافية...',
            hintStyle: TextStyle(color: textHint, fontSize: 12),
            filled: true,
            fillColor: inputFill,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FinancialColors.sales, width: 2)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTotalAndSaveCard(Color cardBg, Color textMain, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.navy, AppColors.navyMedium],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppColors.warning.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.warning.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('إجمالي قيمة المرتجع',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text('${_totalRefund.toStringAsFixed(2)} ﷼',
              style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 24)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _totalRefund > 0
                ? () => _saveReturn(cardBg, textMain, textSub)
                : null,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('حفظ واعتماد المرتجع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              disabledBackgroundColor: Colors.grey.shade400,
            ),
          ),
        ),
      ]),
    );
  }
}
