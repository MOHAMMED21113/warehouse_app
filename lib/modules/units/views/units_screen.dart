// lib/modules/units/views/units_screen.dart
// 🆕 تصميم كحلي + ذهبي — محول إلى Riverpod
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../database/database_helper.dart';

class UnitsScreen extends ConsumerStatefulWidget {
  const UnitsScreen({super.key});

  @override
  ConsumerState<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends ConsumerState<UnitsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _filteredUnits = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ===== ألوان متكيفة =====
  bool get _dark => ref.watch(themeModeProvider) == ThemeMode.dark;
  Color get _scaffoldBg => _dark ? AppColors.navy : const Color(0xFFF1F5F9);
  Color get _cardBg => _dark ? AppColors.navyCard : Colors.white;
  Color get _cardBorder => _dark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
  Color get _textMain => _dark ? AppColors.textPrimary : AppColors.navy;
  Color get _textSub => _dark ? AppColors.textSecondary : const Color(0xFF475569);
  Color get _textHint => _dark ? AppColors.textHint : const Color(0xFF94A3B8);
  Color get _inputFill => _dark ? AppColors.navyLight : Colors.white;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _searchController.addListener(_filterUnits);
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
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseHelperProvider);
      final units = await db.getAllUnits();
      setState(() {
        _units = units;
        _filteredUnits = units;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ في تحميل الوحدات: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterUnits() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUnits = List.from(_units);
      } else {
        _filteredUnits = _units.where((u) {
          final name = (u['name'] ?? '').toString().toLowerCase();
          final symbol = (u['symbol'] ?? '').toString().toLowerCase();
          return name.contains(query) || symbol.contains(query);
        }).toList();
      }
    });
  }

  // ==================== حوار إضافة / تعديل ====================
  Future<void> _showAddEditDialog({Map<String, dynamic>? unit}) async {
    final isEditing = unit != null;
    final nameController = TextEditingController(text: unit?['name']);
    final symbolController = TextEditingController(text: unit?['symbol']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20, right: 20, top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: _cardBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_rounded,
                            color: AppColors.primary, size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'تعديل وحدة قياس' : 'إضافة وحدة قياس جديدة',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              isEditing ? 'تحديث بيانات الوحدة' : 'أدخل معلومات الوحدة الجديدة',
                              style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8)),
                            ),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    _fieldLabel('اسم الوحدة'),
                    const SizedBox(height: 6),
                    _buildInputField(controller: nameController, hint: 'مثال: حبة، كيلو، باكيت', icon: Icons.straighten_rounded),
                    const SizedBox(height: 16),
                    _fieldLabel('الرمز'),
                    const SizedBox(height: 6),
                    _buildInputField(controller: symbolController, hint: 'مثال: pc, kg, pkt', icon: Icons.tag_rounded),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textSub,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: _cardBorder),
                          ),
                          child: Text('إلغاء', style: TextStyle(color: _textSub)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('يرجى إدخال اسم الوحدة'),
                                  backgroundColor: AppColors.warning.withOpacity(0.95),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                              return;
                            }
                            final db = ref.read(databaseHelperProvider);
                            if (isEditing) {
                              await db.updateUnit(unit!['id'], {
                                'name': nameController.text.trim(),
                                'symbol': symbolController.text.trim(),
                              });
                            } else {
                              await db.insertUnit({
                                'name': nameController.text.trim(),
                                'symbol': symbolController.text.trim(),
                                'is_default': 0,
                              });
                            }
                            Navigator.pop(ctx);
                            _loadUnits();
                          },
                          icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 18),
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
      ),
    );
  }

  Future<void> _setAsDefault(Map<String, dynamic> unit) async {
    final db = ref.read(databaseHelperProvider);
    await db.setDefaultUnit(unit['id']);
    _loadUnits();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تعيين "${unit['name']}" كوحدة افتراضية'),
        backgroundColor: AppColors.success.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ==================== حوار الحذف ====================
  Future<void> _confirmDelete(Map<String, dynamic> unit) async {
    final db = ref.read(databaseHelperProvider);
    final productsCount = await db.getProductsCountByUnit(unit['id']);
    if (productsCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن الحذف: يوجد $productsCount منتج(منتجات)'),
          backgroundColor: AppColors.warning.withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever_rounded, size: 40, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text('حذف الوحدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من حذف "${unit['name']}"؟', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _textSub)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSub,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: _cardBorder),
                  ),
                  child: Text('إلغاء', style: TextStyle(color: _textSub)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await db.deleteUnit(unit['id']);
                    Navigator.pop(ctx);
                    _loadUnits();
                  },
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: _dark ? AppColors.navyMedium : AppColors.navy,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('وحدات القياس', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.primary.withOpacity(0.6), AppColors.navy])),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.navy,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 24),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)));
    }

    return Column(children: [
      if (_showSearch)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: _dark ? AppColors.navyMedium.withOpacity(0.5) : AppColors.primary.withOpacity(0.05),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: _textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'بحث باسم الوحدة أو الرمز...',
              hintStyle: TextStyle(color: _textHint, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: _textHint, size: 20),
              suffixIcon: IconButton(icon: Icon(Icons.clear_rounded, color: _textHint, size: 18), onPressed: () => _searchController.clear()),
              filled: true, fillColor: _inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),
      Expanded(
        child: _units.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.straighten_rounded, size: 60, color: _textHint),
              const SizedBox(height: 16),
              Text('لا توجد وحدات قياس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)),
              const SizedBox(height: 4),
              Text('اضغط على زر + لإضافة وحدة', style: TextStyle(fontSize: 12, color: _textHint)),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadUnits,
          color: AppColors.primary,
          child: _filteredUnits.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('لا توجد نتائج', style: TextStyle(color: _textSub))))])
              : FadeTransition(
            opacity: _fadeAnimation,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredUnits.length,
              itemBuilder: (context, index) => _buildUnitCard(index),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildUnitCard(int index) {
    final unit = _filteredUnits[index];
    final isDefault = unit['is_default'] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefault ? AppColors.primary.withOpacity(0.4) : _cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: const Center(child: Icon(Icons.straighten_rounded, color: AppColors.primary, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(unit['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textMain)),
                if (unit['symbol'] != null && unit['symbol'].toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(right: 6), child: Text('(${unit['symbol']})', style: TextStyle(fontSize: 12, color: _textSub))),
              ]),
              if (isDefault) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5)),
                  child: const Text('افتراضي ⭐', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ],
          ),
        ),
        if (!isDefault)
          IconButton(
            icon: Icon(Icons.star_outline_rounded, color: AppColors.primary.withOpacity(0.5), size: 18),
            onPressed: () => _setAsDefault(unit),
            tooltip: 'تعيين كافتراضي',
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
          ),
        IconButton(
          icon: Icon(Icons.edit_rounded, color: AppColors.primary.withOpacity(0.7), size: 18),
          onPressed: () => _showAddEditDialog(unit: unit),
          tooltip: 'تعديل',
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error.withOpacity(0.7), size: 18),
          onPressed: () => _confirmDelete(unit),
          tooltip: 'حذف',
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: _textMain, fontSize: 13));
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(color: _inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: TextStyle(color: _textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: _textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}