// lib/modules/subcategories/views/subcategories_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/subcategories_provider.dart'; // استيراد الـ Provider الجديد
import 'subcategory_details_screen.dart';

class SubcategoriesScreen extends ConsumerStatefulWidget {
  final int? categoryId;
  final String? categoryName;

  const SubcategoriesScreen({
    super.key,
    this.categoryId,
    this.categoryName,
  });

  @override
  ConsumerState<SubcategoriesScreen> createState() => _SubcategoriesScreenState();
}

class _SubcategoriesScreenState extends ConsumerState<SubcategoriesScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppThemeColors get _colors => AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    // لم نعد بحاجة لجلب البيانات يدوياً، Riverpod سيفعل ذلك!
    _searchController.addListener(() => setState(() {})); // تحديث الـ UI فقط عند البحث

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

  // ==================== حوار إضافة / تعديل ====================
  void _showAddEditDialog({Map<String, dynamic>? subcategory}) {
    final isEditing = subcategory != null;
    final nameController = TextEditingController(text: subcategory?['name']);
    final descController = TextEditingController(text: subcategory?['description']);
    int? selectedCategoryId = subcategory?['category_id'] ?? widget.categoryId;
    final colors = _colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 1),
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
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.cardBorder, borderRadius: BorderRadius.circular(10)))),
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
                          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isEditing ? Icons.edit_rounded : Icons.create_new_folder_rounded, color: AppColors.warning, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEditing ? 'تعديل صنف' : 'إضافة صنف جديد', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(isEditing ? 'تحديث بيانات الصنف' : 'أدخل معلومات الصنف الجديد', style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8))),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),

                    _fieldLabel('اختر الفئة', colors),
                    const SizedBox(height: 6),
                    // استخدام Consumer لجلب الفئات (Categories) عبر Riverpod
                    Consumer(
                      builder: (context, ref, child) {
                        final categoriesAsync = ref.watch(categoriesListProvider);
                        return categoriesAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.warning)),
                          error: (err, stack) => Text('خطأ في تحميل الفئات: $err', style: const TextStyle(color: AppColors.error)),
                          data: (categories) => Container(
                            decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<int>(
                                value: selectedCategoryId,
                                isExpanded: true,
                                dropdownColor: colors.cardBg,
                                style: TextStyle(color: colors.textMain, fontSize: 14),
                                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                                items: categories.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text('${c['group_name']} → ${c['name']}'))).toList(),
                                onChanged: (v) => selectedCategoryId = v,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    _fieldLabel('اسم الصنف', colors),
                    const SizedBox(height: 6),
                    _buildInputField(controller: nameController, hint: 'مثال: هواتف', icon: Icons.label_rounded, colors: colors),
                    const SizedBox(height: 16),
                    _fieldLabel('الوصف', colors),
                    const SizedBox(height: 6),
                    _buildInputField(controller: descController, hint: 'وصف الصنف (اختياري)', icon: Icons.description_outlined, maxLines: 3, colors: colors),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textSub, padding: const EdgeInsets.symmetric(vertical: 13),
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
                            if (nameController.text.trim().isEmpty || selectedCategoryId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('يرجى تعبئة الحقول المطلوبة'),
                                backgroundColor: AppColors.warning,
                              ));
                              return;
                            }

                            // 🚀 إرسال البيانات للـ Provider ليقوم بالعمل النظيف
                            final notifier = ref.read(subcategoriesProvider(widget.categoryId).notifier);
                            final data = {
                              'name': nameController.text.trim(),
                              'description': descController.text.trim(),
                              'category_id': selectedCategoryId,
                            };

                            if (isEditing) {
                              await notifier.updateSubcategory(subcategory!['id'], data);
                            } else {
                              await notifier.addSubcategory(data);
                            }
                            if (mounted) Navigator.pop(context);
                          },
                          icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 18),
                          label: Text(isEditing ? 'تحديث' : 'إضافة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, foregroundColor: AppColors.navy, elevation: 0,
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

  // ==================== حوار الحذف ====================
  void _confirmDelete(Map<String, dynamic> subcategory) async {
    final notifier = ref.read(subcategoriesProvider(widget.categoryId).notifier);
    final hasProducts = await notifier.hasProducts(subcategory['id']);

    if (hasProducts && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('لا يمكن الحذف: يوجد منتجات مرتبطة بهذا الصنف'),
        backgroundColor: AppColors.warning.withOpacity(0.95),
      ));
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: _colors.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_forever_rounded, size: 40, color: AppColors.error),
            const SizedBox(height: 16),
            Text('حذف الصنف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _colors.textMain)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من حذف "${subcategory['name']}"؟', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _colors.textSub)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await notifier.deleteSubcategory(subcategory['id']);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                  child: const Text('حذف'),
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
    final title = widget.categoryName != null ? 'أصناف ${widget.categoryName}' : 'جميع الأصناف';

    // 🚀 الاستماع للحالة بشكل تفاعلي ومباشر من الـ Provider
    final asyncSubcategories = ref.watch(subcategoriesProvider(widget.categoryId));

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg, foregroundColor: colors.appBarFg, elevation: 0, centerTitle: true,
        title: Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
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
            Container(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'بحث عن صنف...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),

          Expanded(
            child: asyncSubcategories.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.warning)),
              error: (err, stack) => Center(child: Text('حدث خطأ: $err', style: const TextStyle(color: AppColors.error))),
              data: (subcategories) {
                // تصفية البيانات محلياً في الـ UI بناءً على البحث
                final query = _searchController.text.trim().toLowerCase();
                final filteredList = query.isEmpty
                    ? subcategories
                    : subcategories.where((sub) => (sub['name'] ?? '').toString().toLowerCase().contains(query)).toList();

                if (filteredList.isEmpty) {
                  return Center(child: Text('لا توجد أصناف', style: TextStyle(color: colors.textHint, fontSize: 16)));
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(subcategoriesProvider(widget.categoryId)),
                  color: AppColors.warning,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) => _buildSubcategoryCard(filteredList[index], colors),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: colors.fabBg, foregroundColor: colors.fabFg,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSubcategoryCard(Map<String, dynamic> sub, AppThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: colors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.cardBorder)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.category_rounded, color: AppColors.primary),
        ),
        title: Text(sub['name'] ?? '', style: TextStyle(color: colors.textMain, fontWeight: FontWeight.bold)),
        subtitle: Text('${sub['products_count'] ?? 0} منتجات', style: TextStyle(color: AppColors.warning, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 18), color: AppColors.primary, onPressed: () => _showAddEditDialog(subcategory: sub)),
            IconButton(icon: const Icon(Icons.delete, size: 18), color: AppColors.error, onPressed: () => _confirmDelete(sub)),
          ],
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryDetailsScreen(subcategoryId: sub['id'], subcategoryName: sub['name']))),
      ),
    );
  }

  Widget _fieldLabel(String text, AppThemeColors colors) => Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textMain, fontSize: 13));

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon, int maxLines = 1, required AppThemeColors colors}) {
    return Container(
      decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: TextStyle(color: colors.textMain),
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: AppColors.warning), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
      ),
    );
  }
}