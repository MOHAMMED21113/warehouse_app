// lib/modules/products/views/add_product_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../providers/add_product_provider.dart';
import 'barcode_scanner_screen.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product;
  const AddProductScreen({super.key, this.product});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  // ===== الألوان المتكيفة (نفس منطقك القديم ولكن بـ Riverpod) =====
  bool get _dark => ref.watch(themeModeProvider) == ThemeMode.dark;
  Color get _scaffoldBg => _dark ? AppColors.navy : const Color(0xFFF1F5F9);
  Color get _cardBg => _dark ? AppColors.navyCard : Colors.white;
  Color get _cardBorder => _dark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
  Color get _textMain => _dark ? AppColors.textPrimary : AppColors.navy;
  Color get _textSub => _dark ? AppColors.textSecondary : const Color(0xFF475569);
  Color get _textHint => _dark ? AppColors.textHint : const Color(0xFF94A3B8);
  Color get _inputFill => _dark ? AppColors.navyLight : const Color(0xFFF8FAFC);
  static const Color _accentColor = Color(0xFF3B82F6);

  // Controllers
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _profitPercentController = TextEditingController(text: '20');
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _newGroupController = TextEditingController();
  final _bonusRequiredQtyController = TextEditingController();
  final _bonusFreeQtyController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  final Map<int, TextEditingController> _unitPriceControllers = {};
  final Map<int, bool> _isDefaultUnit = {};

  double _profitPercentage = 20.0;
  double _profitAmount = 0.0;
  bool _isEditing = false;
  int? _editingProductId;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    if (_isEditing) _editingProductId = (widget.product!['id'] as num).toInt();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final formData = await ref.read(addProductProvider.notifier).loadInitialData(widget.product);
      if (!mounted) return;

      if (formData != null) {
        final p = formData['product'];
        _nameController.text = p['name']?.toString() ?? '';
        _barcodeController.text = p['barcode']?.toString() ?? '';

        final cost = (p['cost_price'] as num?)?.toDouble() ?? 0.0;
        final price = (p['unit_price'] as num?)?.toDouble() ?? 0.0;
        _costPriceController.text = cost > 0 ? cost.toStringAsFixed(2) : '';

        if (cost > 0) {
          if (price > cost) {
            _profitAmount = price - cost;
            _profitPercentage = double.parse(((_profitAmount / cost) * 100).toStringAsFixed(2));
          } else {
            _profitPercentage = 20.0;
            _profitAmount = cost * _profitPercentage / 100;
          }
          _profitPercentController.text = _profitPercentage.toStringAsFixed(1);
        } else {
          _profitAmount = price;
          _profitPercentage = 20.0;
          _profitPercentController.text = '20.0';
        }
        _priceController.text = price.toStringAsFixed(2);

        _stockController.text = ((p['current_stock'] as num?)?.toInt() ?? 0).toString();
        _minStockController.text = ((p['min_stock'] as num?)?.toInt() ?? 0).toString();

        if (p['expiry_date'] != null) {
          try {
            final date = DateTime.parse(p['expiry_date'].toString());
            _expiryDateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        if (p['bonus_enabled'] == 1) {
          _bonusRequiredQtyController.text = ((p['bonus_required_qty'] as num?)?.toInt() ?? '').toString();
          _bonusFreeQtyController.text = ((p['bonus_free_qty'] as num?)?.toInt() ?? 1).toString();
        }
      }

      final units = ref.read(addProductProvider).units;
      final prices = formData?['prices'] as Map<int, double>?;
      final defUnit = formData?['defaultUnitId'] as int?;

      for (var u in units) {
        final uid = (u['id'] as num).toInt();
        _unitPriceControllers[uid] = TextEditingController(text: prices?[uid]?.toString() ?? '');
        _isDefaultUnit[uid] = defUnit == uid;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose(); _barcodeController.dispose(); _priceController.dispose();
    _stockController.dispose(); _minStockController.dispose(); _expiryDateController.dispose();
    _newGroupController.dispose(); _costPriceController.dispose(); _profitPercentController.dispose();
    _bonusRequiredQtyController.dispose(); _bonusFreeQtyController.dispose();
    for (var c in _unitPriceControllers.values) { c.dispose(); }
    super.dispose();
  }

  // 🎯 حسابات السعر والربح (نفس منطقك الدقيق)
  void _calculateSellingPrice() {
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0;
    final percentage = double.tryParse(_profitPercentController.text.trim()) ?? 0;
    setState(() {
      _profitPercentage = percentage;
      _profitAmount = costPrice * percentage / 100;
      _priceController.text = (costPrice + _profitAmount).toStringAsFixed(2);
    });
  }

  void _calculateProfitFromSellingPrice() {
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0;
    final sellingPrice = double.tryParse(_priceController.text.trim()) ?? 0;
    setState(() {
      if (costPrice > 0) {
        _profitAmount = sellingPrice - costPrice;
        _profitPercentage = (_profitAmount / costPrice) * 100;
        _profitPercentController.text = _profitPercentage.toStringAsFixed(1);
      } else {
        _profitAmount = sellingPrice;
        _profitPercentage = 100.0;
        _profitPercentController.text = '100.0';
      }
    });
  }

  // 🎯 ديالوج الإضافة السريعة للفئات والأصناف
  Future<String?> _showTextInputDialog(String title, String label) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: _textMain, fontSize: 16)),
        content: TextField(
          controller: c, autofocus: true, style: TextStyle(color: _textMain),
          decoration: InputDecoration(
            labelText: label, labelStyle: TextStyle(color: _textSub), filled: true, fillColor: _inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _cardBorder)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: TextStyle(color: _textSub))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.navy),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating));
  }

  // 🎯 عملية الحفظ
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(addProductProvider);
    final notifier = ref.read(addProductProvider.notifier);

    if (state.selectedSubcategoryId == null || state.selectedUnitId == null || state.selectedCurrencyId == null) {
      _snack('يرجى إكمال جميع الاختيارات الأساسية', AppColors.warning); return;
    }

    int? reqQty; int freeQty = 1;
    if (state.isBonusEnabled) {
      reqQty = int.tryParse(_bonusRequiredQtyController.text.trim());
      if (reqQty == null || reqQty <= 0) { _snack('أدخل كمية مطلوبة للبونص صحيحة', AppColors.warning); return; }
      freeQty = int.tryParse(_bonusFreeQtyController.text.trim()) ?? 1;
      if (state.selectedBonusFreeProductId == null) { _snack('اختر المنتج المجاني', AppColors.warning); return; }
    }

    final payload = {
      'name': _nameController.text.trim(),
      'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      'subcategory_id': state.selectedSubcategoryId,
      'unit_id': state.selectedUnitId,
      'currency_id': state.selectedCurrencyId,
      'unit_price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'cost_price': double.tryParse(_costPriceController.text.trim()) ?? 0.0,
      'current_stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'min_stock': int.tryParse(_minStockController.text.trim()) ?? 0,
      'supplier_id': state.selectedSupplierId,
      'expiry_date': state.selectedExpiryDate?.toIso8601String(),
      'warehouse_id': state.selectedWarehouseId,
      'warehouse_stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'bonus_enabled': state.isBonusEnabled ? 1 : 0,
      'bonus_required_qty': state.isBonusEnabled ? reqQty : null,
      'bonus_free_product_id': state.isBonusEnabled ? state.selectedBonusFreeProductId : null,
      'bonus_free_qty': state.isBonusEnabled ? freeQty : null,
    };

    final Map<int, double> parsedUnitPrices = {};
    int? defaultUnit;
    for (final uid in _unitPriceControllers.keys) {
      final val = double.tryParse(_unitPriceControllers[uid]!.text.trim());
      if (val != null && val > 0) parsedUnitPrices[uid] = val;
      if (_isDefaultUnit[uid] == true) defaultUnit = uid;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final result = await notifier.saveProduct(
      isEditing: _isEditing, editingProductId: _editingProductId,
      payload: payload, unitPrices: parsedUnitPrices, defaultUnitPriceId: defaultUnit,
    );

    if (result['success']) {
      if (mounted) { _snack('تم حفظ المنتج بنجاح', AppColors.success); Navigator.pop(context, true); }
    } else {
      _snack('خطأ أثناء الحفظ: ${result['error']}', AppColors.error);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon, Color? color}) {
    final themeColor = color ?? _accentColor;
    return InputDecoration(
      labelText: label, prefixIcon: Icon(icon, color: themeColor, size: 20), suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: themeColor, width: 1.5)),
      filled: true, fillColor: _inputFill, labelStyle: TextStyle(color: _textSub, fontSize: 13), hintStyle: TextStyle(color: _textHint, fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductProvider);
    final notifier = ref.read(addProductProvider.notifier);

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: _dark ? AppColors.navyMedium : AppColors.navy, foregroundColor: AppColors.primary, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: _accentColor, shape: BoxShape.circle)), const SizedBox(width: 8),
          Text(_isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, _accentColor.withOpacity(0.6), AppColors.navy])))),
      ),
      body: state.isLoading && state.groups.isEmpty
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_accentColor)))
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildSectionCard(title: 'التصنيف والمجموعات', icon: Icons.category_rounded, children: [
              _buildGroupSelector(state, notifier),
              if (state.selectedGroupId != null) ...[const SizedBox(height: 16), _buildCategorySelector(state, notifier)],
              if (state.selectedCategoryId != null) ...[const SizedBox(height: 16), _buildSubcategorySelector(state, notifier)],
            ]),
            const SizedBox(height: 14),

            _buildSectionCard(title: 'بيانات المنتج الأساسية', icon: Icons.inventory_2_rounded, children: [
              TextFormField(controller: _nameController, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('اسم المنتج *', Icons.drive_file_rename_outline), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(controller: _barcodeController, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('الباركود', Icons.qr_code_rounded))),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: _accentColor),
                  onPressed: () async {
                    var status = await Permission.camera.request();
                    if (status.isGranted && mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BarcodeScannerScreen(
                          searchInDatabase: false, // يمنع البحث في قاعدة البيانات
                          onBarcodeScanned: (b) {
                            // 🚀 تم إزالة Navigator.pop من هنا لتجنب الخروج المزدوج
                            setState(() {
                              _barcodeController.text = b; // تعبئة الحقل بالرقم فوراً
                            });
                          }
                      )));
                    } else {
                      // ✅ تم استبدال Get.snackbar بالدالة المحلية الآمنة _snack
                      _snack('يرجى السماح بالوصول للكاميرا في إعدادات التطبيق', AppColors.warning);
                    }
                  },
                ),
              ]),
            ]),
            const SizedBox(height: 14),
            _buildPricingStockSection(state, notifier),
            const SizedBox(height: 14),
            _buildExpandableUnitPricesSection(state, notifier),
            const SizedBox(height: 14),

            _buildSectionCard(title: 'معلومات إضافية', icon: Icons.more_horiz_rounded, children: [
              DropdownButtonFormField<int>(
                isExpanded: true, value: state.selectedWarehouseId, dropdownColor: _cardBg, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('المستودع', Icons.warehouse_rounded),
                items: [DropdownMenuItem<int>(value: null, child: Text('بدون مستودع (المخزن العام)', style: TextStyle(color: _textSub))), ...state.warehouses.map((w) => DropdownMenuItem<int>(value: (w['id'] as num).toInt(), child: Text(w['name'])))],
                onChanged: (v) => notifier.setWarehouse(v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                isExpanded: true, value: state.selectedSupplierId, dropdownColor: _cardBg, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('المورد', Icons.business_rounded),
                items: [DropdownMenuItem<int>(value: null, child: Text('بدون مورد', style: TextStyle(color: _textSub))), ...state.suppliers.map((s) => DropdownMenuItem<int>(value: (s['id'] as num).toInt(), child: Text(s['name'])))],
                onChanged: (v) => notifier.setSupplier(v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiryDateController, readOnly: true, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('تاريخ الانتهاء', Icons.calendar_month_rounded),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: state.selectedExpiryDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
                  if (picked != null) { notifier.setExpiryDate(picked); _expiryDateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}'; }
                },
              ),
            ]),
            const SizedBox(height: 14),
            _buildBonusSectionCard(state, notifier),
            const SizedBox(height: 24),
            _buildBottomActionButtons(state),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _buildGroupSelector(AddProductState state, AddProductNotifier notifier) {
    if (state.isAddingNewGroup) {
      return Row(children: [
        Expanded(child: TextField(controller: _newGroupController, autofocus: true, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('اسم المجموعة الجديدة', Icons.add_box_rounded))),
        IconButton(icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28), onPressed: () async {
          if (_newGroupController.text.trim().isNotEmpty) { await notifier.addNewGroup(_newGroupController.text.trim()); _newGroupController.clear(); }
        }),
        IconButton(icon: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 28), onPressed: () => notifier.toggleNewGroup(false)),
      ]);
    }
    return SearchableDropdownField<int>(
      value: state.selectedGroupId,
      items: state.groups.map((g) => (g['id'] as num).toInt()).toList(),
      itemLabel: (id) => state.groups.firstWhere((g) => (g['id'] as num).toInt() == id, orElse: () => {'name': ''})['name']?.toString() ?? '',
      onChanged: (v) { if (v != null) notifier.loadCategories(v); },
      label: 'المجموعة',
      prefixIcon: Icons.grid_view_rounded,
      suffixIcon: IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: _accentColor), onPressed: () => notifier.toggleNewGroup(true)),
    );
  }

  Widget _buildCategorySelector(AddProductState state, AddProductNotifier notifier) {
    return SearchableDropdownField<int>(
      value: state.selectedCategoryId,
      items: state.categories.map((c) => (c['id'] as num).toInt()).toList(),
      itemLabel: (id) => state.categories.firstWhere((c) => (c['id'] as num).toInt() == id, orElse: () => {'name': ''})['name']?.toString() ?? '',
      onChanged: (v) { if (v != null) notifier.loadSubcategories(v); },
      label: 'الفئة',
      prefixIcon: Icons.category_outlined,
      suffixIcon: IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: _accentColor), onPressed: () async {
        final name = await _showTextInputDialog('إضافة فئة جديدة', 'اسم الفئة');
        if (name != null && name.trim().isNotEmpty) await notifier.addNewCategory(name.trim(), state.selectedGroupId!);
      }),
    );
  }

  Widget _buildSubcategorySelector(AddProductState state, AddProductNotifier notifier) {
    return SearchableDropdownField<int>(
      value: state.selectedSubcategoryId,
      items: state.subcategories.map((s) => (s['id'] as num).toInt()).toList(),
      itemLabel: (id) => state.subcategories.firstWhere((s) => (s['id'] as num).toInt() == id, orElse: () => {'name': ''})['name']?.toString() ?? '',
      onChanged: (v) { if (v != null) notifier.setSubcategory(v); },
      label: 'الصنف الفرعي',
      prefixIcon: Icons.account_tree_outlined,
      suffixIcon: IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: _accentColor), onPressed: () async {
        final name = await _showTextInputDialog('إضافة صنف جديد', 'اسم الصنف');
        if (name != null && name.trim().isNotEmpty) await notifier.addNewSubcategory(name.trim(), state.selectedCategoryId!);
      }),
    );
  }

  Widget _buildPricingStockSection(AddProductState state, AddProductNotifier notifier) {
    return _buildSectionCard(title: 'الأسعار والمخزون', icon: Icons.account_balance_wallet_rounded, children: [
      TextFormField(controller: _costPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('سعر التكلفة (الشراء)', Icons.shopping_cart_outlined, color: Colors.orange), onChanged: (_) => _calculateSellingPrice()),
      const SizedBox(height: 20),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نسبة الربح %', style: TextStyle(fontSize: 13, color: _textSub, fontWeight: FontWeight.w500)), const SizedBox(height: 8),
        TextFormField(controller: _profitPercentController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary), decoration: InputDecoration(suffixText: '%', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cardBorder)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), filled: true, fillColor: _inputFill), onChanged: (_) => _calculateSellingPrice()),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [_buildQuickPercentButton(10), _buildQuickPercentButton(15), _buildQuickPercentButton(20), _buildQuickPercentButton(25)]),
        const SizedBox(height: 16),
        Text('سعر البيع', style: TextStyle(fontSize: 13, color: _textSub, fontWeight: FontWeight.w500)), const SizedBox(height: 8),
        TextFormField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.success), decoration: InputDecoration(suffixText: 'ريال', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cardBorder)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), filled: true, fillColor: _inputFill), onChanged: (_) => _calculateProfitFromSellingPrice(), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
        const SizedBox(height: 6),
        Text('الربح: ${_profitAmount.toStringAsFixed(2)} ريال', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: TextFormField(controller: _stockController, keyboardType: TextInputType.number, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('الكمية *', Icons.exposure), validator: (v) { if (v == null || v.isEmpty) return 'مطلوب'; if (int.tryParse(v) == null || int.parse(v) < 0) return 'قيمة غير صالحة'; return null; })), const SizedBox(width: 14),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: state.selectedUnitId,
            dropdownColor: _cardBg,
            style: TextStyle(color: _textMain, fontSize: 14),
            decoration: _inputDecoration('الوحدة', Icons.straighten_rounded),
            items: state.units.map((u) => DropdownMenuItem<int>(
              value: (u['id'] as num).toInt(),
              child: Text(u['name']),
            )).toList(),
            onChanged: (v) => notifier.setUnit(v),
          ),
        ),      ]),
      const SizedBox(height: 16),
      TextFormField(controller: _minStockController, keyboardType: TextInputType.number, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('حد التنبيه (الحد الأدنى)', Icons.notification_important_outlined), validator: (v) { if (v == null || v.isEmpty) return 'مطلوب'; if (int.tryParse(v) == null || int.parse(v) < 0) return 'قيمة غير صالحة'; return null; }),
    ]);
  }

  Widget _buildQuickPercentButton(double percent) {
    final isSelected = _profitPercentage == percent;
    return InkWell(
      onTap: () { setState(() { _profitPercentage = percent; _profitPercentController.text = percent.toInt().toString(); _calculateSellingPrice(); }); },
      borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${percent.toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? AppColors.navy : AppColors.primary))),
    );
  }

  Widget _buildExpandableUnitPricesSection(AddProductState state, AddProductNotifier notifier) {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => notifier.toggleUnitPrices(), borderRadius: BorderRadius.circular(16),
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.price_change_rounded, color: AppColors.primary, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الأسعار حسب الوحدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textMain)), Text('إضافة أسعار مختلفة لكل وحدة قياس', style: TextStyle(fontSize: 11, color: _textSub))])), Icon(state.showUnitPrices ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _textSub)])),
        ),
        if (state.showUnitPrices)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: state.units.map((unit) {
                final uid = (unit['id'] as num).toInt();
                if (!_unitPriceControllers.containsKey(uid)) return const SizedBox.shrink();
                final ctrl = _unitPriceControllers[uid]!;
                final isDef = _isDefaultUnit[uid] ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    SizedBox(width: 90, child: Text('${unit['name']} ${(unit['symbol'] ?? '').isNotEmpty ? '(${unit['symbol']})' : ''}', style: TextStyle(fontWeight: FontWeight.w500, color: _textMain, fontSize: 13))), const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: ctrl, style: TextStyle(color: _textMain, fontSize: 14), decoration: InputDecoration(hintText: 'سعر الوحدة', hintStyle: TextStyle(color: _textHint, fontSize: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _cardBorder)), prefixIcon: const Icon(Icons.attach_money_rounded, size: 18, color: _accentColor), suffixText: 'ريال', filled: true, fillColor: _inputFill), keyboardType: TextInputType.number)),
                    IconButton(icon: Icon(isDef ? Icons.star_rounded : Icons.star_border_rounded, color: isDef ? AppColors.primary : _textHint), onPressed: () { setState(() { for (var k in _isDefaultUnit.keys) { _isDefaultUnit[k] = false; } _isDefaultUnit[uid] = true; }); }, tooltip: 'تعيين كسعر افتراضي'),
                  ]),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _buildBonusSectionCard(AddProductState state, AddProductNotifier notifier) {
    return _buildSectionCard(title: 'إعدادات البونص', icon: Icons.card_giftcard, children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('تفعيل البونص لهذا المنتج', style: TextStyle(color: _textMain, fontSize: 14)), subtitle: Text(state.isBonusEnabled ? 'سيظهر تلميح في شاشة البيع' : 'لا يوجد بونص', style: TextStyle(color: _textSub, fontSize: 12)), value: state.isBonusEnabled, activeColor: AppColors.primary, onChanged: (val) => notifier.toggleBonus(val)),
      if (state.isBonusEnabled) ...[
        const SizedBox(height: 12),
        TextFormField(controller: _bonusRequiredQtyController, keyboardType: TextInputType.number, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('الكمية المطلوب شراؤها', Icons.shopping_cart_checkout), validator: (v) { if (v == null || v.isEmpty) return 'مطلوب'; if (int.tryParse(v) == null || int.parse(v) < 0) return 'أدخل كمية صحيحة'; return null; }),
        const SizedBox(height: 12),
        SearchableDropdownField<int?>(
          value: state.selectedBonusFreeProductId,
          items: state.allProducts.map((p) => (p['id'] as num).toInt() as int?).toList(),
          itemLabel: (id) {
            if (id == null) return '';
            return state.allProducts.firstWhere((p) => (p['id'] as num).toInt() == id, orElse: () => {'name': ''})['name']?.toString() ?? '';
          },
          onChanged: (v) => notifier.setBonusProduct(v),
          label: 'المنتج المجاني',
          prefixIcon: Icons.redeem,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _bonusFreeQtyController, keyboardType: TextInputType.number, style: TextStyle(color: _textMain, fontSize: 14), decoration: _inputDecoration('الكمية المجانية', Icons.confirmation_number), validator: (v) { if (v == null || v.isEmpty) return 'مطلوب'; if (int.tryParse(v) == null || int.parse(v) < 0) return 'أدخل كمية صحيحة'; return null; }),
      ],
    ]);
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary, size: 20)), const SizedBox(width: 12), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textMain))]), Divider(height: 24, color: _cardBorder), ...children]),
    );
  }

  Widget _buildBottomActionButtons(AddProductState state) {
    return Container(
      width: double.infinity, decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)), padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: _textSub, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: _cardBorder)), child: Text('إلغاء', style: TextStyle(color: _textSub)))), const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton.icon(onPressed: state.isLoading ? null : _handleSave, icon: state.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.navy, strokeWidth: 2)) : Icon(_isEditing ? Icons.save_rounded : Icons.check_rounded, size: 18), label: Text(_isEditing ? 'تحديث المنتج' : 'حفظ المنتج', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.navy, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      ]),
    );
  }
}