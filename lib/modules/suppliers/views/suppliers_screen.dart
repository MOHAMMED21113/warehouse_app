// lib/modules/suppliers/views/suppliers_screen.dart
// 🆕 تصميم كحلي + ذهبي — محول إلى Riverpod مع AppThemeColors
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../database/database_helper.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  Timer? _debounceTimer;
  String? _errorMessage;
  Map<String, dynamic>? _lastDeletedSupplier;
  Timer? _undoTimer;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final int _limit = 20;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterSuppliers);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreSuppliers();
    }
  }

  Future<void> _loadMoreSuppliers() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    final db = ref.read(databaseHelperProvider);
    final newSuppliers = await db.getSuppliersPaginated(
      page: _currentPage,
      limit: _limit,
    );
    if (newSuppliers.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _suppliers.addAll(newSuppliers);
        _filteredSuppliers = List.from(_suppliers);
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _currentPage = 1;
    _hasMore = true;
    try {
      final db = ref.read(databaseHelperProvider);
      final suppliers =
          await db.getSuppliersPaginated(page: 1, limit: _limit);
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = List.from(suppliers);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل تحميل بيانات الموردين: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: _loadSuppliers,
          ),
        ),
      );
    }
  }

  void _filterSuppliers() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final query = _searchController.text.trim().toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _filteredSuppliers = List.from(_suppliers);
        } else {
          _filteredSuppliers = _suppliers
              .where((s) =>
                  (s['name'] ?? '').toLowerCase().contains(query) ||
                  (s['phone'] ?? '').toLowerCase().contains(query) ||
                  (s['address'] ?? '').toLowerCase().contains(query))
              .toList();
        }
      });
    });
  }

  // ==================== حوار إضافة / تعديل ====================
  Future<void> _showAddEditDialog({Map<String, dynamic>? supplier}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddSupplierSheet(
        supplier: supplier,
        colors: _colors,
        onSaved: _loadSuppliers,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> supplier) async {
    final colors = _colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            Text('حذف المورد',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textMain)),
            const SizedBox(height: 8),
            Text(
              'هل أنت متأكد من حذف "${supplier['name']}"؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textSub),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
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
                    final deletedItem = Map<String, dynamic>.from(supplier);
                    _lastDeletedSupplier = deletedItem;

                    final dbClient = await db.database;
                    await dbClient.transaction((txn) async {
                      await txn.delete('suppliers', where: 'id = ?', whereArgs: [supplier['id']]);
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadSuppliers();

                    _undoTimer?.cancel();
                    _undoTimer = Timer(const Duration(seconds: 5), () {
                      _lastDeletedSupplier = null;
                    });

                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حذف المورد "${deletedItem['name']}"'),
                        duration: const Duration(seconds: 5),
                        backgroundColor: AppColors.navy,
                        action: SnackBarAction(
                          label: 'تراجع',
                          textColor: AppColors.primary,
                          onPressed: () async {
                            _undoTimer?.cancel();
                            if (_lastDeletedSupplier != null) {
                              await db.insertSupplier(_lastDeletedSupplier!);
                              _lastDeletedSupplier = null;
                              if (mounted) _loadSuppliers();
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

  // ==================== بناء الواجهة ====================
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
                color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('الموردين',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
        actions: [
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
                AppColors.success.withValues(alpha: 0.6),
                AppColors.navy,
              ]),
            ),
          ),
        ),
      ),
      body: _buildBody(colors),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
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
            onPressed: _loadSuppliers,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
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
            valueColor:
                AlwaysStoppedAnimation<Color>(AppColors.success)),
      );
    }

    if (_errorMessage != null && _suppliers.isEmpty) {
      return _showErrorWidget(colors);
    }

    return Column(children: [
      if (_showSearch)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: colors.scaffoldBg == AppColors.navy
              ? AppColors.navyMedium.withValues(alpha: 0.5)
              : AppColors.success.withValues(alpha: 0.05),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: colors.textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'بحث باسم المورد أو الهاتف...',
              hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: colors.textHint, size: 20),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear_rounded,
                    color: colors.textHint, size: 18),
                onPressed: () => _searchController.clear(),
              ),
              filled: true,
              fillColor: colors.inputFill,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.success, width: 1.5),
              ),
            ),
          ),
        ),
      Expanded(
        child: _suppliers.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_rounded,
                  size: 60, color: colors.textHint),
              const SizedBox(height: 16),
              Text('لا توجد موردين',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain)),
              const SizedBox(height: 4),
              Text('اضغط على زر + لإضافة مورد',
                  style: TextStyle(
                      fontSize: 12, color: colors.textHint)),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadSuppliers,
          color: AppColors.success,
          child: _filteredSuppliers.isEmpty
              ? ListView(children: [
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text('لا توجد نتائج',
                    style: TextStyle(color: colors.textSub)),
              ),
            ),
          ])
              : FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _filteredSuppliers.length + 1,
              itemBuilder: (context, index) {
                if (index == _filteredSuppliers.length) {
                  return _isLoadingMore
                      ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                        child: CircularProgressIndicator(
                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                                AppColors.success))),
                  )
                      : const SizedBox.shrink();
                }
                return _buildSupplierCard(
                    index, colors, _filteredSuppliers[index]);
              },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSupplierCard(
      int index, AppThemeColors colors, Map<String, dynamic> supplier) {
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyMedium],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.success.withOpacity(0.3)),
          ),
          child: const Center(
            child: Icon(Icons.business_rounded,
                color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(supplier['name'] ?? '',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (supplier['phone'] != null &&
                  supplier['phone'].toString().isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.phone_rounded,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(supplier['phone'],
                      style: TextStyle(
                          fontSize: 12, color: colors.textSub)),
                ]),
              ],
              if (supplier['address'] != null &&
                  supplier['address'].toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_rounded,
                      size: 13, color: colors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(supplier['address'],
                        style: TextStyle(
                            fontSize: 11, color: colors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit_rounded,
              color: AppColors.primary.withOpacity(0.7), size: 18),
          onPressed: () => _showAddEditDialog(supplier: supplier),
          tooltip: 'تعديل',
          constraints:
          const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: AppColors.error.withOpacity(0.7), size: 18),
          onPressed: () => _confirmDelete(supplier),
          tooltip: 'حذف',
          constraints:
          const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text, AppThemeColors colors) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.textMain,
            fontSize: 13));
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    required AppThemeColors colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: colors.textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.success, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _AddSupplierSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? supplier;
  final dynamic colors;
  final VoidCallback onSaved;

  const _AddSupplierSheet({
    Key? key,
    this.supplier,
    required this.colors,
    required this.onSaved,
  }) : super(key: key);

  @override
  ConsumerState<_AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends ConsumerState<_AddSupplierSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?['name']);
    _phoneController = TextEditingController(text: widget.supplier?['phone']);
    _addressController = TextEditingController(text: widget.supplier?['address']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;
    final colors = widget.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.cardBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.navy, AppColors.navyMedium],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'تعديل مورد' : 'إضافة مورد جديد',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            isEditing ? 'تحديث بيانات المورد' : 'أدخل معلومات المورد الجديد',
                            style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  _fieldLabel('اسم المورد', colors),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _nameController,
                    hint: 'مثال: شركة التوريدات المتحدة',
                    icon: Icons.business_rounded,
                    colors: colors,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('رقم الهاتف / التواصل', colors),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _phoneController,
                    hint: 'مثال: 0512345678',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    colors: colors,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('العنوان', colors),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _addressController,
                    hint: 'عنوان المورد',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                    colors: colors,
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textSub,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: colors.cardBorder),
                        ),
                        child: Text('إلغاء', style: TextStyle(color: colors.textSub)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('يرجى إدخال اسم المورد'),
                                backgroundColor: AppColors.warning.withOpacity(0.95),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          final db = ref.read(databaseHelperProvider);
                          if (isEditing) {
                            await db.updateSupplier(widget.supplier!['id'], {
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'address': _addressController.text.trim(),
                            });
                          } else {
                            await db.insertSupplier({
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'address': _addressController.text.trim(),
                            });
                          }
                          Navigator.pop(context);
                          widget.onSaved();
                        },
                        icon: Icon(isEditing ? Icons.save_rounded : Icons.person_add_rounded, size: 18),
                        label: Text(isEditing ? 'تحديث' : 'إضافة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.navy,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fieldLabel(String label, dynamic colors) {
    return Text(
      label,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textMain),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required dynamic colors,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: colors.textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.success, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}