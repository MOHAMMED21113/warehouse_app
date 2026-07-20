// lib/modules/invoices/views/purchase_invoice_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/transaction_guard.dart';
import '../../../database/database_helper.dart';
import '../../products/views/barcode_scanner_screen.dart';
import '../../returns/views/returns_list_screen.dart';

class PurchaseInvoiceScreen extends ConsumerStatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  ConsumerState<PurchaseInvoiceScreen> createState() =>
      _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends ConsumerState<PurchaseInvoiceScreen>
    with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ==================== State Management ====================
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subcategories = [];
  List<Map<String, dynamic>> _products = [];

  int? _selectedSupplierId;
  int? _selectedCurrencyId;
  int? _selectedGroupId;
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _selectedProductId;

  String _selectedPaymentType = 'آجل';
  String _selectedPaymentStatus = 'كامل';
  DateTime? _selectedDueDate;

  bool _isLoading = false;
  bool _productLoading = false;
  double _totalAmount = 0.0;
  double _cashAmount = 0.0;
  double _transferAmount = 0.0;
  double _totalPaid = 0.0;
  double _remainingAmount = 0.0;

  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  final _notesController = TextEditingController();
  final _cashController = TextEditingController();
  final _transferController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  static const Color _purchaseAccent = Color(0xFFE67E22);

  String _formatNumber(num value) =>
      NumberFormat('#,##0.00', 'en_US').format(value);

  @override
  void initState() {
    super.initState();
    _loadData();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    _notesController.dispose();
    _cashController.dispose();
    _transferController.dispose();
    _dueDateController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _confirmRow(
      String label, String value, Color txtSubColor, Color txtMainColor,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: txtSubColor,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? txtMainColor,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _updatePaymentCalculations() {
    setState(() {
      _totalPaid = _cashAmount + _transferAmount;
      _remainingAmount = _totalAmount - _totalPaid;
      if (_remainingAmount < 0) {
        _remainingAmount = 0;
        _cashAmount = _totalAmount;
        _transferAmount = 0;
        _cashController.text = _totalAmount.toStringAsFixed(2);
        _transferController.clear();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await db.getAllSuppliers();
      final currencies = await db.getAllCurrencies();
      final groups = await db.getAllGroups();

      setState(() {
        _suppliers = suppliers;
        _currencies = currencies;
        _groups = groups;
        if (_currencies.isNotEmpty && _selectedCurrencyId == null) {
          final defaultCurrency = _currencies.firstWhere(
              (c) => c['is_default'] == 1,
              orElse: () => <String, dynamic>{});
          _selectedCurrencyId = defaultCurrency.isNotEmpty
              ? defaultCurrency['id']
              : _currencies.first['id'];
        }
      });
    } catch (e) {
      debugPrint('خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories(int groupId) async {
    setState(() => _productLoading = true);
    try {
      final fetchedCategories = await db.getCategoriesByGroup(groupId);
      setState(() {
        _categories = fetchedCategories;
        _selectedCategoryId = null;
        _selectedSubcategoryId = null;
        _selectedProductId = null;
        _subcategories.clear();
        _products.clear();
      });
    } finally {
      if (mounted) setState(() => _productLoading = false);
    }
  }

  Future<void> _loadSubcategories(int categoryId) async {
    setState(() => _productLoading = true);
    try {
      final fetchedSubs = await db.getSubcategoriesByCategory(categoryId);
      setState(() {
        _subcategories = fetchedSubs;
        _selectedSubcategoryId = null;
        _selectedProductId = null;
        _products.clear();
      });
    } finally {
      if (mounted) setState(() => _productLoading = false);
    }
  }

  Future<void> _loadProducts(int subcategoryId) async {
    setState(() => _productLoading = true);
    try {
      final fetchedProducts = await db.getProductsBySubcategory(subcategoryId);
      setState(() {
        _products = fetchedProducts;
        _selectedProductId = null;
      });
    } finally {
      if (mounted) setState(() => _productLoading = false);
    }
  }

  Future<void> _handleAddToCartManual() async {
    if (_selectedProductId == null) {
      _snack('يرجى اختيار منتج', AppColors.warning);
      return;
    }

    final product = _products.firstWhere((p) => p['id'] == _selectedProductId);
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    final result = await _showQuantityPriceDialog(product, isDark);

    if (result != null) {
      final quantity = result['quantity'] as int;
      final unitCost = result['unitCost'] as double;
      _addOrUpdateCart(product, quantity, unitCost);
    }
  }

  void _addOrUpdateCart(
      Map<String, dynamic> product, int quantity, double unitCost) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((item) =>
          item['productId'] == product['id'] && item['unitCost'] == unitCost);

      if (existingIndex != -1) {
        final oldQuantity = _cartItems[existingIndex]['quantity'] as int;
        final newQuantity = oldQuantity + quantity;
        final newTotal =
            double.parse((newQuantity * unitCost).toStringAsFixed(2));
        _cartItems[existingIndex] = {
          ..._cartItems[existingIndex],
          'quantity': newQuantity,
          'total': newTotal,
        };
      } else {
        final total = double.parse((quantity * unitCost).toStringAsFixed(2));
        final currencySymbol = _currencies.firstWhere(
                (c) => c['id'] == _selectedCurrencyId,
                orElse: () => {'symbol': 'ريال'})['symbol'] ??
            'ريال';

        _cartItems.add({
          'productId': product['id'],
          'productName': product['name'],
          'quantity': quantity,
          'unitCost': unitCost,
          'currencySymbol': currencySymbol,
          'total': total,
        });
      }
      _calculateTotal();
      _selectedProductId = null;
      _quantityController.text = '1';
      _unitCostController.clear();
    });
    _snack(
        '✅ تمت إضافة ${product['name']} ($quantity × ${_formatNumber(unitCost)})',
        AppColors.success);
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    double sum = 0;
    for (var item in _cartItems) {
      sum += (item['total'] as num).toDouble();
    }
    setState(() {
      _totalAmount = double.parse(sum.toStringAsFixed(2));
      _updatePaymentCalculations();
    });
  }

  // ==================== 🚀 الباركود (الآلية الجديدة الآمنة 100%) ====================
  Future<void> _scanBarcode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    print('📷 _scanBarcode: بدء المسح');

    String? scannedBarcode; // متغير لاصطياد الباركود من الـ Callback
    bool isProcessing = false; // لمنع تكرار الإرسال

    final returnedBarcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (scannerCtx) => BarcodeScannerScreen(
          searchInDatabase: false,
          onBarcodeScanned: (code) {
            if (isProcessing) return;
            isProcessing = true;

            print('📷 Callback: الباركود الممسوح = $code');
            scannedBarcode = code;

            if (Navigator.canPop(scannerCtx)) {
              Navigator.pushReplacementNamed(scannerCtx, code);
            }
          },
        ),
      ),
    );

    // 🚀 الدمج الذكي: نأخذ القيمة إما من الـ Callback (الأضمن) أو من الارجاع
    final finalBarcode = returnedBarcode ?? scannedBarcode;

    print('📷 _scanBarcode: القيمة النهائية = $finalBarcode');

    if (!mounted) return;

    if (finalBarcode != null && finalBarcode.isNotEmpty) {
      _barcodeController.text = finalBarcode;

      // ⏱️ تأخير بسيط لضمان انتهاء أنيميشن إغلاق الكاميرا قبل فتح نافذة السعر
      await Future.delayed(const Duration(milliseconds: 300));

      await _searchByBarcode(finalBarcode);
    } else {
      print('⚠️ لم يتم مسح باركود أو تم التراجع');
      _snack('⚠️ لم يتم مسح باركود صحيح', AppColors.warning);
    }
  }

  Future<void> _searchByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    if (!mounted) return;

    print('🔍 _searchByBarcode: بدء البحث عن $barcode');
    setState(() => _isLoading = true);

    try {
      final product = await db.searchProductByAnyBarcode(barcode.trim());
      print(
          '🔍 _searchByBarcode: نتيجة البحث = ${product != null ? product['name'] : 'غير موجود'}');

      if (!mounted) return;

      if (product != null) {
        setState(() => _isLoading = false);

        // استخدام ref.read هنا لتجنب المشاكل
        final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

        final result = await _showQuantityPriceDialog(product, isDark);

        if (!mounted) return;

        if (result != null) {
          final quantity = result['quantity'] as int;
          final unitCost = result['unitCost'] as double;
          _addOrUpdateCart(product, quantity, unitCost);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('❌ المنتج غير موجود بالباركود: $barcode', AppColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('❌ خطأ: $e');
        _snack('❌ حدث خطأ أثناء البحث', AppColors.error);
      }
    }

    if (mounted) {
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
    }
  }

  // ==================== النافذة المنبثقة الذكية للسعر والكمية ====================
  Future<Map<String, dynamic>?> _showQuantityPriceDialog(
      Map<String, dynamic> product, bool isDark) async {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final productName = product['name'] ?? 'المنتج';

    final lastCost = (product['cost_price'] as num?)?.toDouble() ?? 0.0;
    if (lastCost > 0) {
      priceController.text = lastCost.toStringAsFixed(2);
    }

    final cardBg = isDark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppColors.darkTextPrimary : AppColors.navy;
    final textSub =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final inputFill = isDark ? AppColors.navyLight : Colors.white;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _purchaseAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_shopping_cart,
                      color: _purchaseAccent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    productName,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textMain),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _purchaseAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'المخزون الحالي: ${product['current_stock'] ?? 0}',
                                style: TextStyle(color: textSub, fontSize: 12)),
                            if (lastCost > 0)
                              Text(
                                  'آخر سعر شراء: ${_formatNumber(lastCost)} ريال',
                                  style: const TextStyle(
                                      color: AppColors.primary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: priceController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: 'سعر الشراء *',
                    hintText: 'أدخل سعر الشراء',
                    labelStyle: TextStyle(color: textSub),
                    prefixIcon: const Icon(Icons.monetization_on_rounded,
                        color: AppColors.primary, size: 20),
                    suffixText: 'ريال',
                    suffixStyle: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: inputFill,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: 'الكمية *',
                    hintText: 'أدخل الكمية',
                    labelStyle: TextStyle(color: textSub),
                    prefixIcon: const Icon(Icons.numbers_rounded,
                        color: AppColors.primary, size: 20),
                    suffixText: 'وحدة',
                    suffixStyle: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: inputFill,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2)),
                  ),
                  onSubmitted: (v) {
                    final qty = int.tryParse(v);
                    final price = double.tryParse(priceController.text.trim());
                    if (qty != null && qty > 0 && price != null && price > 0) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx, {'quantity': qty, 'unitCost': price});
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [1, 2, 5, 10, 20, 50, 100].map((qty) {
                      return InkWell(
                        onTap: () {
                          quantityController.text = qty.toString();
                          setDialogState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: _purchaseAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _purchaseAccent.withOpacity(0.4))),
                          child: Text('$qty',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _purchaseAccent,
                                  fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(ctx);
                },
                child: Text('إلغاء', style: TextStyle(color: textSub)),
              ),
              ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(quantityController.text.trim());
                  final price = double.tryParse(priceController.text.trim());
                  if (qty != null && qty > 0 && price != null && price > 0) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(ctx, {'quantity': qty, 'unitCost': price});
                  } else {
                    _snack('الرجاء إدخال كمية وسعر صحيحين', AppColors.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('إضافة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPaymentStatusChanged(String? newStatus) {
    if (newStatus == null) return;
    setState(() {
      _selectedPaymentStatus = newStatus;
      _cashAmount = 0;
      _transferAmount = 0;
      _totalPaid = 0;
      _remainingAmount = _totalAmount;
      _cashController.clear();
      _transferController.clear();
      if (newStatus == 'كامل') {
        _selectedDueDate = null;
        _dueDateController.clear();
      }
    });
  }

  Future<void> _selectDueDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _clearDueDate() {
    setState(() {
      _selectedDueDate = null;
      _dueDateController.clear();
    });
  }

  bool _validateInvoice() {
    final errors = <String>[];
    if (_selectedSupplierId == null) errors.add('يرجى اختيار المورد');
    if (_cartItems.isEmpty) errors.add('يرجى إضافة منتجات');
    if (_remainingAmount > 0 && _selectedDueDate == null)
      errors.add('يرجى تحديد تاريخ الاستحقاق');
    if (_selectedPaymentStatus == 'كامل' && _totalPaid < _totalAmount)
      errors.add('يرجى إدخال كامل المبلغ');
    if (_selectedDueDate != null && _selectedDueDate!.isBefore(DateTime.now()))
      errors.add('تاريخ الاستحقاق يجب أن يكون في المستقبل');

    if (errors.isNotEmpty) {
      _snack(errors.join('\n'), AppColors.error);
    }
    return errors.isEmpty;
  }

  // ==================== حفظ الفاتورة ====================
// ==================== حفظ الفاتورة (الآلية الجديدة) ====================
  Future<void> _saveInvoice(Color cardBg, Color textMain, Color textSub) async {
    // 1. التحقق من صحة الفاتورة
    if (!_validateInvoice()) return;
    FocusManager.instance.primaryFocus?.unfocus();

    // 2. عرض نافذة تأكيد الحفظ (أولاً وقبل أي شيء)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text('تأكيد الحفظ',
                style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _confirmRow(
                ' المنتجات', '${_cartItems.length} صنف', textSub, textMain),
            _confirmRow(' الإجمالي', '${_formatNumber(_totalAmount)} ريال',
                textSub, textMain,
                bold: true, valueColor: AppColors.primary),
            if (_cashAmount > 0)
              _confirmRow(' كاش', '${_formatNumber(_cashAmount)} ريال', textSub,
                  textMain),
            if (_transferAmount > 0)
              _confirmRow(' حوالة', '${_formatNumber(_transferAmount)} ريال',
                  textSub, textMain),
            if (_remainingAmount > 0)
              _confirmRow(' متبقي', '${_formatNumber(_remainingAmount)} ريال',
                  textSub, textMain,
                  valueColor: AppColors.error),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // تراجع
            child: Text('إلغاء', style: TextStyle(color: textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // تأكيد
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // إذا اختار المستخدم "إلغاء" أو أغلقت النافذة، نوقف العملية هنا
    if (confirm != true) return;

    // 3. طلب البصمة (بعد التأكيد، وقبل الحفظ الفعلي)
    final securityState = ref.read(securityProvider).value;
    if (securityState?.isTransactionLockEnabled == true) {
      final authenticated = await TransactionGuard.check(
        context: context,
        ref: ref,
      );
      if (!authenticated) {
        _snack('❌ لم يتم تأكيد البصمة، تم إلغاء الحفظ', AppColors.error);
        return; // نوقف العملية إذا فشلت البصمة أو تراجع المستخدم
      }
    }

    // 4. الحفظ الفعلي في قاعدة البيانات
    setState(() => _isLoading = true);

    try {
      final items = _cartItems
          .map((item) => {
                'productId': item['productId'],
                'quantity': item['quantity'],
                'unitCost': item['unitCost'],
              })
          .toList();

      final result = await db.createPurchaseInvoice(
        supplierId: _selectedSupplierId!,
        paymentType: _selectedPaymentType,
        paymentStatus: _selectedPaymentStatus,
        paidAmount: _totalPaid,
        dueDate: _selectedDueDate?.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        items: items,
      );

      if (result['success'] == true) {
        _snack('✅ تم حفظ فاتورة الشراء بنجاح', AppColors.success);
        if (mounted)
          Navigator.pop(context, true); // الرجوع للشاشة السابقة بعد نجاح الحفظ
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      _snack('❌ خطأ: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== البناء الرئيسي ====================
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final scaffoldBg =
        isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9);
    final cardBg = isDark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppColors.darkTextPrimary : AppColors.navy;
    final textSub =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final textHint = isDark ? AppColors.darkTextHint : const Color(0xFF94A3B8);
    final inputFill = isDark ? AppColors.navyLight : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_cartItems.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? AppColors.navyMedium : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('تنبيه', style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontWeight: FontWeight.bold)),
            content: Text('لديك منتجات في السلة، هل أنت متأكد من الخروج دون حفظ؟', style: TextStyle(color: isDark ? Colors.white70 : AppColors.navy)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.primary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                child: const Text('نعم، اخرج'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
            if (_cartItems.isEmpty) {
              Navigator.pop(context);
              return;
            }
            showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: isDark ? AppColors.navyMedium : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('تنبيه', style: TextStyle(color: isDark ? Colors.white : AppColors.navy, fontWeight: FontWeight.bold)),
                content: Text('لديك منتجات في السلة، هل أنت متأكد من الخروج دون حفظ؟', style: TextStyle(color: isDark ? Colors.white70 : AppColors.navy)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء', style: TextStyle(color: AppColors.primary)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                    child: const Text('نعم، اخرج'),
                  ),
                ],
              ),
            ).then((shouldPop) {
              if (shouldPop == true && context.mounted) {
                Navigator.pop(context);
              }
            });
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: _purchaseAccent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('فاتورة شراء جديدة',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.calculate_outlined, color: AppColors.primary),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              showDialog(
                context: context,
                builder: (_) => CalculatorDialog(
                  isDarkMode: isDark,
                  onResult: (res) {
                    setState(() {
                      _cashController.text = res;
                      _cashAmount = double.tryParse(res) ?? 0;
                      _updatePaymentCalculations();
                    });
                  },
                ),
              );
            },
            tooltip: 'آلة حاسبة',
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
                  _purchaseAccent
                ])))),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInvoiceHeader(),
              const SizedBox(height: 16),
              _buildSupplierCurrencyCard(
                  cardBg, cardBorder, textMain, textSub, inputFill),
              const SizedBox(height: 14),
              _buildBarcodeScanCard(
                  cardBg, cardBorder, textMain, textHint, inputFill),
              const SizedBox(height: 14),
              _buildAddProductCard(
                  cardBg, cardBorder, textMain, textSub, inputFill),
              const SizedBox(height: 14),
              _buildPaymentCard(
                  cardBg, cardBorder, textMain, textSub, inputFill, textHint),
              if (_cartItems.isNotEmpty)
                Column(children: [
                  const SizedBox(height: 14),
                  _buildCartCard(cardBg, cardBorder, textMain, textSub)
                ]),
              const SizedBox(height: 14),
              _buildNotesCard(
                  cardBg, cardBorder, textMain, textHint, inputFill),
              const SizedBox(height: 14),
              _buildTotalCard(textSub),
              const SizedBox(height: 16),
              _buildActionButtons(cardBg, textMain, textSub),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
    );
  }

  // ==================== بطاقات الواجهة ====================
  Widget _buildInvoiceHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyMedium],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _purchaseAccent.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _purchaseAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: _purchaseAccent.withOpacity(0.4), width: 1.5)),
              child: const Icon(Icons.receipt_long_rounded,
                  color: _purchaseAccent, size: 28)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Text('فاتورة شراء',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          gradient: AppGradients.goldGradient,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('PO',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)))
                ]),
                const SizedBox(height: 4),
                Text(
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12))
              ])),
        ],
      ),
    );
  }

  Widget _card(
      {required String title,
      required IconData icon,
      required Color iconColor,
      required Widget child,
      required Color bg,
      required Color border,
      required Color textMain}) {
    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.06),
                    border: Border(bottom: BorderSide(color: border))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: iconColor, size: 18)),
                  const SizedBox(width: 10),
                  Text(title,
                      style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))
                ])),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierCurrencyCard(
      Color bg, Color border, Color mainText, Color subText, Color fill) {
    return _card(
      title: 'بيانات المورد',
      icon: Icons.business_rounded,
      iconColor: _purchaseAccent,
      bg: bg,
      border: border,
      textMain: mainText,
      child: Column(
        children: [
          _dropdownField<int>(
              label: 'المورد',
              value: _selectedSupplierId,
              icon: Icons.person_rounded,
              bg: bg,
              border: border,
              fill: fill,
              mainText: mainText,
              subText: subText,
              items: _suppliers
                  .map((s) => DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text(s['name'] ?? 'غير معروف',
                          style: TextStyle(color: mainText))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSupplierId = v)),
          const SizedBox(height: 12),
          _dropdownField<int>(
              label: 'العملة',
              value: _selectedCurrencyId,
              icon: Icons.currency_exchange_rounded,
              bg: bg,
              border: border,
              fill: fill,
              mainText: mainText,
              subText: subText,
              items: _currencies
                  .map((c) => DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text('${c['name']} (${c['symbol'] ?? ''})',
                          style: TextStyle(color: mainText))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCurrencyId = v)),
        ],
      ),
    );
  }

  Widget _buildBarcodeScanCard(
      Color bg, Color border, Color mainText, Color hintText, Color fill) {
    return _card(
      title: 'مسح الباركود',
      icon: Icons.qr_code_scanner_rounded,
      iconColor: AppColors.primary,
      bg: bg,
      border: border,
      textMain: mainText,
      child: Row(
        children: [
          Expanded(
              child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode,
                  style: TextStyle(color: mainText),
                  decoration: InputDecoration(
                      hintText: 'مسح أو إدخال الباركود...',
                      hintStyle: TextStyle(color: hintText, fontSize: 13),
                      prefixIcon: const Icon(Icons.qr_code_rounded,
                          color: AppColors.primary, size: 20),
                      filled: true,
                      fillColor: fill,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2))),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _searchByBarcode(v.trim());
                  })),
          const SizedBox(width: 10),
          InkWell(
              onTap: _scanBarcode,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      gradient: AppGradients.goldGradient,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.navy, size: 24))),
        ],
      ),
    );
  }

  Widget _buildAddProductCard(
      Color bg, Color border, Color mainText, Color subText, Color fill) {
    return _card(
      title: 'إضافة منتج يدوياً',
      icon: Icons.add_shopping_cart_rounded,
      iconColor: _purchaseAccent,
      bg: bg,
      border: border,
      textMain: mainText,
      child: Column(
        children: [
          if (_productLoading)
            Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: const LinearProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                    backgroundColor: AppColors.navyBorder,
                    minHeight: 2)),
          _dropdownField<int>(
              label: 'المجموعة',
              value: _selectedGroupId,
              icon: Icons.folder_rounded,
              bg: bg,
              border: border,
              fill: fill,
              mainText: mainText,
              subText: subText,
              items: _groups
                  .map((g) => DropdownMenuItem<int>(
                      value: g['id'],
                      child: Text(g['name'] ?? '',
                          style: TextStyle(color: mainText))))
                  .toList(),
              onChanged: _productLoading
                  ? null
                  : (v) {
                      setState(() => _selectedGroupId = v);
                      if (v != null) _loadCategories(v);
                    }),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dropdownField<int>(
                label: 'الفئة',
                value: _selectedCategoryId,
                icon: Icons.category_rounded,
                bg: bg,
                border: border,
                fill: fill,
                mainText: mainText,
                subText: subText,
                items: _categories
                    .map((c) => DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name'] ?? '',
                            style: TextStyle(color: mainText))))
                    .toList(),
                onChanged: _productLoading
                    ? null
                    : (v) {
                        setState(() => _selectedCategoryId = v);
                        if (v != null) _loadSubcategories(v);
                      })
          ],
          if (_subcategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dropdownField<int>(
                label: 'النوع',
                value: _selectedSubcategoryId,
                icon: Icons.label_rounded,
                bg: bg,
                border: border,
                fill: fill,
                mainText: mainText,
                subText: subText,
                items: _subcategories
                    .map((s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text(s['name'] ?? '',
                            style: TextStyle(color: mainText))))
                    .toList(),
                onChanged: _productLoading
                    ? null
                    : (v) {
                        setState(() => _selectedSubcategoryId = v);
                        if (v != null) _loadProducts(v);
                      })
          ],
          if (_products.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dropdownField<int>(
                label: 'المنتج',
                value: _selectedProductId,
                icon: Icons.inventory_2_rounded,
                bg: bg,
                border: border,
                fill: fill,
                mainText: mainText,
                subText: subText,
                selectedItemBuilder: (context) {
                  return _products.map<Widget>((p) {
                    return Text(p['name'] ?? '',
                        style: TextStyle(
                            color: mainText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis);
                  }).toList();
                },
                items: _products.map((p) {
                  final stock = p['current_stock'] ?? 0;
                  return DropdownMenuItem<int>(
                      value: p['id'],
                      child: Row(children: [
                        Expanded(
                            child: Text(p['name'] ?? '',
                                style: TextStyle(color: mainText, fontSize: 13),
                                overflow: TextOverflow.ellipsis)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: stock > 0
                                    ? AppColors.success.withOpacity(0.12)
                                    : AppColors.error.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('$stock',
                                style: TextStyle(
                                    color: stock > 0
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)))
                      ]));
                }).toList(),
                onChanged: _productLoading
                    ? null
                    : (v) => setState(() => _selectedProductId = v))
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _productLoading ? null : _handleAddToCartManual,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة للسلة',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _productLoading ? AppColors.navyBorder : _purchaseAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Color bg, Color border, Color mainText,
      Color subText, Color fill, Color hintText) {
    return _card(
      title: 'معلومات الدفع',
      icon: Icons.payment_rounded,
      iconColor: AppColors.primary,
      bg: bg,
      border: border,
      textMain: mainText,
      child: Column(
        children: [
          Row(children: [
            Text('حالة الدفع:', style: TextStyle(color: subText, fontSize: 13)),
            const SizedBox(width: 8),
            ...[
              {'v': 'كامل', 'c': AppColors.success},
              {'v': 'جزئي', 'c': AppColors.warning},
              {'v': 'آجل', 'c': AppColors.error}
            ].map((t) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _choiceChip(
                    label: t['v'] as String,
                    selected: _selectedPaymentStatus == t['v'],
                    color: t['c'] as Color,
                    border: border,
                    subText: subText,
                    onTap: () => _onPaymentStatusChanged(t['v'] as String))))
          ]),
          if (_selectedPaymentStatus != 'آجل') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _numField(
                      controller: _cashController,
                      label: 'كاش ',
                      icon: Icons.money_rounded,
                      border: border,
                      fill: fill,
                      mainText: mainText,
                      subText: subText,
                      hintColor: hintText,
                      onChanged: (v) {
                        setState(() {
                          _cashAmount = double.tryParse(v) ?? 0;
                          _updatePaymentCalculations();
                        });
                      })),
              const SizedBox(width: 10),
              Expanded(
                  child: _numField(
                      controller: _transferController,
                      label: 'حوالة ',
                      icon: Icons.account_balance_rounded,
                      border: border,
                      fill: fill,
                      mainText: mainText,
                      subText: subText,
                      hintColor: hintText,
                      onChanged: (v) {
                        setState(() {
                          _transferAmount = double.tryParse(v) ?? 0;
                          _updatePaymentCalculations();
                        });
                      })),
            ]),
            if (_totalPaid > 0 || _remainingAmount > 0) ...[
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border)),
                  child: Column(children: [
                    _payRow('المدفوع', '${_formatNumber(_totalPaid)} ﷼',
                        AppColors.success, subText),
                    if (_remainingAmount > 0)
                      _payRow('المتبقي', '${_formatNumber(_remainingAmount)} ﷼',
                          AppColors.error, subText)
                  ])),
            ],
          ],
          if (_remainingAmount > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _selectDueDate();
              },
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _selectedDueDate != null
                              ? AppColors.primary
                              : border)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            _dueDateController.text.isEmpty
                                ? 'تحديد تاريخ الاستحقاق *'
                                : _dueDateController.text,
                            style: TextStyle(
                                color: _dueDateController.text.isEmpty
                                    ? hintText
                                    : AppColors.primary,
                                fontSize: 13))),
                    if (_selectedDueDate != null)
                      GestureDetector(
                          onTap: _clearDueDate,
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.error, size: 16))
                  ])),
            ),
          ],
        ],
      ),
    );
  }

  Widget _payRow(String label, String value, Color color, Color subText) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: subText, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14))
        ]));
  }

  Widget _buildCartCard(Color bg, Color border, Color mainText, Color subText) {
    return _card(
      title: 'السلة (${_cartItems.length})',
      icon: Icons.shopping_cart_rounded,
      iconColor: _purchaseAccent,
      bg: bg,
      border: border,
      textMain: mainText,
      child: Column(
        children: [
          ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cartItems.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: border),
              itemBuilder: (_, i) {
                final item = _cartItems[i];
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: _purchaseAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Center(
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: _purchaseAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item['productName'] ?? '',
                                style: TextStyle(
                                    color: mainText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text(
                                '${item['quantity']} × ${_formatNumber(item['unitCost'])} ﷼',
                                style: TextStyle(color: subText, fontSize: 11))
                          ])),
                      Text('${_formatNumber(item['total'])} ﷼',
                          style: const TextStyle(
                              color: _purchaseAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 6),
                      IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: AppColors.error, size: 20),
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            _removeFromCart(i);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints())
                    ]));
              }),
          const SizedBox(height: 8),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _clearCart();
                  },
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: AppColors.error, size: 16),
                  label: const Text('مسح السلة',
                      style: TextStyle(color: AppColors.error, fontSize: 12)))),
        ],
      ),
    );
  }

  Widget _buildNotesCard(
      Color bg, Color border, Color mainText, Color hintText, Color fill) {
    return _card(
      title: 'ملاحظات',
      icon: Icons.notes_rounded,
      iconColor: AppColors.primary,
      bg: bg,
      border: border,
      textMain: mainText,
      child: TextField(
          controller: _notesController,
          maxLines: 3,
          style: TextStyle(color: mainText, fontSize: 13),
          decoration: InputDecoration(
              hintText: 'أدخل ملاحظاتك هنا...',
              hintStyle: TextStyle(color: hintText, fontSize: 13),
              filled: true,
              fillColor: fill,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2)))),
    );
  }

  Widget _buildTotalCard(Color textSub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyMedium],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _purchaseAccent.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text(' إجمالي الشراء',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            Text('${_formatNumber(_totalAmount)} ﷼',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22))
          ]),
          if (_totalPaid > 0) ...[
            const SizedBox(height: 8),
            _totalRow(' المدفوع', _totalPaid, AppColors.success, textSub)
          ],
          if (_remainingAmount > 0) ...[
            const SizedBox(height: 4),
            _totalRow(' المتبقي', _remainingAmount, AppColors.error, textSub)
          ],
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, Color color, Color textSub) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 13)),
          Text('${value >= 0 ? '' : '-'}${_formatNumber(value.abs())} ﷼',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14))
        ]));
  }

  Widget _buildActionButtons(Color cardBg, Color textMain, Color textSub) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton.icon(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              if (_cartItems.isNotEmpty) {
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                            backgroundColor: cardBg,
                            title: Row(children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.error),
                              const SizedBox(width: 8),
                              Text('تأكيد الخروج',
                                  style: TextStyle(
                                      color: textMain,
                                      fontWeight: FontWeight.bold))
                            ]),
                            content: Text(
                                'لديك منتجات في السلة، هل أنت متأكد من الخروج دون حفظ؟',
                                style: TextStyle(color: textSub)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('استمرار بالتعديل')),
                              ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error),
                                  child: const Text('خروج وإلغاء الفاتورة',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)))
                            ]));
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('إلغاء'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isLoading || _cartItems.isEmpty
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _saveInvoice(cardBg, textMain, textSub);
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.navy))
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(_isLoading ? 'جاري الحفظ...' : 'حفظ الفاتورة',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
                backgroundColor: _cartItems.isEmpty
                    ? AppColors.navyBorder
                    : AppColors.primary,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4)),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField<T>(
      {required String label,
      required T? value,
      required IconData icon,
      required List<DropdownMenuItem<T>> items,
      ValueChanged<T?>? onChanged,
      List<Widget> Function(BuildContext)? selectedItemBuilder,
      required Color bg,
      required Color border,
      required Color fill,
      required Color mainText,
      required Color subText}) {
    final listItems = items.map((e) => e.value).whereType<T>().toList();

    String getLabel(T val) {
      try {
        final menuItem = items.firstWhere((element) => element.value == val);
        return _extractTextFromWidget(menuItem.child);
      } catch (_) {
        return '';
      }
    }

    return SearchableDropdownField<T>(
      value: value,
      items: listItems,
      itemLabel: getLabel,
      onChanged: onChanged ?? (_) {},
      label: label,
      prefixIcon: icon,
      isEnabled: onChanged != null,
    );
  }

  String _extractTextFromWidget(Widget? widget) {
    if (widget == null) return '';
    if (widget is Text) return widget.data ?? '';
    if (widget is Expanded) return _extractTextFromWidget(widget.child);
    if (widget is Flexible) return _extractTextFromWidget(widget.child);
    if (widget is Padding) return _extractTextFromWidget(widget.child);
    if (widget is Container) return _extractTextFromWidget(widget.child);
    if (widget is Align) return _extractTextFromWidget(widget.child);
    if (widget is Center) return _extractTextFromWidget(widget.child);
    if (widget is SizedBox) return _extractTextFromWidget(widget.child);
    if (widget is Row) return widget.children.map(_extractTextFromWidget).where((s) => s.isNotEmpty).join(' | ');
    if (widget is Column) return widget.children.map(_extractTextFromWidget).where((s) => s.isNotEmpty).join(' - ');
    if (widget is SingleChildRenderObjectWidget) return _extractTextFromWidget(widget.child);
    if (widget is MultiChildRenderObjectWidget) return widget.children.map(_extractTextFromWidget).where((s) => s.isNotEmpty).join(' ');
    return '';
  }

  Widget _numField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      String? suffix,
      String? hint,
      ValueChanged<String>? onChanged,
      required Color border,
      required Color fill,
      required Color mainText,
      required Color subText,
      required Color hintColor}) {
    return TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: mainText, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: subText, fontSize: 12),
            hintText: hint,
            hintStyle: TextStyle(color: hintColor, fontSize: 12),
            suffixText: suffix,
            suffixStyle: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
            filled: true,
            fillColor: fill,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2))));
  }

  Widget _choiceChip(
      {required String label,
      required bool selected,
      required Color color,
      required VoidCallback onTap,
      required Color border,
      required Color subText}) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: selected ? color : border, width: 1.5)),
            child: Text(label,
                style: TextStyle(
                    color: selected ? color : subText,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12))));
  }
}

// ==============================================================================
//  كلاس الآلة الحاسبة (بدون تغيير)
// ==============================================================================
class CalculatorDialog extends StatefulWidget {
  final bool isDarkMode;
  final Function(String) onResult;

  const CalculatorDialog(
      {super.key, required this.isDarkMode, required this.onResult});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String display = '0';
  String expression = '';
  double? firstOperand;
  String? operator;
  bool isNewNumber = true;

  void press(String btn) {
    setState(() {
      if (btn == 'C') {
        display = '0';
        expression = '';
        firstOperand = null;
        operator = null;
        isNewNumber = true;
      } else if (btn == '⌫') {
        if (display.length > 1) {
          display = display.substring(0, display.length - 1);
        } else {
          display = '0';
          isNewNumber = true;
        }
      } else if (btn == '%') {
        final v = double.tryParse(display) ?? 0;
        double res = v / 100;
        display =
            res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(4);
        isNewNumber = true;
      } else if (['+', '-', '×', '÷'].contains(btn)) {
        if (firstOperand != null && operator != null && !isNewNumber) {
          final second = double.tryParse(display) ?? 0;
          double res = 0;
          if (operator == '+')
            res = firstOperand! + second;
          else if (operator == '-')
            res = firstOperand! - second;
          else if (operator == '×')
            res = firstOperand! * second;
          else if (operator == '÷')
            res = second != 0 ? firstOperand! / second : 0;
          firstOperand = res;
        } else {
          firstOperand = double.tryParse(display) ?? 0;
        }
        operator = btn;
        expression =
            '${firstOperand! % 1 == 0 ? firstOperand!.toInt() : firstOperand} $btn';
        isNewNumber = true;
      } else if (btn == '=') {
        if (firstOperand != null && operator != null) {
          final second = double.tryParse(display) ?? 0;
          double res = 0;
          if (operator == '+')
            res = firstOperand! + second;
          else if (operator == '-')
            res = firstOperand! - second;
          else if (operator == '×')
            res = firstOperand! * second;
          else if (operator == '÷')
            res = second != 0 ? firstOperand! / second : 0;
          display = res % 1 == 0
              ? res.toInt().toString()
              : double.parse(res.toStringAsFixed(6)).toString();
          expression = '';
          firstOperand = null;
          operator = null;
          isNewNumber = true;
        }
      } else if (btn == '.') {
        if (isNewNumber) {
          display = '0.';
          isNewNumber = false;
        } else if (!display.contains('.')) {
          display += '.';
        }
      } else {
        if (isNewNumber || display == '0') {
          display = btn;
          isNewNumber = false;
        } else {
          if (display.length < 12) display += btn;
        }
      }
      widget.onResult(display);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? AppColors.darkCardColor : Colors.white;

    final List<List<String>> buttons = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['00', '0', '.', '=']
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Container(
        decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 4)
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.navy, AppColors.navyMedium],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(26))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(children: [
                          Icon(Icons.calculate_rounded,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 6),
                          Text('آلة حاسبة',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14))
                        ]),
                        GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white54, size: 20))
                      ]),
                  const SizedBox(height: 8),
                  if (expression.isNotEmpty)
                    Text(expression,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  Text(display,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: buttons.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: row.map((btn) {
                        final bool isOp =
                            ['+', '-', '×', '÷', '='].contains(btn);
                        final bool isOrange = ['C', '⌫', '%'].contains(btn);
                        final bool isEq = btn == '=';
                        Color btnBg, btnFg;
                        if (isEq) {
                          btnBg = AppColors.primary;
                          btnFg = AppColors.navy;
                        } else if (isOp) {
                          btnBg = AppColors.primary.withOpacity(0.15);
                          btnFg = AppColors.primary;
                        } else if (isOrange) {
                          btnBg = AppColors.warning.withOpacity(0.15);
                          btnFg = AppColors.warning;
                        } else {
                          btnBg = isDark
                              ? AppColors.navyLight
                              : const Color(0xFFF1F5F9);
                          btnFg =
                              isDark ? AppColors.textPrimary : AppColors.navy;
                        }
                        return Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: GestureDetector(
                                    onTap: () => press(btn),
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 80),
                                        height: 56,
                                        decoration: BoxDecoration(
                                            color: btnBg,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: isOp || isEq
                                                ? Border.all(
                                                    color: AppColors.primary
                                                        .withOpacity(0.4))
                                                : null),
                                        child: Center(
                                            child: Text(btn,
                                                style: TextStyle(
                                                    color: btnFg,
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.bold)))))));
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
