// lib/modules/invoices/views/sales_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:warehouse_app/core/widgets/transaction_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../database/database_helper.dart';

import '../../products/views/barcode_scanner_screen.dart';
import '../../returns/views/returns_list_screen.dart';
import '../providers/sales_invoice_provider.dart';

class SalesInvoiceScreen extends ConsumerStatefulWidget {
  const SalesInvoiceScreen({super.key});

  @override
  ConsumerState<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends ConsumerState<SalesInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  final _cashController = TextEditingController();
  final _transferController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _newCustomerNameController = TextEditingController();
  final _newCustomerPhoneController = TextEditingController();
  final _newCustomerAddressController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  static const Color _salesAccent = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    _cashController.dispose();
    _transferController.dispose();
    _dueDateController.dispose();
    _newCustomerNameController.dispose();
    _newCustomerPhoneController.dispose();
    _newCustomerAddressController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _formatNumber(num value) =>
      NumberFormat('#,##0.00', 'en_US').format(value);

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

  // ==================== الباركود والنافذة المنبثقة ====================
  Future<void> _scanBarcode() async {
    FocusManager.instance.primaryFocus?.unfocus();
    var status = await Permission.camera.request();
    if (status.isGranted && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeScannerScreen(
            searchInDatabase: false,
            onBarcodeScanned: (b) {
              _barcodeController.text = b;
              _searchByBarcode(b);
            },
          ),
        ),
      );
    } else {
      _snack('يرجى السماح بالوصول للكاميرا', AppColors.warning);
    }
  }

  Future<void> _searchByBarcode(String barcode) async {
    final notifier = ref.read(salesInvoiceProvider.notifier);
    final product = await notifier.fetchProductByBarcode(barcode);

    if (product != null) {
      if (!mounted) return;
      final quantity = await _showQuantityDialog(product);
      if (quantity != null && quantity > 0) {
        final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
        await notifier.addToCart(product, quantity, price,
            onError: (err) => _snack(err, AppColors.error));
        _barcodeController.clear();
        _barcodeFocusNode.requestFocus();
        _snack('✅ تمت الإضافة: ${product['name']}', AppColors.success);
      }
    } else {
      _snack('❌ المنتج غير موجود', AppColors.error);
    }
  }

  Future<int?> _showQuantityDialog(Map<String, dynamic> product) async {
    final ctrl = TextEditingController(text: '1');
    final productName = product['name'] ?? 'المنتج';
    final unitPrice = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
    final stockAvail = (product['current_stock'] as num?)?.toInt() ?? 0;
    final productId = product['id'];

    final cartItems = ref.read(salesInvoiceProvider).cartItems;

    // ✅ البحث عن العنصر باستخدام حلقة for (يعمل في كل الإصدارات)
    Map<String, dynamic>? existingItem;
    for (var item in cartItems) {
      if (item['productId'] == productId && item['isBonus'] != true) {
        existingItem = item;
        break;
      }
    }

    final alreadyInCart = existingItem != null
        ? (existingItem['quantity'] as num).toInt()
        : 0;
    final availableToAdd = stockAvail - alreadyInCart;

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (ctx, setS) {
            final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
            final cardBg = isDark ? AppColors.darkCardColor : Colors.white;
            final cardBorder = isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
            final textMain = isDark ? AppColors.darkTextPrimary : AppColors.navy;
            final textSub = isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
            final inputFill = isDark ? AppColors.navyLight : Colors.white;

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _salesAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart, color: _salesAccent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      productName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textMain),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        _dialogRow('السعر', '${_formatNumber(unitPrice)} ريال', _salesAccent, textSub),
                        const SizedBox(height: 4),
                        _dialogRow('المخزون', '$stockAvail', stockAvail <= 5 ? AppColors.error : AppColors.success, textSub),
                        if (alreadyInCart > 0) ...[
                          const SizedBox(height: 4),
                          _dialogRow('في السلة', '$alreadyInCart', AppColors.primary, textSub),
                        ],
                        if (availableToAdd <= 0)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_rounded, color: AppColors.error, size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'تمت إضافة كل الكمية المتاحة في السلة',
                                    style: TextStyle(color: AppColors.error, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(
                      labelText: 'الكمية المطلوبة',
                      hintText: 'أدخل الكمية',
                      labelStyle: TextStyle(color: textSub),
                      prefixIcon: const Icon(Icons.numbers, color: AppColors.primary),
                      suffixText: 'وحدة',
                      errorText: errorMessage,
                      filled: true,
                      fillColor: inputFill,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
                      ),
                    ),
                    onChanged: (v) {
                      setS(() {
                        final qty = int.tryParse(v);
                        if (qty != null && qty > availableToAdd && availableToAdd > 0) {
                          errorMessage = 'الكمية تتجاوز المخزون (المتاح: $availableToAdd)';
                        } else if (qty != null && qty <= 0) {
                          errorMessage = 'الكمية يجب أن تكون أكبر من صفر';
                        } else {
                          errorMessage = null;
                        }
                      });
                    },
                    onSubmitted: (v) {
                      final qty = int.tryParse(v);
                      if (qty != null && qty > 0 && (qty <= availableToAdd || availableToAdd <= 0)) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(context, qty);
                      }
                    },
                  ),
                  if (availableToAdd > 0 && availableToAdd <= 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '⚠️ الكمية المتاحة محدودة: $availableToAdd فقط',
                        style: const TextStyle(fontSize: 11, color: AppColors.warning),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [1, 2, 5, 10, 20].map((qty) {
                      final disabled = availableToAdd > 0 && qty > availableToAdd;
                      return InkWell(
                        onTap: disabled
                            ? null
                            : () {
                          ctrl.text = qty.toString();
                          setS(() => errorMessage = null);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: disabled ? cardBorder.withOpacity(0.3) : _salesAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: disabled ? cardBorder : _salesAccent.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '$qty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: disabled
                                  ? (isDark ? AppColors.darkTextHint : const Color(0xFF94A3B8))
                                  : _salesAccent,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(context);
                  },
                  child: Text('إلغاء', style: TextStyle(color: textSub)),
                ),
                ElevatedButton(
                  onPressed: availableToAdd <= 0
                      ? null
                      : () {
                    final qty = int.tryParse(ctrl.text.trim());
                    if (qty != null && qty > 0) {
                      if (availableToAdd > 0 && qty > availableToAdd) {
                        setS(() => errorMessage = 'الكمية تتجاوز المخزون (المتاح: $availableToAdd)');
                      } else {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(context, qty);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: availableToAdd <= 0 ? cardBorder : AppColors.primary,
                    foregroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    availableToAdd <= 0 ? 'المخزون منتهي' : 'إضافة للسلة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== العملاء وإضافتهم ====================
  void _showAddCustomerDialog(Color cardBg, Color textMain, Color textSub,
      Color inputFill, Color cardBorder) {
    _newCustomerNameController.clear();
    _newCustomerPhoneController.clear();
    _newCustomerAddressController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('إضافة عميل جديد',
            style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _styledTextField(
              controller: _newCustomerNameController,
              label: 'اسم العميل',
              icon: Icons.person_rounded,
              textMain: textMain,
              textSub: textSub,
              inputFill: inputFill,
              cardBorder: cardBorder,
            ),
            const SizedBox(height: 12),
            _styledTextField(
              controller: _newCustomerPhoneController,
              label: 'رقم الهاتف',
              icon: Icons.phone_rounded,
              keyboard: TextInputType.phone,
              textMain: textMain,
              textSub: textSub,
              inputFill: inputFill,
              cardBorder: cardBorder,
            ),
            const SizedBox(height: 12),
            _styledTextField(
              controller: _newCustomerAddressController,
              label: 'العنوان',
              icon: Icons.location_on_rounded,
              textMain: textMain,
              textSub: textSub,
              inputFill: inputFill,
              cardBorder: cardBorder,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: textSub))),
          ElevatedButton(
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await _saveNewCustomer();
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNewCustomer() async {
    final name = _newCustomerNameController.text.trim();
    if (name.isEmpty) {
      _snack('يرجى إدخال اسم العميل', AppColors.error);
      return;
    }
    try {
      final db = DatabaseHelper.instance;
      final id = await db.insertCustomer({
        'name': name,
        'phone': _newCustomerPhoneController.text.trim(),
        'address': _newCustomerAddressController.text.trim(),
      });

      final notifier = ref.read(salesInvoiceProvider.notifier);
      await notifier.loadInitialData();
      notifier.setCustomerId(id);

      _snack(' تم إضافة العميل بنجاح', AppColors.success);
    } catch (e) {
      _snack(' خطأ: $e', AppColors.error);
    }
  }

  // ==================== الحفظ والدفع ====================
  bool _validateInvoice(SalesInvoiceState state) {
    final errors = <String>[];
    if (state.cartItems.isEmpty) errors.add('يرجى إضافة منتجات إلى الفاتورة');
    if (state.remainingAmount > 0 && state.selectedDueDate == null) {
      errors.add('يرجى تحديد تاريخ الاستحقاق للمبلغ المتبقي');
    }
    if (state.selectedPaymentStatus == 'كامل' &&
        state.totalPaid < state.grandTotal) {
      errors.add(
          'يرجى إدخال كامل المبلغ (${_formatNumber(state.grandTotal)} ريال)');
    }
    if (state.totalPaid > state.grandTotal) {
      errors.add('المبلغ المدفوع أكبر من الإجمالي');
    }
    if (errors.isNotEmpty) {
      _snack(errors.join('\n'), AppColors.error);
      return false;
    }
    return true;
  }

  // ==================== الحفظ والدفع (الآلية الجديدة) ====================
  Future<void> _handleSaveInvoice(Color cardBg, Color textMain, Color textSub) async {
    final state = ref.read(salesInvoiceProvider);

    // 1. التحقق من صحة الفاتورة
    if (!_validateInvoice(state)) return;
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
            _confirmRow(' المنتجات', '${state.cartItems.length} صنف', textSub,
                textMain),
            _confirmRow(' الإجمالي', '${_formatNumber(state.grandTotal)} ريال',
                textSub, textMain, bold: true, valueColor: AppColors.primary),
            if (state.totalPaid > 0)
              _confirmRow(' المدفوع', '${_formatNumber(state.totalPaid)} ريال',
                  textSub, textMain, valueColor: AppColors.success),
            if (state.remainingAmount > 0)
              _confirmRow(' متبقي', '${_formatNumber(state.remainingAmount)} ريال',
                  textSub, textMain, valueColor: AppColors.error),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), // تراجع
              child: Text('إلغاء', style: TextStyle(color: textSub))),
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

    // 3. طلب البصمة / كلمة المرور (نظام التحقق الديناميكي)
    final authenticated = await TransactionGuard.check(
      context: context,
      ref: ref,
    );
    if (!authenticated) {
      _snack('❌ تم إلغاء الحفظ، فشل التحقق الأمني', AppColors.error);
      return;
    }

    // 4. الحفظ الفعلي في قاعدة البيانات
    final valuationMethod = ref.read(settingsProvider).value?.valuationMethod ?? 'WAC';
    final notifier = ref.read(salesInvoiceProvider.notifier);

    final result = await notifier.saveInvoice(
        _notesController.text.trim(), valuationMethod);

    if (result['success'] == true) {
      if (mounted) {
        final invNum = result['data']?['invoiceNumber']?.toString() ??
            'غير محدد';
        final cName = result['cName']?.toString() ?? 'عميل نقدي';
        final cPhone = result['cPhone']?.toString() ?? '';

        final snapshotState = ref.read(salesInvoiceProvider);

        _showSaveSuccessDialog(
            invNum, cName, cPhone, snapshotState, cardBg, textMain, textSub);

        notifier.clearCart();
        _notesController.clear();
        _cashController.clear();
        _transferController.clear();
        _dueDateController.clear();
      }
    } else {
      _snack(
          '❌ خطأ في الحفظ: ${result['error'] ?? 'حدث خطأ غير متوقع'}',
          AppColors.error);
    }
  }
  void _showSaveSuccessDialog(String invNum, String cName, String cPhone,
      SalesInvoiceState snapshotState, Color cardBg, Color textMain,
      Color textSub) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 24)),
            const SizedBox(width: 10),
            Text('تم الحفظ بنجاح',
                style: TextStyle(
                    color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('رقم الفاتورة: $invNum\nالعميل: $cName',
            style: TextStyle(color: textSub, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text('إغلاق', style: TextStyle(color: textSub))),
          if (cPhone.isNotEmpty)
            ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _sendViaWhatsApp(cName, cPhone, invNum, snapshotState);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.whatshot, size: 16),
                label: const Text('واتساب'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)))),
        ],
      ),
    );
  }

  Future<void> _sendViaWhatsApp(String customerName, String customerPhone,
      String invoiceNumber, SalesInvoiceState snapshotState) async {
    if (customerPhone.isEmpty) {
      _snack('❌ لا يوجد رقم هاتف مسجل للعميل', AppColors.error);
      return;
    }

    final date = DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now());

    String message = '*فاتورة بيع رقم $invoiceNumber*\n';
    message += 'التاريخ: $date\n';
    message += 'العميل: $customerName\n';
    message += '--------------------------------\n';
    for (var item in snapshotState.cartItems) {
      message +=
      '${item['quantity']} × ${item['productName']} = ${_formatNumber(item['total'])} ﷼\n';
    }
    message += '--------------------------------\n';
    message += 'المجموع الفرعي: ${_formatNumber(snapshotState.subtotal)} ﷼\n';
    if (snapshotState.discountAmount > 0) {
      message += 'الخصم: -${_formatNumber(snapshotState.discountAmount)} ﷼\n';
    }
    if (snapshotState.taxAmount > 0) {
      message += 'الضريبة: +${_formatNumber(snapshotState.taxAmount)} ﷼\n';
    }
    message += 'الإجمالي: ${_formatNumber(snapshotState.grandTotal)} ﷼\n';
    message += 'المدفوع: ${_formatNumber(snapshotState.totalPaid)} ﷼\n';
    if (snapshotState.remainingAmount > 0) {
      message += 'المتبقي: ${_formatNumber(snapshotState.remainingAmount)} ﷼\n';
    }
    if (snapshotState.selectedDueDate != null) {
      message +=
      'تاريخ الاستحقاق: ${DateFormat('yyyy-MM-dd').format(snapshotState.selectedDueDate!)}\n';
    }
    message += '--------------------------------\n';
    message += 'شكراً لتسوقكم معنا';

    final whatsappUrl =
        'https://wa.me/$customerPhone?text=${Uri.encodeComponent(message)}';

    try {
      await launchUrl(Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack(
          '❌ لم نتمكن من فتح واتساب. تأكد من تثبيت التطبيق.', AppColors.error);
    }
  }

  // ==================== بناء الواجهة ====================
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cardBgColor = isDark ? AppColors.darkCardColor : Colors.white;
    final cardBorderColor =
    isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMainColor =
    isDark ? AppColors.darkTextPrimary : AppColors.navy;
    final textSubColor =
    isDark ? AppColors.darkTextSecondary : const Color(0xFF475569);
    final textHintColor =
    isDark ? AppColors.darkTextHint : const Color(0xFF94A3B8);
    final inputFillColor = isDark ? AppColors.navyLight : Colors.white;
    final scaffoldBgColor =
    isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9);

    final state = ref.watch(salesInvoiceProvider);
    final notifier = ref.read(salesInvoiceProvider.notifier);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
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
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: _salesAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('فاتورة بيع جديدة',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined,
                color: AppColors.primary),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              showDialog(
                context: context,
                builder: (_) => CalculatorDialog(
                  isDarkMode: isDark,
                  onResult: (res) {
                    _cashController.text = res;
                    notifier.updatePayments(
                        double.tryParse(res) ?? 0, state.transferAmount);
                  },
                ),
              );
            },
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
                _salesAccent
              ]),
            ),
          ),
        ),
      ),
      body: state.isLoading && state.groups.isEmpty
          ? const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInvoiceHeader(state),
              const SizedBox(height: 16),
              _buildCustomerCurrencyCard(
                  state,
                  notifier,
                  cardBgColor,
                  cardBorderColor,
                  textMainColor,
                  textSubColor,
                  inputFillColor),
              const SizedBox(height: 14),
              _buildBarcodeScanCard(
                  state,
                  notifier,
                  cardBgColor,
                  cardBorderColor,
                  textMainColor,
                  textHintColor,
                  inputFillColor),
              const SizedBox(height: 14),
              _buildAddProductCard(
                  state,
                  notifier,
                  cardBgColor,
                  cardBorderColor,
                  textMainColor,
                  textSubColor,
                  inputFillColor),
              const SizedBox(height: 14),
              _buildDiscountTaxCard(
                  state,
                  notifier,
                  cardBgColor,
                  cardBorderColor,
                  textMainColor,
                  textSubColor,
                  inputFillColor),
              const SizedBox(height: 14),
              _buildPaymentCard(
                  state,
                  notifier,
                  cardBgColor,
                  cardBorderColor,
                  textMainColor,
                  textSubColor,
                  inputFillColor,
                  textHintColor),
              if (state.cartItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCartCard(
                    state,
                    notifier,
                    cardBgColor,
                    cardBorderColor,
                    textMainColor,
                    textSubColor),
              ],
              const SizedBox(height: 14),
              _buildNotesCard(cardBgColor, cardBorderColor,
                  textMainColor, textHintColor, inputFillColor),
              const SizedBox(height: 14),
              _buildTotalCard(state, textSubColor),
              const SizedBox(height: 16),
              _buildActionButtons(
                  state, cardBgColor, textMainColor, textSubColor),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== تفاصيل الواجهة ====================
  Widget _buildInvoiceHeader(SalesInvoiceState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyMedium],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _salesAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: _salesAccent.withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.point_of_sale_rounded,
                color: _salesAccent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('فاتورة بيع',
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
                      child: const Text('POS',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (state.cartItems.isNotEmpty)
            Column(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Text('${state.cartItems.length} صنف',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Text('${_formatNumber(state.grandTotal)} ﷼',
                    style: const TextStyle(
                        color: _salesAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
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
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.06),
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(title,
                      style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeScanCard(SalesInvoiceState state,
      SalesInvoiceNotifier notifier, Color bg, Color border, Color mainText,
      Color hintText, Color fill) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'مسح الباركود',
      icon: Icons.qr_code_scanner_rounded,
      iconColor: AppColors.primary,
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
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _searchByBarcode(v.trim());
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _scanBarcode,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppGradients.goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.navy, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCurrencyCard(SalesInvoiceState state,
      SalesInvoiceNotifier notifier, Color bg, Color border, Color mainText,
      Color subText, Color fill) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'بيانات العميل',
      icon: Icons.person_rounded,
      iconColor: _salesAccent,
      child: Column(
        children: [
          Row(
            children: [
              Text('نوع العميل:', style: TextStyle(color: subText, fontSize: 13)),
              const SizedBox(width: 8),
              ...[
                {'v': 'نقدي', 'c': _salesAccent},
                {'v': 'مسجل', 'c': AppColors.primary}
              ].map(
                    (t) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _choiceChip(
                    label: t['v'] as String,
                    selected: state.selectedCustomerType == t['v'],
                    color: t['c'] as Color,
                    border: border,
                    subText: subText,
                    onTap: () =>
                        notifier.setCustomerType(t['v'] as String),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.selectedCustomerType == 'مسجل') ...[
            Row(
              children: [
                Expanded(
                  child: _dropdownField<int>(
                    bg: bg,
                    border: border,
                    fill: fill,
                    mainText: mainText,
                    subText: subText,
                    label: 'اختر العميل',
                    value: state.selectedCustomerId,
                    icon: Icons.search_rounded,
                    items: state.customers
                        .map(
                          (c) => DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name'] ?? '',
                            style: TextStyle(color: mainText)),
                      ),
                    )
                        .toList(),
                    onChanged: (v) => notifier.setCustomerId(v),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _showAddCustomerDialog(
                        bg, mainText, subText, fill, border);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _salesAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _salesAccent.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: _salesAccent, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

        ],
      ),
    );
  }

  Widget _buildAddProductCard(SalesInvoiceState state,
      SalesInvoiceNotifier notifier, Color bg, Color border, Color mainText,
      Color subText, Color fill) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'إضافة منتج يدوياً',
      icon: Icons.add_shopping_cart_rounded,
      iconColor: _salesAccent,
      child: Column(
        children: [
          if (state.productLoading)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                backgroundColor: AppColors.navyBorder,
                minHeight: 2,
              ),
            ),
          _dropdownField<int>(
            bg: bg,
            border: border,
            fill: fill,
            mainText: mainText,
            subText: subText,
            label: 'المجموعة',
            value: state.selectedGroupId,
            icon: Icons.folder_rounded,
            items: state.groups
                .map(
                  (g) => DropdownMenuItem<int>(
                value: g['id'],
                child: Text(g['name'] ?? '',
                    style: TextStyle(color: mainText)),
              ),
            )
                .toList(),
            onChanged: state.productLoading
                ? null
                : (v) {
              if (v != null) notifier.loadCategories(v);
            },
          ),
          if (state.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dropdownField<int>(
              bg: bg,
              border: border,
              fill: fill,
              mainText: mainText,
              subText: subText,
              label: 'الفئة',
              value: state.selectedCategoryId,
              icon: Icons.category_rounded,
              items: state.categories
                  .map(
                    (c) => DropdownMenuItem<int>(
                  value: c['id'],
                  child: Text(c['name'] ?? '',
                      style: TextStyle(color: mainText)),
                ),
              )
                  .toList(),
              onChanged: state.productLoading
                  ? null
                  : (v) {
                if (v != null) notifier.loadSubcategories(v);
              },
            ),
          ],
          if (state.subcategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dropdownField<int>(
              bg: bg,
              border: border,
              fill: fill,
              mainText: mainText,
              subText: subText,
              label: 'الصنف',
              value: state.selectedSubcategoryId,
              icon: Icons.label_rounded,
              items: state.subcategories
                  .map(
                    (s) => DropdownMenuItem<int>(
                  value: s['id'],
                  child: Text(s['name'] ?? '',
                      style: TextStyle(color: mainText)),
                ),
              )
                  .toList(),
              onChanged: state.productLoading
                  ? null
                  : (v) {
                if (v != null) notifier.loadProducts(v);
              },
            ),
          ],
          if (state.products.isNotEmpty) ...[
            const SizedBox(height: 10),
            _dropdownField<int>(
              bg: bg,
              border: border,
              fill: fill,
              mainText: mainText,
              subText: subText,
              label: 'المنتج',
              value: state.selectedProductId,
              icon: Icons.inventory_2_rounded,
              items: state.products.map((p) {
                final stock = p['current_stock'] ?? 0;
                return DropdownMenuItem<int>(
                  value: p['id'],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p['name'] ?? '',
                            style: TextStyle(color: mainText, fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: stock > 5
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$stock',
                          style: TextStyle(
                            color: stock > 5 ? AppColors.success : AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: state.productLoading
                  ? null
                  : (v) {
                notifier.setProduct(v);
                final p = state.products.firstWhere(
                        (element) => element['id'] == v);
                _unitPriceController.text =
                    (p['unit_price'] ?? 0).toString();
              },
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numField(
                  border: border,
                  fill: fill,
                  mainText: mainText,
                  subText: subText,
                  controller: _quantityController,
                  label: 'الكمية',
                  icon: Icons.numbers_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numField(
                  border: border,
                  fill: fill,
                  mainText: mainText,
                  subText: subText,
                  controller: _unitPriceController,
                  label: 'السعر',
                  icon: Icons.sell_rounded,
                  suffix: 'ريال',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.productLoading
                  ? null
                  : () async {
                if (state.selectedProductId == null) {
                  _snack('اختر منتجاً', AppColors.warning);
                  return;
                }
                final qty = int.tryParse(_quantityController.text) ?? 0;
                final price =
                    double.tryParse(_unitPriceController.text) ?? 0.0;
                if (qty <= 0 || price <= 0) {
                  _snack('أدخل قيم صحيحة', AppColors.warning);
                  return;
                }
                final p = state.products.firstWhere(
                        (element) => element['id'] == state.selectedProductId);

                bool hasError = false;
                await notifier.addToCart(p, qty, price,
                    onError: (err) {
                      hasError = true;
                      _snack(err, AppColors.error);
                    });

                if (!hasError) {
                  _snack(
                      '✅ تمت إضافة ${p['name']} للسلة ($qty وحدة)',
                      AppColors.success);
                  _quantityController.text = '1';
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة للسلة',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.productLoading
                    ? AppColors.navyBorder
                    : _salesAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountTaxCard(SalesInvoiceState state,
      SalesInvoiceNotifier notifier, Color bg, Color border, Color mainText,
      Color subText, Color fill) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'الخصم والضريبة',
      icon: Icons.discount_rounded,
      iconColor: AppColors.warning,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _numField(
                  border: border,
                  fill: fill,
                  mainText: mainText,
                  subText: subText,
                  controller: _discountController,
                  label: state.isDiscountPercent
                      ? 'نسبة الخصم %'
                      : 'قيمة الخصم',
                  icon: Icons.discount_rounded,
                  suffix: state.isDiscountPercent ? '%' : 'ريال',
                  onChanged: (v) => notifier.applyDiscount(
                      double.tryParse(v) ?? 0, state.isDiscountPercent),
                ),
              ),
              const SizedBox(width: 8),
              IntrinsicWidth(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _discountToggle('%', true, subText, state, notifier),
                      _discountToggle('ريال', false, subText, state, notifier),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (state.discountAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.warning, size: 14),
                  const SizedBox(width: 4),
                  Text('خصم: ${_formatNumber(state.discountAmount)} ريال',
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _numField(
            border: border,
            fill: fill,
            mainText: mainText,
            subText: subText,
            controller: _taxController,
            label: 'نسبة الضريبة %',
            icon: Icons.receipt_long_rounded,
            suffix: '%',
            hint: '0',
            onChanged: (v) =>
                notifier.applyTax(double.tryParse(v) ?? 0),
          ),
          if (state.taxAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: AppColors.error, size: 14),
                  const SizedBox(width: 4),
                  Text('ضريبة: ${_formatNumber(state.taxAmount)} ريال',
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _discountToggle(String label, bool isPercent, Color subText,
      SalesInvoiceState state, SalesInvoiceNotifier notifier) {
    final selected = state.isDiscountPercent == isPercent;
    return InkWell(
      onTap: () {
        _discountController.clear();
        notifier.applyDiscount(0, isPercent);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.warning.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: selected ? AppColors.warning : subText,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(SalesInvoiceState state,
      SalesInvoiceNotifier notifier, Color bg, Color border, Color mainText,
      Color subText, Color fill, Color hintText) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'طريقة الدفع',
      icon: Icons.payment_rounded,
      iconColor: AppColors.primary,
      child: Column(
        children: [
          Row(
            children: [
              Text('حالة الدفع:',
                  style: TextStyle(color: subText, fontSize: 13)),
              const SizedBox(width: 8),
              ...[
                {'v': 'كامل', 'c': AppColors.success},
                {'v': 'جزئي', 'c': AppColors.warning},
                {'v': 'آجل', 'c': AppColors.error}
              ].map(
                    (t) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _choiceChip(
                    label: t['v'] as String,
                    selected: state.selectedPaymentStatus == t['v'],
                    color: t['c'] as Color,
                    border: border,
                    subText: subText,
                    onTap: () {
                      _cashController.clear();
                      _transferController.clear();
                      notifier.setPaymentStatus(t['v'] as String);
                    },
                  ),
                ),
              ),
            ],
          ),
          if (state.selectedPaymentStatus != 'آجل') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numField(
                    border: border,
                    fill: fill,
                    mainText: mainText,
                    subText: subText,
                    controller: _cashController,
                    label: 'كاش ',
                    icon: Icons.money_rounded,
                    onChanged: (v) => notifier.updatePayments(
                        double.tryParse(v) ?? 0, state.transferAmount),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField(
                    border: border,
                    fill: fill,
                    mainText: mainText,
                    subText: subText,
                    controller: _transferController,
                    label: 'حوالة',
                    icon: Icons.account_balance_rounded,
                    onChanged: (v) => notifier.updatePayments(
                        state.cashAmount, double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            if (state.totalPaid > 0 || state.remainingAmount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    _confirmRow('المدفوع', '${_formatNumber(state.totalPaid)} ﷼',
                        subText, mainText, valueColor: AppColors.success),
                    if (state.remainingAmount > 0)
                      _confirmRow('المتبقي',
                          '${_formatNumber(state.remainingAmount)} ﷼', subText,
                          mainText, valueColor: AppColors.error),
                  ],
                ),
              ),
            ],
          ],
          if (state.remainingAmount > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.selectedDueDate ??
                      DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate:
                  DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  _dueDateController.text =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  notifier.setDueDate(picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.selectedDueDate != null
                        ? AppColors.primary
                        : border,
                  ),
                ),
                child: Row(
                  children: [
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
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (state.selectedDueDate != null)
                      GestureDetector(
                        onTap: () {
                          _dueDateController.clear();
                          notifier.setDueDate(null);
                        },
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.error, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartCard(SalesInvoiceState state,
      SalesInvoiceNotifier notifier, Color bg, Color border, Color mainText,
      Color subText) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'السلة (${state.cartItems.length})',
      icon: Icons.shopping_cart_rounded,
      iconColor: _salesAccent,
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.cartItems.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: border),
            itemBuilder: (_, i) {
              final item = state.cartItems[i];
              final isBonus = item['isBonus'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isBonus
                            ? AppColors.success.withOpacity(0.2)
                            : _salesAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isBonus
                            ? const Icon(Icons.card_giftcard, size: 16,
                            color: AppColors.success)
                            : Text('${i + 1}',
                            style: const TextStyle(
                                color: _salesAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['productName'] ?? '',
                              style: TextStyle(
                                  color: isBonus
                                      ? AppColors.success
                                      : mainText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                              '${item['quantity']} × ${_formatNumber(item['unitPrice'])} ﷼',
                              style: TextStyle(
                                  color: subText, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(
                      isBonus ? 'مجاناً' : '${_formatNumber(item['total'])} ﷼',
                      style: TextStyle(
                        color: isBonus ? AppColors.success : _salesAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!isBonus)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: AppColors.error, size: 20),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          notifier.removeFromCart(i);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                notifier.clearCart();
              },
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AppColors.error, size: 16),
              label: const Text('مسح السلة',
                  style: TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(Color bg, Color border, Color mainText,
      Color hintText, Color fill) {
    return _card(
      bg: bg,
      border: border,
      textMain: mainText,
      title: 'ملاحظات',
      icon: Icons.notes_rounded,
      iconColor: AppColors.primary,
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
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(SalesInvoiceState state, Color textSub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyMedium],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          if (state.subtotal != state.grandTotal) ...[
            _dialogRow('المجموع الفرعي', '${_formatNumber(state.subtotal)} ﷼',
                Colors.white70, textSub),
            if (state.discountAmount > 0)
              _dialogRow('الخصم', '-${_formatNumber(state.discountAmount)} ﷼',
                  AppColors.warning, textSub),
            if (state.taxAmount > 0)
              _dialogRow('الضريبة (${state.taxRate.toStringAsFixed(0)}%)',
                  '+${_formatNumber(state.taxAmount)} ﷼', AppColors.error,
                  textSub),
            Divider(color: AppColors.primary.withOpacity(0.3), height: 20),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(' الإجمالي',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
              Text('${_formatNumber(state.grandTotal)} ﷼',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
            ],
          ),
          if (state.totalPaid > 0) ...[
            const SizedBox(height: 8),
            _dialogRow(' المدفوع', '${_formatNumber(state.totalPaid)} ﷼',
                AppColors.success, textSub),
          ],
          if (state.remainingAmount > 0) ...[
            const SizedBox(height: 4),
            _dialogRow(' المتبقي',
                '${_formatNumber(state.remainingAmount)} ﷼', AppColors.error,
                textSub),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(SalesInvoiceState state, Color cardBg,
      Color textMain, Color textSub) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton.icon(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              if (state.cartItems.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: cardBg,
                    title: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('تأكيد الخروج',
                            style: TextStyle(
                                color: textMain,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: Text(
                        'لديك منتجات في السلة، هل أنت متأكد من الخروج دون حفظ؟',
                        style: TextStyle(color: textSub)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('استمرار بالتعديل'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        child: const Text(
                            'خروج وإلغاء الفاتورة',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
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
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: state.isLoading || state.cartItems.isEmpty
                ? null
                : () => _handleSaveInvoice(cardBg, textMain, textSub),
            icon: state.isLoading
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.navy))
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              state.isLoading ? 'جاري الحفظ...' : 'حفظ الفاتورة',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.cartItems.isEmpty
                  ? AppColors.navyBorder
                  : AppColors.primary,
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
    required Color bg,
    required Color border,
    required Color fill,
    required Color mainText,
    required Color subText,
    List<Widget> Function(BuildContext)? selectedItemBuilder,
  }) {
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

  Widget _numField({
    required Color border,
    required Color fill,
    required Color mainText,
    required Color subText,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: mainText, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(

        labelText: label,
        labelStyle: TextStyle(color: subText, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: subText.withOpacity(0.6), fontSize: 12),
        suffixText: suffix,
        suffixStyle: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        filled: true,
        fillColor: fill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value, Color sub, Color main,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: sub,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? main,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value, Color valueColor,
      Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: sub, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    required Color border,
    required Color subText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : subText,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    required Color textMain,
    required Color textSub,
    required Color inputFill,
    required Color cardBorder,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: TextStyle(color: textMain),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSub),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: inputFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ==============================================================================
// كلاس الآلة الحاسبة (معدل - بدون Obx)
// ==============================================================================
class CalculatorDialog extends StatefulWidget {
  final bool isDarkMode;
  final Function(String) onResult;
  const CalculatorDialog({
    super.key,
    required this.isDarkMode,
    required this.onResult,
  });

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
        display = res % 1 == 0
            ? res.toInt().toString()
            : res.toStringAsFixed(4);
        isNewNumber = true;
      } else if (['+', '-', '×', '÷'].contains(btn)) {
        if (firstOperand != null && operator != null && !isNewNumber) {
          final second = double.tryParse(display) ?? 0;
          double res = 0;
          if (operator == '+') res = firstOperand! + second;
          else if (operator == '-') res = firstOperand! - second;
          else if (operator == '×') res = firstOperand! * second;
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
          if (operator == '+') res = firstOperand! + second;
          else if (operator == '-') res = firstOperand! - second;
          else if (operator == '×') res = firstOperand! * second;
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
      ['00', '0', '.', '='],
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
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.navy, AppColors.navyMedium]),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(26)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calculate_rounded,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'آلة حاسبة',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (expression.isNotEmpty)
                    Text(expression,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  Text(
                    display,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1),
                  ),
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
                        final bool isOp = ['+', '-', '×', '÷', '=']
                            .contains(btn);
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
                          btnFg = isDark
                              ? AppColors.textPrimary
                              : AppColors.navy;
                        }
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: GestureDetector(
                              onTap: () => press(btn),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 80),
                                height: 56,
                                decoration: BoxDecoration(
                                  color: btnBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isOp || isEq
                                      ? Border.all(
                                      color: AppColors.primary
                                          .withOpacity(0.4))
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    btn,
                                    style: TextStyle(
                                      color: btnFg,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
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

