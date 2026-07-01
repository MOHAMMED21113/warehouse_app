// lib/modules/customers/views/customers_screen.dart
// 🆕 تصميم كحلي + ذهبي — محول إلى Riverpod مع AppThemeColors
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../database/database_helper.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  Timer? _debounceTimer;
  String? _errorMessage;
  Map<String, dynamic>? _lastDeletedCustomer;
  Timer? _undoTimer;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final int _limit = 20;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ✅ استخدام كلاس الألوان الموحد
  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _searchController.addListener(_filterCustomers);
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
      _loadMoreCustomers();
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    final db = ref.read(databaseHelperProvider);
    final newCustomers = await db.getCustomersPaginated(
      page: _currentPage,
      limit: _limit,
    );
    if (newCustomers.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _customers.addAll(newCustomers);
        _filteredCustomers = List.from(_customers);
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _currentPage = 1;
    _hasMore = true;
    try {
      final db = ref.read(databaseHelperProvider);
      final customers =
          await db.getCustomersPaginated(page: 1, limit: _limit);
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _filteredCustomers = List.from(customers);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ في تحميل العملاء: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل تحميل بيانات العملاء: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: _loadCustomers,
          ),
        ),
      );
    }
  }

  void _filterCustomers() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final query = _searchController.text.trim().toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _filteredCustomers = List.from(_customers);
        } else {
          _filteredCustomers = _customers.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final phone = (c['phone'] ?? '').toString().toLowerCase();
            final address = (c['address'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                phone.contains(query) ||
                address.contains(query);
          }).toList();
        }
      });
    });
  }

  // ==================== حوار إضافة / تعديل ====================
  Future<void> _showAddEditDialog({Map<String, dynamic>? customer}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCustomerSheet(
        customer: customer,
        colors: _colors,
        onSaved: _loadCustomers,
      ),
    );
  }

  // ==================== حوار الحذف مع ميزة التراجع ====================
  Future<void> _confirmDelete(Map<String, dynamic> customer) async {
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
            Text('حذف العميل',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textMain)),
            const SizedBox(height: 8),
            Text(
              'هل أنت متأكد من حذف "${customer['name']}"؟',
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
                    final deletedItem = Map<String, dynamic>.from(customer);
                    _lastDeletedCustomer = deletedItem;

                    final dbClient = await db.database;
                    await dbClient.transaction((txn) async {
                      await txn.delete('customers', where: 'id = ?', whereArgs: [customer['id']]);
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadCustomers();

                    _undoTimer?.cancel();
                    _undoTimer = Timer(const Duration(seconds: 5), () {
                      _lastDeletedCustomer = null;
                    });

                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حذف العميل "${deletedItem['name']}"'),
                        duration: const Duration(seconds: 5),
                        backgroundColor: AppColors.navy,
                        action: SnackBarAction(
                          label: 'تراجع',
                          textColor: AppColors.primary,
                          onPressed: () async {
                            _undoTimer?.cancel();
                            if (_lastDeletedCustomer != null) {
                              await db.insertCustomer(_lastDeletedCustomer!);
                              _lastDeletedCustomer = null;
                              if (mounted) _loadCustomers();
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
                color: AppColors.info, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text('العملاء',
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
                AppColors.info.withValues(alpha: 0.6),
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
        child: const Icon(Icons.person_add_rounded, size: 24),
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
            onPressed: _loadCustomers,
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

    if (_errorMessage != null && _customers.isEmpty) {
      return _showErrorWidget(colors);
    }

    return Column(children: [
      if (_showSearch)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: colors.scaffoldBg == AppColors.navy
              ? AppColors.navyMedium.withValues(alpha: 0.5)
              : AppColors.info.withValues(alpha: 0.05),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: colors.textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'بحث باسم العميل أو الهاتف...',
              hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
              prefixIcon:
              Icon(Icons.search_rounded, color: colors.textHint, size: 20),
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
                borderSide:
                const BorderSide(color: AppColors.info, width: 1.5),
              ),
            ),
          ),
        ),
      Expanded(
        child: _customers.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 60, color: colors.textHint),
              const SizedBox(height: 16),
              Text('لا توجد عملاء',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain)),
              const SizedBox(height: 4),
              Text('اضغط على زر + لإضافة عميل',
                  style: TextStyle(
                      fontSize: 12, color: colors.textHint)),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadCustomers,
          color: AppColors.info,
          child: _filteredCustomers.isEmpty
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
              itemCount: _filteredCustomers.length + 1,
              itemBuilder: (context, index) {
                if (index == _filteredCustomers.length) {
                  return _isLoadingMore
                      ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                        child: CircularProgressIndicator(
                            valueColor:
                            AlwaysStoppedAnimation<
                                Color>(AppColors.info))),
                  )
                      : const SizedBox.shrink();
                }
                return _buildCustomerCard(index, colors);
              },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildCustomerCard(int index, AppThemeColors colors) {
    final customer = _filteredCustomers[index];
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
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              (customer['name'] ?? 'ع')[0].toUpperCase(),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer['name'] ?? '',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (customer['phone'] != null &&
                  customer['phone'].toString().isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.phone_android_rounded,
                      size: 12, color: colors.textHint),
                  const SizedBox(width: 4),
                  Text(customer['phone'],
                      style: TextStyle(
                          fontSize: 12, color: colors.textSub)),
                ]),
              ],
              if (customer['address'] != null &&
                  customer['address'].toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on_outlined,
                      size: 12, color: colors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(customer['address'],
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
              color: AppColors.primary.withOpacity(0.7), size: 20),
          onPressed: () => _showAddEditDialog(customer: customer),
          tooltip: 'تعديل',
          constraints:
          const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: AppColors.error.withOpacity(0.7), size: 20),
          onPressed: () => _confirmDelete(customer),
          tooltip: 'حذف',
          constraints:
          const BoxConstraints(minWidth: 36, minHeight: 36),
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
    TextInputType? keyboardType,
    int maxLines = 1,
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
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: colors.textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.info, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _AddCustomerSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? customer;
  final dynamic colors;
  final VoidCallback onSaved;

  const _AddCustomerSheet({
    Key? key,
    this.customer,
    required this.colors,
    required this.onSaved,
  }) : super(key: key);

  @override
  ConsumerState<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends ConsumerState<_AddCustomerSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?['name']);
    _phoneController = TextEditingController(text: widget.customer?['phone']);
    _addressController = TextEditingController(text: widget.customer?['address']);
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
    final isEditing = widget.customer != null;
    final colors = widget.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.info.withOpacity(0.3), width: 1),
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
                          color: AppColors.info.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: AppColors.info,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'تعديل عميل' : 'إضافة عميل جديد',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            isEditing ? 'تحديث بيانات العميل' : 'أدخل معلومات العميل الجديد',
                            style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  _fieldLabel('اسم العميل', colors),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _nameController,
                    hint: 'مثال: أحمد محمد',
                    icon: Icons.person_outline_rounded,
                    colors: colors,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('رقم الهاتف', colors),
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
                    hint: 'عنوان العميل',
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
                                content: const Text('يرجى إدخال اسم العميل'),
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
                            await db.updateCustomer(widget.customer!['id'], {
                              'name': _nameController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'address': _addressController.text.trim(),
                            });
                          } else {
                            await db.insertCustomer({
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
          prefixIcon: Icon(icon, color: AppColors.info, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}