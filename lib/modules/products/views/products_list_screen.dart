// lib/modules/products/views/products_list_screen.dart
// 🆕 تصميم كحلي + ذهبي — محول إلى Riverpod مع AppThemeColors
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/current_user.dart';
import '../../../database/database_helper.dart';
import 'add_product_screen.dart';
import 'barcode_scanner_screen.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 20;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showSearch = false;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _lastDeletedProduct;
  String? _errorMessage;
  Timer? _undoTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _currentPage = 1;
    _hasMore = true;
    try {
      final db = ref.read(databaseHelperProvider);
      final query = _searchController.text.trim();
      final products = await db.getProductsPaginated(
        page: 1, 
        limit: _limit,
        searchQuery: query.isNotEmpty ? query : null,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _filteredProducts = List.from(products);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل تحميل بيانات المنتجات: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: _loadProducts,
          ),
        ),
      );
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    final db = ref.read(databaseHelperProvider);
    final query = _searchController.text.trim();
    final newProducts = await db.getProductsPaginated(
      page: _currentPage, 
      limit: _limit,
      searchQuery: query.isNotEmpty ? query : null,
    );
    if (newProducts.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _products.addAll(newProducts);
        _filteredProducts = List.from(_products);
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadProducts();
    });
  }

  Future<void> _scanBarcode() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى السماح بالوصول للكاميرا'),
          backgroundColor: AppColors.warning.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          onBarcodeScanned: (code) => Navigator.pop(context, code),
        ),
      ),
    );

    if (barcode != null && barcode.trim().isNotEmpty) {
      final db = ref.read(databaseHelperProvider);
      final product = await db.searchProductByAnyBarcode(barcode.trim());
      if (product != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddProductScreen(product: product),
          ),
        );
        _loadProducts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لم يتم العثور على منتج بهذا الباركود'),
            backgroundColor: AppColors.warning.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(int id, String name) async {
    final colors = _colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3), width: 1),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  size: 40, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text('حذف المنتج',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textMain)),
            const SizedBox(height: 8),
            Text(
              'هل أنت متأكد من حذف "$name"؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textSub),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSub,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: colors.cardBorder),
                  ),
                  child: Text('إلغاء',
                      style: TextStyle(color: colors.textSub)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final db = ref.read(databaseHelperProvider);
                    final productToSave = await db.getProductById(id);
                    if (productToSave != null) {
                      _lastDeletedProduct = Map.from(productToSave);
                    }
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    final result = await db.deleteProductSafe(id);
                    if (result['success'] != true) {
                      _lastDeletedProduct = null;
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'].toString()),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    _loadProducts();

                    _undoTimer?.cancel();
                    _undoTimer = Timer(const Duration(seconds: 5), () {
                      _lastDeletedProduct = null;
                    });

                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حذف المنتج "$name"'),
                        duration: const Duration(seconds: 5),
                        backgroundColor: AppColors.navy,
                        action: SnackBarAction(
                          label: 'تراجع',
                          textColor: AppColors.primary,
                          onPressed: () async {
                            _undoTimer?.cancel();
                            if (_lastDeletedProduct != null) {
                              await db.insertProduct(_lastDeletedProduct!);
                              _lastDeletedProduct = null;
                              if (mounted) _loadProducts();
                            }
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('حذف',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveToDamagedDialog(Map<String, dynamic> product) async {
    final qtyController = TextEditingController();
    String selectedReason = 'منتهي الصلاحية';
    final reasons = ['منتهي الصلاحية', 'تالف', 'مكسور', 'مفقود'];
    final colors = _colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                  color: AppColors.warning.withOpacity(0.3), width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded,
                      size: 40, color: AppColors.warning),
                ),
                const SizedBox(height: 16),
                Text('نقل "${product['name']}" للتوالف',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textMain)),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textMain),
                  decoration: InputDecoration(
                    labelText: 'الكمية التالفة / المنتهية',
                    labelStyle: TextStyle(color: colors.textHint),
                    filled: true,
                    fillColor: colors.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: colors.cardBg,
                  style: TextStyle(color: colors.textMain),
                  decoration: InputDecoration(
                    labelText: 'السبب',
                    labelStyle: TextStyle(color: colors.textHint),
                    filled: true,
                    fillColor: colors.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: reasons
                      .map((r) =>
                      DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) =>
                      setSheetState(() => selectedReason = val!),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSub,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final qty = double.tryParse(
                            qtyController.text) ??
                            0.0;
                        final currentStock =
                            (product['current_stock'] as num?)
                                ?.toDouble() ??
                                0.0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'يرجى إدخال كمية صحيحة.'),
                              backgroundColor:
                              AppColors.error,
                              behavior:
                              SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      12)),
                            ),
                          );
                          return;
                        }
                        if (qty > currentStock) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                  'الكمية المدخلة أكبر من المخزون الحالي ($currentStock).'),
                              backgroundColor:
                              AppColors.error,
                              behavior:
                              SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      12)),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                              child:
                              CircularProgressIndicator()),
                        );
                        final db =
                        ref.read(databaseHelperProvider);

                        // ✅ الحصول على المستخدم الحالي من Riverpod
                        final currentUser = ref.read(currentUserProvider);

                        final result = await db
                            .moveProductToDamaged(
                          productId: product['id'],
                          warehouseId: 1,
                          quantity: qty,
                          reason: selectedReason,
                          userId: currentUser?.id,  // ✅ استخدام userId من Riverpod
                        );
                        Navigator.pop(context);
                        if (result['success']) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                  result['message']),
                              backgroundColor:
                              AppColors.success,
                              behavior:
                              SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      12)),
                            ),
                          );
                          _loadProducts();
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                  result['message']),
                              backgroundColor:
                              AppColors.error,
                              behavior:
                              SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      12)),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded,
                          size: 18),
                      label: const Text('تأكيد النقل',
                          style: TextStyle(
                              fontWeight:
                              FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
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
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg,
        foregroundColor: colors.appBarFg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.info, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('المنتجات',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: AppColors.primary),
            onPressed: _scanBarcode,
            tooltip: 'بحث بالباركود',
          ),
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.primary,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchController.clear();
              });
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
                AppColors.info.withOpacity(0.6),
                AppColors.navy,
              ]),
            ),
          ),
        ),
      ),
      body: _buildBody(colors),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddProductScreen()),
          );
          if (result == true) _loadProducts();
        },
        backgroundColor: colors.fabBg,
        foregroundColor: colors.fabFg,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 24),
      ),
    );
  }

  Widget _showErrorWidget(AppThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text('حدث خطأ أثناء تحميل البيانات',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textMain)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage ?? 'خطأ غير معروف',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textHint)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppThemeColors colors) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.info)),
      );
    }

    if (_errorMessage != null && _products.isEmpty) {
      return _showErrorWidget(colors);
    }

    return Column(children: [
      if (_showSearch)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: colors.scaffoldBg == AppColors.navy
              ? AppColors.navyMedium.withValues(alpha: 0.5)
              : AppColors.info.withValues(alpha: 0.05),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: colors.textMain, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'بحث باسم المنتج أو الباركود...',
                  hintStyle:
                  TextStyle(color: colors.textHint, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: colors.textHint, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: colors.textHint, size: 18),
                    onPressed: () => _searchController.clear(),
                  ),
                  filled: true,
                  fillColor: colors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.info, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _scanBarcode,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded,
                    color: AppColors.navy),
              ),
            ),
          ]),
        ),
      Expanded(
        child: _products.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_rounded,
                  size: 60, color: colors.textHint),
              const SizedBox(height: 16),
              Text('لا توجد منتجات',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain)),
              const SizedBox(height: 4),
              Text('اضغط على زر + لإضافة منتج',
                  style: TextStyle(
                      fontSize: 12, color: colors.textHint)),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadProducts,
          color: AppColors.info,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _filteredProducts.length + 1,
            itemBuilder: (context, index) {
              if (index == _filteredProducts.length) {
                return _isLoadingMore
                    ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                        child:
                        CircularProgressIndicator(
                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(AppColors.info))))
                    : const SizedBox.shrink();
              }
              return _buildProductCard(
                  index, colors, _filteredProducts[index]);
            },
          ),
        ),
      ),
    ]);
  }

  Widget _buildProductCard(
      int index, AppThemeColors colors, Map<String, dynamic> product) {
    final unitSymbol = product['unit_symbol']?.toString() ?? '';
    final currencySymbol =
        product['currency_symbol']?.toString() ?? 'ريال';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.navyMedium],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border:
                  Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['name'] ?? 'بدون اسم',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${product['group_name'] ?? ''} → ${product['category_name'] ?? ''} → ${product['subcategory_name'] ?? ''}',
                      style:
                      TextStyle(fontSize: 10, color: colors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildBadge(
                            'بيع: ${product['unit_price'] ?? 0} $currencySymbol',
                            AppColors.info,
                            colors),
                        _buildBadge(
                            'تكلفة: ${(product['cost_price'] ?? 0).toStringAsFixed(2)} $currencySymbol',
                            AppColors.textHint,
                            colors),
                        _buildBadge(
                            'الكمية: ${(product['current_stock'] ?? 0).toInt()} $unitSymbol',
                            AppColors.warning,
                            colors),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: colors.dividerColor),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: Icon(Icons.delete_sweep_rounded,
                    color: AppColors.warning.withOpacity(0.9),
                    size: 18),
                label: Text('توالف',
                    style: TextStyle(
                        color: AppColors.warning.withOpacity(0.9),
                        fontSize: 12)),
                onPressed: () => _showMoveToDamagedDialog(product),
              ),
              TextButton.icon(
                icon: Icon(Icons.edit_rounded,
                    color: AppColors.primary.withOpacity(0.7),
                    size: 18),
                label: Text('تعديل',
                    style: TextStyle(
                        color: AppColors.primary.withOpacity(0.7),
                        fontSize: 12)),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddProductScreen(product: product),
                    ),
                  );
                  if (result == true) _loadProducts();
                },
              ),
              TextButton.icon(
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.error.withOpacity(0.7),
                    size: 18),
                label: Text('حذف',
                    style: TextStyle(
                        color: AppColors.error.withOpacity(0.7),
                        fontSize: 12)),
                onPressed: () => _confirmDelete(
                    product['id'] ?? 0, product['name'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(
            colors.scaffoldBg == AppColors.navy ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}