// lib/modules/inventory/views/inventory_count_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/inventory_adjustment_printer.dart';

class InventoryCountScreen extends ConsumerStatefulWidget {
  const InventoryCountScreen({super.key});

  @override
  ConsumerState<InventoryCountScreen> createState() => _InventoryCountScreenState();
}

class _InventoryCountScreenState extends ConsumerState<InventoryCountScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _adjustments = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseHelperProvider);
    final prods = await db.getAllProducts();
    final adjs = await db.getInventoryAdjustments();
    if (mounted) {
      setState(() {
        _products = prods;
        _adjustments = adjs;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.trim().isEmpty) return _products;
    final q = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final barcode = (p['barcode'] ?? '').toString().toLowerCase();
      return name.contains(q) || barcode.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسوية المخزون وسجل التوالف (Inventory & Damages)'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'الجرد الفعلي للمنتجات'),
            Tab(icon: Icon(Icons.history_rounded), text: 'سجل التوالف والتسويات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'طباعة تقرير التوالف والتسويات الشامل',
            onPressed: () async {
              if (_adjustments.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد سجلات تسوية أو توالف للطباعة')),
                );
                return;
              }
              await InventoryAdjustmentPrinter.printAdjustmentReport(_adjustments);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildAdjustmentsTab(),
              ],
            ),
    );
  }

  Widget _buildProductsTab() {
    final list = _filteredProducts;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث باسم الصنف أو الباركود لتسهيل الجرد...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'لا توجد نتائج مطابقة لبحثك' : 'لا توجد منتجات مسجلة بالمخزن',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final p = list[index];
                    final sysStock = (p['current_stock'] as num?)?.toDouble() ?? 0.0;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                        ),
                        title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('الرصيد الدفتري الحالي: $sysStock وحدة | الباركود: ${p['barcode'] ?? "N/A"}'),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showAdjustmentDialog(p, sysStock),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('تسوية جرد'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAdjustmentsTab() {
    if (_adjustments.isEmpty) {
      return const Center(
        child: Text('لا توجد عمليات تسوية أو سجل توالف سابقاً', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _adjustments.length,
      itemBuilder: (context, index) {
        final adj = _adjustments[index];
        final diff = (adj['difference'] as num?)?.toDouble() ?? 0.0;
        final isSurplus = diff > 0;
        final isDeficit = diff < 0;
        final color = isSurplus ? AppColors.success : (isDeficit ? AppColors.error : Colors.grey);
        final icon = isSurplus ? Icons.trending_up_rounded : (isDeficit ? Icons.broken_image_rounded : Icons.check_circle_rounded);
        final dateStr = (adj['adjustment_date'] ?? '').toString().split('T').first;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(adj['product_name']?.toString() ?? 'منتج غير معروف', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('السبب: ${adj['reason'] ?? "جرد دوري"} | التاريخ: $dateStr'),
                Text('دفتري: ${adj['system_quantity']} ← فعلي: ${adj['actual_quantity']}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${isSurplus ? "+" : ""}${diff.toStringAsFixed(1)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: AppColors.primary),
                  tooltip: 'طباعة إذن التسوية والتلف',
                  onPressed: () async {
                    await InventoryAdjustmentPrinter.printSingleAdjustment(adj);
                  },
                ),
              ],
            ),
          ),
        );
      },
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
            title: Text('تسوية جرد وتوالف: ${product['name']}'),
            content: SingleChildScrollView(
              child: Column(
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
                      const Text('فرق التسوية (فائض / تلف وعجز):'),
                      Text(
                        '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)}',
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
                    decoration: const InputDecoration(
                      labelText: 'سبب الفروقات (تلف، كسر، فقدان، جرد دوري)',
                      hintText: 'مثال: تلف قطعتين بسبب الرطوبة بالمخزن',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (diff == 0 && reasonController.text.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }
                  final db = ref.read(databaseHelperProvider);
                  final adjId = await db.createInventoryAdjustment({
                    'product_id': product['id'],
                    'system_quantity': sysStock,
                    'actual_quantity': actual,
                    'difference': diff,
                    'reason': reasonController.text.isNotEmpty ? reasonController.text : 'جرد دوري',
                    'adjustment_date': DateTime.now().toIso8601String(),
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadData();
                    _tabController.animateTo(1); // الانتقال تلقائياً لتبويب سجل التوالف
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: const Text('تم حفظ تسوية المخزون! يمكنك الآن طباعة إذن التلف أو التقرير من سجل التسويات.'),
                        backgroundColor: AppColors.success,
                        action: SnackBarAction(
                          label: 'طباعة الإذن',
                          textColor: Colors.white,
                          onPressed: () async {
                            final newAdj = _adjustments.firstWhere((a) => a['id'] == adjId, orElse: () => _adjustments.first);
                            await InventoryAdjustmentPrinter.printSingleAdjustment(newAdj);
                          },
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('حفظ التسوية'),
              ),
            ],
          );
        },
      ),
    );
  }
}
