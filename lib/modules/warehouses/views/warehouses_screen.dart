// lib/modules/warehouses/views/warehouses_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/warehouses_provider.dart'; // 🚀 استيراد المزود
import 'warehouse_products_screen.dart';

class WarehousesScreen extends ConsumerStatefulWidget {
  const WarehousesScreen({super.key});

  @override
  ConsumerState<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends ConsumerState<WarehousesScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppThemeColors get _colors => AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {})); // التحديث لتفعيل الفلترة المحلية
    _animationController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== حوار إضافة / تعديل ====================
  void _showAddEditDialog({Map<String, dynamic>? warehouse}) {
    final isEditing = warehouse != null;
    final nameController = TextEditingController(text: warehouse?['name']);
    final locationController = TextEditingController(text: warehouse?['location']);
    final managerController = TextEditingController(text: warehouse?['manager']);
    final phoneController = TextEditingController(text: warehouse?['phone']);
    final colors = _colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.cardBorder, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isEditing ? Icons.edit_rounded : Icons.add_business_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEditing ? 'تعديل مستودع' : 'إضافة مستودع جديد', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(isEditing ? 'تحديث بيانات المستودع' : 'أدخل معلومات المستودع الجديد', style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _fieldLabel('اسم المستودع', colors),
              const SizedBox(height: 6),
              _buildInputField(controller: nameController, hint: 'مثال: المستودع الرئيسي', icon: Icons.warehouse_rounded, colors: colors),
              const SizedBox(height: 16),
              _fieldLabel('الموقع', colors),
              const SizedBox(height: 6),
              _buildInputField(controller: locationController, hint: 'المنطقة - المدينة - العنوان', icon: Icons.location_on_rounded, colors: colors),
              const SizedBox(height: 16),
              _fieldLabel('المسؤول', colors),
              const SizedBox(height: 6),
              _buildInputField(controller: managerController, hint: 'اسم الشخص المسؤول', icon: Icons.person_rounded, colors: colors),
              const SizedBox(height: 16),
              _fieldLabel('رقم الهاتف', colors),
              const SizedBox(height: 6),
              _buildInputField(controller: phoneController, hint: 'رقم التواصل', icon: Icons.phone_rounded, keyboardType: TextInputType.phone, colors: colors),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: colors.textSub, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: colors.cardBorder)),
                      child: Text('إلغاء', style: TextStyle(color: colors.textSub)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('يرجى إدخال اسم المستودع'), backgroundColor: AppColors.warning.withOpacity(0.9)));
                          return;
                        }

                        // 🚀 توجيه الأوامر للـ Provider النظيف بدلاً من قاعدة البيانات المباشرة
                        final notifier = ref.read(warehousesProvider.notifier);
                        final data = {
                          'name': nameController.text.trim(),
                          'location': locationController.text.trim(),
                          'manager': managerController.text.trim(),
                          'phone': phoneController.text.trim(),
                        };

                        if (isEditing) {
                          await notifier.updateWarehouse(warehouse!['id'], data);
                        } else {
                          await notifier.addWarehouse(data);
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'تم تعديل المستودع بنجاح' : 'تم إضافة المستودع بنجاح'), backgroundColor: AppColors.success.withOpacity(0.9)));
                        }
                      },
                      icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 18),
                      label: Text(isEditing ? 'تحديث' : 'إضافة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.navy, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== حوار نقل المنتجات ====================
  Future<void> _showTransferDialog(Map<String, dynamic> fromWarehouse) async {
    final db = ref.read(databaseHelperProvider);
    final productsWithStock = await db.getProductsWithStockForWarehouse(fromWarehouse['id']);
    final warehouses = await db.getAllWarehouses();
    final colors = _colors;

    int? selectedProductId;
    int? selectedToWarehouseId;
    final quantityController = TextEditingController();
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredProducts = List.from(productsWithStock);
    int maxQuantity = 0;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(color: colors.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.cardBorder, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('نقل المنتجات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), Text('المستودع الحالي: ${fromWarehouse['name']}', style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8)))]))
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'بحث باسم المنتج أو الباركود...',
                        hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                        filled: true, fillColor: colors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                      onChanged: (v) {
                        final query = v.trim().toLowerCase();
                        setDialogState(() {
                          filteredProducts = query.isEmpty
                              ? productsWithStock
                              : productsWithStock.where((p) => (p['name'] ?? '').toLowerCase().contains(query) || (p['barcode'] ?? '').toLowerCase().contains(query)).toList();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 60, color: colors.textHint), const SizedBox(height: 10), Text('لا توجد منتجات', style: TextStyle(fontSize: 14, color: colors.textSub))]))
                    : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _fieldLabel('اختر المنتج', colors),
                    const SizedBox(height: 10),
                    ...filteredProducts.map((p) {
                      final isSelected = selectedProductId == p['id'];
                      final stock = (p['current_stock'] as num).toInt();
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: isSelected ? AppColors.primary.withOpacity(0.08) : colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? AppColors.primary : colors.cardBorder, width: isSelected ? 1.5 : 1)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: isSelected ? const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]) : null, color: isSelected ? null : colors.inputFill, borderRadius: BorderRadius.circular(12), border: isSelected ? null : Border.all(color: colors.cardBorder)), child: Center(child: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20) : Text('$stock', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textSub, fontSize: 13)))),
                          title: Text(p['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textMain)),
                          subtitle: Text(p['barcode'] ?? 'بدون باركود', style: TextStyle(fontSize: 11, color: colors.textHint)),
                          onTap: () {
                            setDialogState(() {
                              selectedProductId = p['id'];
                              maxQuantity = stock;
                              quantityController.clear();
                            });
                          },
                        ),
                      );
                    }),
                    if (selectedProductId != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تفاصيل النقل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textMain)),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18), const SizedBox(width: 8), Text('الكمية المتاحة: $maxQuantity', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.info, fontSize: 13))]),
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('المستودع الهدف', colors),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
                              child: DropdownButtonFormField<int>(
                                value: selectedToWarehouseId, isExpanded: true, dropdownColor: colors.cardBg,
                                style: TextStyle(color: colors.textMain, fontSize: 14),
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                                hint: Text('اختر المستودع', style: TextStyle(color: colors.textHint)),
                                items: warehouses.where((w) => w['id'] != fromWarehouse['id']).map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name'] ?? ''))).toList(),
                                onChanged: (v) => setDialogState(() => selectedToWarehouseId = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('الكمية', colors),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
                              child: TextField(
                                controller: quantityController, keyboardType: TextInputType.number, style: TextStyle(color: colors.textMain, fontSize: 14),
                                decoration: InputDecoration(hintText: '1 - $maxQuantity', hintStyle: TextStyle(color: colors.textHint, fontSize: 13), prefixIcon: const Icon(Icons.numbers_rounded, color: AppColors.primary, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: colors.textSub, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: colors.cardBorder)), child: Text('إلغاء', style: TextStyle(color: colors.textSub)))),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: (selectedToWarehouseId == null || quantityController.text.isEmpty)
                                        ? null
                                        : () async {
                                      final qty = int.tryParse(quantityController.text) ?? 0;
                                      if (qty <= 0 || qty > maxQuantity) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية يجب أن تكون بين 1 و $maxQuantity'), backgroundColor: AppColors.error));
                                        return;
                                      }
                                      // تنفيذ النقل
                                      final result = await db.transferProductFixed(productId: selectedProductId!, fromWarehouseId: fromWarehouse['id'], toWarehouseId: selectedToWarehouseId!, quantity: qty);

                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['success'] ? 'تم النقل بنجاح' : '${result['error']}'), backgroundColor: result['success'] ? AppColors.success : AppColors.error));
                                      }
                                    },
                                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                                    label: const Text('نقل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.navy, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> warehouse) {
    final colors = _colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: colors.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_forever_rounded, size: 40, color: AppColors.error)),
            const SizedBox(height: 16),
            Text('حذف المستودع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textMain)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من حذف "${warehouse['name']}"؟\nسيتم حذف جميع سجلاته.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.textSub)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: colors.textSub, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: colors.cardBorder)), child: Text('إلغاء', style: TextStyle(color: colors.textSub)))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(warehousesProvider.notifier).deleteWarehouse(warehouse['id']);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف "${warehouse['name']}" بنجاح'), backgroundColor: AppColors.success.withOpacity(0.95)));
                      }
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== بناء الواجهة ====================
  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final asyncWarehouses = ref.watch(warehousesProvider);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.scaffoldBg == AppColors.navy ? AppColors.navyMedium : AppColors.navy,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('إدارة المستودعات', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchController.clear();
              });
            },
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.primary.withOpacity(0.6), AppColors.navy])))),
      ),
      body: _buildBody(colors, asyncWarehouses),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.navy,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 24),
      ),
    );
  }

  Widget _buildBody(AppThemeColors colors, AsyncValue<List<Map<String, dynamic>>> asyncWarehouses) {
    return Column(
      children: [
        if (_showSearch)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: colors.scaffoldBg == AppColors.navy ? AppColors.navyMedium.withOpacity(0.5) : AppColors.primary.withOpacity(0.05),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: colors.textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'بحث باسم المستودع أو الموقع...',
                hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: colors.textHint, size: 20),
                suffixIcon: IconButton(icon: Icon(Icons.clear_rounded, color: colors.textHint, size: 18), onPressed: () => _searchController.clear()),
                filled: true, fillColor: colors.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
        Expanded(
          child: asyncWarehouses.when(
            loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
            error: (err, stack) => Center(child: Text('حدث خطأ: $err', style: const TextStyle(color: AppColors.error))),
            data: (warehouses) {
              final query = _searchController.text.trim().toLowerCase();
              final filteredList = query.isEmpty
                  ? warehouses
                  : warehouses.where((w) {
                final name = (w['name'] ?? '').toString().toLowerCase();
                final location = (w['location'] ?? '').toString().toLowerCase();
                final manager = (w['manager'] ?? '').toString().toLowerCase();
                return name.contains(query) || location.contains(query) || manager.contains(query);
              }).toList();

              if (warehouses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse_rounded, size: 60, color: colors.textHint),
                      const SizedBox(height: 16),
                      Text('لا توجد مستودعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textMain)),
                      const SizedBox(height: 4),
                      Text('اضغط على زر + لإضافة مستودع', style: TextStyle(fontSize: 12, color: colors.textHint)),
                    ],
                  ),
                );
              }

              if (filteredList.isEmpty) {
                return Center(child: Text('لا توجد نتائج', style: TextStyle(color: colors.textSub)));
              }

              return RefreshIndicator(
                onRefresh: () async => ref.refresh(warehousesProvider),
                color: AppColors.primary,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) => _buildWarehouseCard(filteredList[index], colors),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseCard(Map<String, dynamic> warehouse, AppThemeColors colors) {
    final isDefault = warehouse['is_default'] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefault ? AppColors.primary.withOpacity(0.5) : colors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                  child: const Center(child: Icon(Icons.warehouse_rounded, color: AppColors.primary, size: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(warehouse['name'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textMain))),
                          if (isDefault) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5)), child: const Text('افتراضي ⭐', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary))),
                        ],
                      ),
                      if (warehouse['location'] != null && warehouse['location'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [Icon(Icons.location_on_rounded, size: 14, color: colors.textHint), const SizedBox(width: 4), Expanded(child: Text(warehouse['location'], style: TextStyle(fontSize: 12, color: colors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                      ],
                      if (warehouse['manager'] != null && warehouse['manager'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [const Icon(Icons.person_rounded, size: 14, color: AppColors.primary), const SizedBox(width: 4), Text(warehouse['manager'], style: TextStyle(fontSize: 12, color: colors.textSub))]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.cardBorder),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn(Icons.inventory_2_rounded, 'المنتجات', AppColors.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WarehouseProductsScreen(warehouseId: warehouse['id'], warehouseName: warehouse['name'])))),
                _actionBtn(Icons.swap_horiz_rounded, 'نقل المخزون', const Color(0xFF06B6D4), () => _showTransferDialog(warehouse)),
                if (!isDefault)
                  _actionBtn(Icons.star_outline_rounded, 'تعيين افتراضي', const Color(0xFFF59E0B), () async {
                    await ref.read(warehousesProvider.notifier).setDefaultWarehouse(warehouse['id']);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعيين "${warehouse['name']}" كمستودع افتراضي'), backgroundColor: AppColors.success));
                  }),
                _actionBtn(Icons.edit_rounded, 'تعديل', AppColors.primary.withOpacity(0.7), () => _showAddEditDialog(warehouse: warehouse)),
                _actionBtn(Icons.delete_outline_rounded, 'حذف', AppColors.error.withOpacity(0.8), () => _confirmDelete(warehouse)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, AppThemeColors colors) {
    return Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: colors.textMain, fontSize: 13));
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon, int maxLines = 1, TextInputType? keyboardType, required AppThemeColors colors}) {
    return Container(
      decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
      child: TextField(
        controller: controller, maxLines: maxLines, keyboardType: keyboardType, style: TextStyle(color: colors.textMain, fontSize: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: colors.textHint, fontSize: 13), prefixIcon: Icon(icon, color: AppColors.primary, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      ),
    );
  }
}