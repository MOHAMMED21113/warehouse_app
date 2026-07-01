// lib/modules/products/views/product_batches_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/batches_provider.dart';

class ProductBatchesScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;
  const ProductBatchesScreen({super.key, required this.productId, required this.productName});

  @override
  ConsumerState<ProductBatchesScreen> createState() => _ProductBatchesScreenState();
}

class _ProductBatchesScreenState extends ConsumerState<ProductBatchesScreen> {
  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(productBatchesProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(
        title: Text('دفعات وتواريخ صلاحية: ${widget.productName}'),
        centerTitle: true,
      ),
      body: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ في التحميل: $err')),
        data: (batches) {
          if (batches.isEmpty) {
            return const Center(child: Text('لا توجد دفعات مسجلة لهذا المنتج'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(productBatchesProvider(widget.productId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final b = batches[index];
                final rem = (b['remaining_quantity'] as num?)?.toDouble() ?? 0.0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rem > 0 ? AppColors.success : AppColors.error,
                      child: const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                    ),
                    title: Text('رقم التشغيلة: ${b['batch_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('تاريخ الصلاحية: ${b['expiry_date'] ?? 'غير محدد'} | سعر الشراء: ${b['purchase_price']} ﷼'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('الكمية المتبقية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('$rem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: rem > 0 ? AppColors.success : AppColors.error)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBatchDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة دفعة جديدة'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showAddBatchDialog() {
    final batchController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController();
    final expiryController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة دفعة مشتريات (FIFO Batch)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: batchController, decoration: const InputDecoration(labelText: 'رقم التشغيلة (Batch Number)')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'سعر شراء الوحدة (﷼)'), keyboardType: TextInputType.number),
              TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'الكمية المستلمة'), keyboardType: TextInputType.number),
              TextField(controller: expiryController, decoration: const InputDecoration(labelText: 'تاريخ الصلاحية (YYYY-MM-DD)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text) ?? 0.0;
              final price = double.tryParse(priceController.text) ?? 0.0;
              if (qty <= 0 || batchController.text.isEmpty) return;
              final db = ref.read(databaseHelperProvider);
              await db.insertProductBatch({
                'product_id': widget.productId,
                'batch_number': batchController.text,
                'purchase_price': price,
                'quantity': qty,
                'remaining_quantity': qty,
                'expiry_date': expiryController.text.isNotEmpty ? expiryController.text : null,
                'purchase_date': DateTime.now().toIso8601String().substring(0, 10),
              });
              if (mounted) {
                Navigator.pop(context);
                ref.refresh(productBatchesProvider(widget.productId));
              }
            },
            child: const Text('حفظ الدفعة'),
          ),
        ],
      ),
    );
  }
}
