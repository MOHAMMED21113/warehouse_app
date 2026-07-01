// lib/modules/inventory/views/inventory_count_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';

class InventoryCountScreen extends ConsumerStatefulWidget {
  const InventoryCountScreen({super.key});

  @override
  ConsumerState<InventoryCountScreen> createState() => _InventoryCountScreenState();
}

class _InventoryCountScreenState extends ConsumerState<InventoryCountScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseHelperProvider);
    final prods = await db.getAllProducts();
    if (mounted) {
      setState(() {
        _products = prods;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسوية المخزون والجرد الفعلي (Physical Inventory Count)'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد منتجات مسجلة بالمخزن'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    final sysStock = (p['current_stock'] as num?)?.toDouble() ?? 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('رصيد النظام الحالي: $sysStock وحدة | الباركود: ${p['barcode']}'),
                        trailing: ElevatedButton(
                          onPressed: () => _showAdjustmentDialog(p, sysStock),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          child: const Text('إدخال الجرد الفعلي'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showAdjustmentDialog(Map<String, dynamic> product, double sysStock) {
    final actualController = TextEditingController(text: sysStock.toString());
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final actual = double.tryParse(actualController.text) ?? sysStock;
          final diff = actual - sysStock;

          return AlertDialog(
            title: Text('تسوية جرد: ${product['name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الرصيد الدفتري بالنظام: $sysStock وحدة', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: actualController,
                  decoration: const InputDecoration(labelText: 'الرصيد الفعلي بعد الجرد'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('فرق التسوية (الفائض / العجز):'),
                    Text(
                      '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: diff > 0 ? AppColors.success : (diff < 0 ? AppColors.error : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'سبب الفروقات (تلف، فقدان، جرد دوري)'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (diff == 0) {
                    Navigator.pop(context);
                    return;
                  }
                  final db = ref.read(databaseHelperProvider);
                  await db.createInventoryAdjustment({
                    'product_id': product['id'],
                    'system_quantity': sysStock,
                    'actual_quantity': actual,
                    'difference': diff,
                    'reason': reasonController.text.isNotEmpty ? reasonController.text : 'جرد فعلي',
                    'adjustment_date': DateTime.now().toIso8601String(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _loadProducts();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ تسوية المخزون وتحديث الرصيد بنجاح!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                child: const Text('حفظ التسوية'),
              ),
            ],
          );
        },
      ),
    );
  }
}
