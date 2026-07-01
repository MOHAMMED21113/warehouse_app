// lib/modules/subcategories/views/subcategory_details_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/subcategory_details_provider.dart'; // 🚀 استيراد المزود الجديد

class SubcategoryDetailsScreen extends ConsumerStatefulWidget {
  final int subcategoryId;
  final String subcategoryName;

  const SubcategoryDetailsScreen({
    super.key,
    required this.subcategoryId,
    required this.subcategoryName,
  });

  @override
  ConsumerState<SubcategoryDetailsScreen> createState() => _SubcategoryDetailsScreenState();
}

class _SubcategoryDetailsScreenState extends ConsumerState<SubcategoryDetailsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppThemeColors get _colors => AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    // 🚀 لا يوجد loadProducts هنا، Riverpod يتكفل بذلك
    _searchController.addListener(() => setState(() {})); // إعادة البناء فقط لتطبيق الفلترة المحلية
    _animationController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== التصدير إلى Excel ====================
  // 🚀 نمرر القائمة المفلترة مباشرة كـ Parameter لتجنب استخدام متغيرات عامة
  Future<void> _exportToExcel(List<Map<String, dynamic>> productsToExport) async {
    if (productsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لا توجد بيانات للتصدير'),
          backgroundColor: AppColors.warning.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    var excel = Excel.createExcel();
    var sheet = excel[widget.subcategoryName];

    sheet.appendRow([
      TextCellValue('المنتج'), TextCellValue('الباركود'),
      TextCellValue('السعر'), TextCellValue('العملة'),
      TextCellValue('الوحدة'), TextCellValue('الكمية'),
      TextCellValue('الحد الأدنى'), TextCellValue('تاريخ الصلاحية'),
    ]);

    for (var product in productsToExport) {
      final currencySymbol = product['currency_symbol']?.toString() ?? product['currency_code']?.toString() ?? 'ريال';
      sheet.appendRow([
        TextCellValue(product['name']?.toString() ?? ''),
        TextCellValue(product['barcode']?.toString() ?? ''),
        DoubleCellValue((product['unit_price'] ?? 0).toDouble()),
        TextCellValue(currencySymbol),
        TextCellValue(product['unit_symbol']?.toString() ?? product['unit_name']?.toString() ?? ''),
        IntCellValue(product['current_stock'] ?? 0),
        IntCellValue(product['min_stock'] ?? 0),
        TextCellValue(product['expiry_date']?.toString().substring(0, 10) ?? ''),
      ]);
    }

    final List<int>? excelBytes = excel.encode();
    if (excelBytes != null) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير ${widget.subcategoryName}',
        fileName: '${widget.subcategoryName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
        bytes: Uint8List.fromList(excelBytes),
      );
      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ التقرير بنجاح'),
            backgroundColor: AppColors.success.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    // 🚀 الاستماع للحالة بشكل تفاعلي
    final asyncProducts = ref.watch(subcategoryProductsProvider(widget.subcategoryId));

    // 🚀 فلترة البيانات محلياً داخل الواجهة بناءً على حالة البحث (دون الحاجة لمتغيرات State إضافية)
    List<Map<String, dynamic>> filteredList = [];
    asyncProducts.whenData((products) {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        filteredList = products;
      } else {
        filteredList = products.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final barcode = (p['barcode'] ?? '').toString().toLowerCase();
          return name.contains(query) || barcode.contains(query);
        }).toList();
      }
    });

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg, foregroundColor: colors.appBarFg, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.of(context).pop()),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(widget.subcategoryName, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
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
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            onPressed: () => _exportToExcel(filteredList), // 🚀 إرسال القائمة المفلترة مباشرة
            tooltip: 'تصدير إلى Excel',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.warning.withOpacity(0.6), AppColors.navy]))),
        ),
      ),
      body: Column(
        children: [
          if (_showSearch)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: colors.scaffoldBg == AppColors.navy ? AppColors.navyMedium.withOpacity(0.5) : AppColors.warning.withOpacity(0.05),
              child: TextField(
                controller: _searchController, autofocus: true,
                style: TextStyle(color: colors.textMain, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'بحث عن منتج...', hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: colors.textHint, size: 20),
                  suffixIcon: IconButton(icon: Icon(Icons.clear_rounded, color: colors.textHint, size: 18), onPressed: () => _searchController.clear()),
                  filled: true, fillColor: colors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.warning, width: 1.5)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Text('المنتجات (${filteredList.length})', style: TextStyle(fontSize: 13, color: colors.textSub)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), borderRadius: BorderRadius.circular(20)),
                child: Text('${filteredList.length}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(
            child: asyncProducts.when(
              loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning))),
              error: (err, stack) => Center(child: Text('حدث خطأ: $err', style: const TextStyle(color: AppColors.error))),
              data: (products) {
                if (filteredList.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_rounded, size: 60, color: colors.textHint),
                            const SizedBox(height: 16),
                            Text('لا توجد منتجات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textMain)),
                          ]
                      )
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.read(subcategoryProductsProvider(widget.subcategoryId).notifier).refresh(),
                  color: AppColors.warning,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) => _buildProductCard(filteredList[index], colors),
                    ),
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
    final unitSymbol = product['unit_symbol']?.toString() ?? '';
    final unitName = product['unit_name']?.toString() ?? '';
    final unitText = unitSymbol.isNotEmpty ? unitSymbol : unitName;
    final currencySymbol = product['currency_symbol']?.toString() ?? product['currency_code']?.toString() ?? 'ريال';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Center(child: Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                product['name']?.toString() ?? 'بدون اسم',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textMain),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _buildInfoChip(label: 'السعر', value: '${product['unit_price'] ?? 0} $currencySymbol', color: AppColors.info, colors: colors),
              if (unitText.isNotEmpty) _buildInfoChip(label: 'الوحدة', value: unitText, color: AppColors.secondary, colors: colors),
              _buildInfoChip(label: 'الكمية', value: '${product['current_stock'] ?? 0}', color: AppColors.warning, colors: colors),
              _buildInfoChip(label: 'الحد الأدنى', value: '${product['min_stock'] ?? 0}', color: AppColors.info, colors: colors),
            ],
          ),
          if (product['expiry_date'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: colors.textHint),
                const SizedBox(width: 6),
                Text('تاريخ الصلاحية: ${product['expiry_date'].toString().substring(0, 10)}', style: TextStyle(fontSize: 11, color: colors.textHint)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required String label, required String value, required Color color, required AppThemeColors colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(colors.scaffoldBg == AppColors.navy ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          const SizedBox(width: 3),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}