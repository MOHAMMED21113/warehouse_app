// lib/modules/invoices/providers/sales_invoice_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../database/database_helper.dart';

class SalesInvoiceState {
  final bool isLoading;
  final bool productLoading;

  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> currencies;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> subcategories;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> cartItems;

  final int? selectedCustomerId;
  final int? selectedCurrencyId;
  final int? selectedGroupId;
  final int? selectedCategoryId;
  final int? selectedSubcategoryId;
  final int? selectedProductId;

  final String selectedPaymentType;
  final String selectedCustomerType;
  final String selectedPaymentStatus;
  final DateTime? selectedDueDate;

  final double cashAmount;
  final double transferAmount;
  final double totalPaid;
  final double remainingAmount;

  final double discountPercent;
  final double discountAmount;
  final bool isDiscountPercent;
  final double taxRate;
  final double taxAmount;
  final double subtotal;
  final double grandTotal;

  SalesInvoiceState({
    this.isLoading = false,
    this.productLoading = false,
    this.customers = const [],
    this.currencies = const [],
    this.groups = const [],
    this.categories = const [],
    this.subcategories = const [],
    this.products = const [],
    this.cartItems = const [],
    this.selectedCustomerId,
    this.selectedCurrencyId,
    this.selectedGroupId,
    this.selectedCategoryId,
    this.selectedSubcategoryId,
    this.selectedProductId,
    this.selectedPaymentType = 'آجل',
    this.selectedCustomerType = 'نقدي',
    this.selectedPaymentStatus = 'كامل',
    this.selectedDueDate,
    this.cashAmount = 0.0,
    this.transferAmount = 0.0,
    this.totalPaid = 0.0,
    this.remainingAmount = 0.0,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    this.isDiscountPercent = true,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.subtotal = 0.0,
    this.grandTotal = 0.0,
  });

  SalesInvoiceState copyWith({
    bool? isLoading, bool? productLoading,
    List<Map<String, dynamic>>? customers, List<Map<String, dynamic>>? currencies,
    List<Map<String, dynamic>>? groups, List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? subcategories, List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? cartItems,
    int? selectedCustomerId, bool clearCustomerId = false,
    int? selectedCurrencyId, int? selectedGroupId, int? selectedCategoryId,
    int? selectedSubcategoryId, int? selectedProductId,
    String? selectedPaymentType, String? selectedCustomerType, String? selectedPaymentStatus,
    DateTime? selectedDueDate, bool clearDueDate = false,
    double? cashAmount, double? transferAmount, double? totalPaid, double? remainingAmount,
    double? discountPercent, double? discountAmount, bool? isDiscountPercent,
    double? taxRate, double? taxAmount, double? subtotal, double? grandTotal,
  }) {
    return SalesInvoiceState(
      isLoading: isLoading ?? this.isLoading,
      productLoading: productLoading ?? this.productLoading,
      customers: customers ?? this.customers,
      currencies: currencies ?? this.currencies,
      groups: groups ?? this.groups,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      products: products ?? this.products,
      cartItems: cartItems ?? this.cartItems,
      selectedCustomerId: clearCustomerId ? null : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCurrencyId: selectedCurrencyId ?? this.selectedCurrencyId,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedSubcategoryId: selectedSubcategoryId ?? this.selectedSubcategoryId,
      selectedProductId: selectedProductId ?? this.selectedProductId,
      selectedPaymentType: selectedPaymentType ?? this.selectedPaymentType,
      selectedCustomerType: selectedCustomerType ?? this.selectedCustomerType,
      selectedPaymentStatus: selectedPaymentStatus ?? this.selectedPaymentStatus,
      selectedDueDate: clearDueDate ? null : (selectedDueDate ?? this.selectedDueDate),
      cashAmount: cashAmount ?? this.cashAmount,
      transferAmount: transferAmount ?? this.transferAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      isDiscountPercent: isDiscountPercent ?? this.isDiscountPercent,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      subtotal: subtotal ?? this.subtotal,
      grandTotal: grandTotal ?? this.grandTotal,
    );
  }
}

final salesInvoiceProvider = AutoDisposeNotifierProvider<SalesInvoiceNotifier, SalesInvoiceState>(SalesInvoiceNotifier.new);

class SalesInvoiceNotifier extends AutoDisposeNotifier<SalesInvoiceState> {
  final db = DatabaseHelper.instance;

  @override
  SalesInvoiceState build() {
    Future.microtask(() => loadInitialData());
    return SalesInvoiceState();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true);
    final customers = await db.getAllCustomers();
    final currencies = await db.getAllCurrencies();
    final groups = await db.getAllGroups();

    int? defCurrencyId;
    if (currencies.isNotEmpty) {
      final def = currencies.firstWhere((c) => c['is_default'] == 1, orElse: () => currencies.first);
      defCurrencyId = def['id'];
    }

    state = state.copyWith(isLoading: false, customers: customers, currencies: currencies, groups: groups, selectedCurrencyId: defCurrencyId);
  }

  // ===== محددات القوائم =====
  void setCustomerType(String type) => state = state.copyWith(selectedCustomerType: type, clearCustomerId: true);
  void setCustomerId(int? id) => state = state.copyWith(selectedCustomerId: id);
  void setCurrencyId(int? id) => state = state.copyWith(selectedCurrencyId: id);

  Future<void> loadCategories(int groupId) async {
    state = state.copyWith(productLoading: true, selectedGroupId: groupId, categories: [], subcategories: [], products: [], selectedCategoryId: null, selectedSubcategoryId: null, selectedProductId: null);
    final categories = await db.getCategoriesByGroup(groupId);
    state = state.copyWith(productLoading: false, categories: categories);
  }

  Future<void> loadSubcategories(int categoryId) async {
    state = state.copyWith(productLoading: true, selectedCategoryId: categoryId, subcategories: [], products: [], selectedSubcategoryId: null, selectedProductId: null);
    final subcategories = await db.getSubcategoriesByCategory(categoryId);
    state = state.copyWith(productLoading: false, subcategories: subcategories);
  }

  Future<void> loadProducts(int subcategoryId) async {
    state = state.copyWith(productLoading: true, selectedSubcategoryId: subcategoryId, products: [], selectedProductId: null);
    final products = await db.getProductsBySubcategory(subcategoryId);
    state = state.copyWith(productLoading: false, products: products);
  }

  void setProduct(int? productId) => state = state.copyWith(selectedProductId: productId);

  // ===== العمليات الحسابية =====
  void _calculateTotals() {
    double subtotal = 0;
    for (var item in state.cartItems) subtotal += (item['total'] as num).toDouble();

    double discAmt = state.isDiscountPercent ? (subtotal * state.discountPercent / 100) : state.discountAmount;

    final taxable = subtotal - discAmt;
    double taxAmt = taxable * state.taxRate / 100;
    double grandTotal = taxable + taxAmt;
    double remaining = grandTotal - state.totalPaid;

    if (remaining < 0) remaining = 0;

    state = state.copyWith(
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      discountAmount: double.parse(discAmt.toStringAsFixed(2)),
      taxAmount: double.parse(taxAmt.toStringAsFixed(2)),
      grandTotal: double.parse(grandTotal.toStringAsFixed(2)),
      remainingAmount: double.parse(remaining.toStringAsFixed(2)),
    );
  }

  void updatePayments(double cash, double transfer) {
    double totalPaid = cash + transfer;
    double remaining = state.grandTotal - totalPaid;
    state = state.copyWith(cashAmount: cash, transferAmount: transfer, totalPaid: totalPaid, remainingAmount: remaining);
  }

  void setPaymentStatus(String status) {
    state = state.copyWith(selectedPaymentStatus: status, cashAmount: 0, transferAmount: 0, totalPaid: 0, remainingAmount: state.grandTotal, clearDueDate: status == 'كامل');
  }

  void applyDiscount(double value, bool isPercent) {
    state = state.copyWith(isDiscountPercent: isPercent, discountPercent: isPercent ? value : (state.subtotal > 0 ? (value / state.subtotal) * 100 : 0), discountAmount: isPercent ? (state.subtotal * value / 100) : value);
    _calculateTotals();
  }

  void applyTax(double rate) {
    state = state.copyWith(taxRate: rate);
    _calculateTotals();
  }

  void setDueDate(DateTime? date) => state = state.copyWith(selectedDueDate: date, clearDueDate: date == null);

  // 🚀 جلب المنتج فقط لعرضه في النافذة المنبثقة (دون إضافته مباشرة)
  Future<Map<String, dynamic>?> fetchProductByBarcode(String barcode) async {
    state = state.copyWith(isLoading: true);
    try {
      return await db.searchProductByAnyBarcode(barcode); // ✅ التعديل هنا

    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ===== إضافة المنتج للسلة =====
  Future<void> addToCart(Map<String, dynamic> product, int quantity, double unitPrice, {required Function(String) onError}) async {
    // حل مشكلة التحويل الآمن للمخزون
    final stock = (product['current_stock'] as num?)?.toInt() ?? 0;
    final existingIdx = state.cartItems.indexWhere((i) => i['productId'] == product['id'] && i['isBonus'] == false);
    final inCart = existingIdx != -1 ? (state.cartItems[existingIdx]['quantity'] as num).toInt() : 0;

    if (stock < (inCart + quantity)) {
      onError('المخزون لا يكفي! المتاح: $stock، وفي السلة: $inCart');
      return;
    }

    final List<Map<String, dynamic>> newCart = List.from(state.cartItems);
    final sym = state.currencies.firstWhereOrNull((c) => c['id'] == state.selectedCurrencyId)?['symbol'] ?? 'ريال';

    if (existingIdx != -1) {
      final newQty = inCart + quantity;
      newCart[existingIdx] = {
        ...newCart[existingIdx],
        'quantity': newQty,
        'total': double.parse((newQty * unitPrice).toStringAsFixed(2)),
      };
    } else {
      newCart.add({
        'productId': product['id'],
        'productName': product['name'],
        'quantity': quantity,
        'unitPrice': unitPrice,
        'currencySymbol': sym,
        'total': double.parse((quantity * unitPrice).toStringAsFixed(2)),
        'isBonus': false,
      });
    }

    state = state.copyWith(cartItems: newCart);
    await _checkAndApplyBonus();
    _calculateTotals();
  }

  Future<void> _checkAndApplyBonus() async {
    final List<Map<String, dynamic>> cleanCart = state.cartItems.where((i) => i['isBonus'] == false).toList();
    final List<Map<String, dynamic>> pendingBonuses = [];

    for (var item in cleanCart) {
      final product = await db.getProductById(item['productId']);
      if (product != null && product['bonus_enabled'] == 1) {
        // حماية البيانات باستخدام num
        final requiredQty = (product['bonus_required_qty'] as num?)?.toInt() ?? 0;
        final freeProdId = (product['bonus_free_product_id'] as num?)?.toInt();
        final freeQtyFactor = (product['bonus_free_qty'] as num?)?.toInt() ?? 1;

        if (requiredQty > 0 && freeProdId != null) {
          final int purchasedQty = (item['quantity'] as num).toInt();
          final int totalFreeQty = (purchasedQty ~/ requiredQty) * freeQtyFactor;

          if (totalFreeQty > 0) {
            final freeProduct = await db.getProductById(freeProdId);
            if (freeProduct != null) {
              pendingBonuses.add({
                'productId': freeProduct['id'],
                'productName': '🎁 بونص: ${freeProduct['name']}',
                'quantity': totalFreeQty,
                'unitPrice': 0.0,
                'currencySymbol': item['currencySymbol'],
                'total': 0.0,
                'isBonus': true,
              });
            }
          }
        }
      }
    }

    cleanCart.addAll(pendingBonuses);
    state = state.copyWith(cartItems: cleanCart);
  }

  void removeFromCart(int index) async {
    final newCart = List<Map<String, dynamic>>.from(state.cartItems);
    newCart.removeAt(index);
    state = state.copyWith(cartItems: newCart);
    await _checkAndApplyBonus();
    _calculateTotals();
  }

  void clearCart() {
    state = state.copyWith(cartItems: []);
    _calculateTotals();
  }

  Future<Map<String, dynamic>> saveInvoice(String notes, String valuationMethod) async {
    state = state.copyWith(isLoading: true);
    try {
      String? customerName;
      String? customerPhone;
      if (state.selectedCustomerId != null) {
        final c = state.customers.firstWhereOrNull((x) => x['id'] == state.selectedCustomerId);
        customerName = c?['name'];
        customerPhone = c?['phone'];
      }

      final items = state.cartItems.map((item) => {
        'productId': item['productId'],
        'quantity': item['quantity'],
        'unitPrice': item['unitPrice'],
        'isBonus': item['isBonus'],
      }).toList();

      final result = await db.createSaleInvoice(
        customerId: state.selectedCustomerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerType: state.selectedCustomerType,
        paymentStatus: state.selectedPaymentStatus,
        paidAmount: state.totalPaid,
        dueDate: state.selectedDueDate?.toIso8601String(),
        notes: notes,
        items: items,
        grandTotal: state.grandTotal,
        subtotal: state.subtotal,
        discountAmount: state.discountAmount,
        taxAmount: state.taxAmount,
        taxRate: state.taxRate,
        valuationMethod: valuationMethod,
      );

      state = state.copyWith(isLoading: false);
      return {'success': true, 'data': result, 'cName': customerName, 'cPhone': customerPhone};
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return {'success': false, 'error': e.toString()};
    }
  }
}