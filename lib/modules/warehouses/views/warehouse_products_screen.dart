// lib/modules/warehouses/views/warehouse_products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/warehouse_products_provider.dart';

class WarehouseProductsScreen extends ConsumerStatefulWidget {
  final int warehouseId;
  final String warehouseName;

  const WarehouseProductsScreen({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  ConsumerState<WarehouseProductsScreen> createState() => _WarehouseProductsScreenState();
}

class _WarehouseProductsScreenState extends ConsumerState<WarehouseProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTransferDialog(Map<String, dynamic> product) async {
    final db = ref.read(databaseHelperProvider);
    final warehouses = await db.getAllWarehouses();
    final otherWarehouses = warehouses.where((w) => w['id'] != widget.warehouseId).toList();

    if (otherWarehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('لا توجد مستودعات أخرى للنقل إليها'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final quantityController = TextEditingController();
    final colors = _colors;
    final stock = (product['current_stock'] as num).toInt();
    int? selectedToWarehouseId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.cardBorder, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 16),
                Text('نقل: ${product['name']}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textMain)),
                const SizedBox(height: 8),
                Text('الكمية المتاحة: $stock', style: TextStyle(color: colors.textSub, fontSize: 12)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedToWarehouseId,
                  decoration: InputDecoration(
                    labelText: 'المستودع الهدف',
                    filled: true, fillColor: colors.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  dropdownColor: colors.cardBg,
                  style: TextStyle(color: colors.textMain),
                  items: otherWarehouses.map((w) => DropdownMenuItem<int>(value: w['id'], child: Text(w['name']))).toList(),
                  onChanged: (v) => setSheetState(() => selectedToWarehouseId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الكمية',
                    hintText: '1 - $stock',
                    filled: true, fillColor: colors.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: TextStyle(color: colors.textMain),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (selectedToWarehouseId == null || quantityController.text.trim().isEmpty)
                          ? null
                          : () async {
                        final qty = int.tryParse(quantityController.text.trim()) ?? 0;
                        if (qty <= 0 || qty > stock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('الكمية يجب أن تكون بين 1 و $stock'), backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final notifier = ref.read(warehouseProductsProvider(widget.warehouseId).notifier);
                        final result = await notifier.transferProduct(
                          productId: product['id'],
                          fromWarehouseId: widget.warehouseId,
                          toWarehouseId: selectedToWarehouseId!,
                          quantity: qty,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['success'] ? 'تم النقل بنجاح' : '${result['error']}'),
                            backgroundColor: result['success'] ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('نقل'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.navy),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final asyncProducts = ref.watch(warehouseProductsProvider(widget.warehouseId));

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg, foregroundColor: colors.appBarFg, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.of(context).pop()),
        title: Text(widget.warehouseName, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primary),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchController.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'بحث عن منتج...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  filled: true, fillColor: colors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
          Expanded(
            child: asyncProducts.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Center(child: Text('خطأ: $err')),
              data: (products) {
                final query = _searchController.text.trim().toLowerCase();
                final filteredList = query.isEmpty
                    ? products
                    : products.where((p) => (p['name'] ?? '').toLowerCase().contains(query) || (p['barcode'] ?? '').toLowerCase().contains(query)).toList();

                if (filteredList.isEmpty) {
                  return Center(child: Text('لا توجد منتجات في هذا المستودع', style: TextStyle(color: colors.textHint)));
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(warehouseProductsProvider(widget.warehouseId)),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (ctx, i) => _buildProductCard(filteredList[i], colors),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, AppThemeColors colors) {
    final stock = (product['current_stock'] as num).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text('$stock', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: colors.textMain)),
              if (product['barcode'] != null) Text(product['barcode'].toString(), style: TextStyle(fontSize: 11, color: colors.textHint)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('${product['unit_price'] ?? 0} ﷼', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.info),
          onPressed: () => _showTransferDialog(product),
          tooltip: 'نقل لمستودع آخر',
        ),
      ]),
    );
  }
}