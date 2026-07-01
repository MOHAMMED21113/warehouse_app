// lib/modules/groups/views/groups_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/groups_provider.dart'; // 🚀 استيراد المزود
import 'categories_screen.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppThemeColors get _colors => AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {})); // التحديث لتفعيل فلترة البحث المحلية
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
  void _showAddEditDialog({Map<String, dynamic>? group}) {
    final isEditing = group != null;
    final nameController = TextEditingController(text: group?['name']);
    final descController = TextEditingController(text: group?['description']);
    final colors = _colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
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
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isEditing ? Icons.edit_rounded : Icons.create_new_folder_rounded, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEditing ? 'تعديل مجموعة' : 'إضافة مجموعة جديدة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(isEditing ? 'تحديث بيانات المجموعة' : 'أدخل معلومات المجموعة الجديدة', style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.8))),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    _fieldLabel('اسم المجموعة', colors),
                    const SizedBox(height: 6),
                    _buildInputField(controller: nameController, hint: 'مثال: إلكترونيات', icon: Icons.folder_outlined, colors: colors),
                    const SizedBox(height: 16),
                    _fieldLabel('الوصف', colors),
                    const SizedBox(height: 6),
                    _buildInputField(controller: descController, hint: 'وصف المجموعة (اختياري)', icon: Icons.description_outlined, maxLines: 3, colors: colors),
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
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('يرجى إدخال اسم المجموعة'),
                                backgroundColor: AppColors.warning.withOpacity(0.95),
                              ));
                              return;
                            }

                            // 🚀 إرسال الأوامر للمزود (Provider)
                            final notifier = ref.read(groupsProvider.notifier);
                            final data = {
                              'name': nameController.text.trim(),
                              'description': descController.text.trim(),
                            };

                            if (isEditing) {
                              await notifier.updateGroup(group!['id'], data);
                            } else {
                              await notifier.addGroup(data);
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
  void _confirmDelete(Map<String, dynamic> group) async {
    final notifier = ref.read(groupsProvider.notifier);

    // 🚀 التأكد من عدم وجود فئات مرتبطة قبل الحذف
    final hasLinkedCategories = await notifier.hasCategories(group['id']);
    if (hasLinkedCategories && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('لا يمكن الحذف: يوجد فئات (Categories) مرتبطة بهذه المجموعة'),
        backgroundColor: AppColors.warning.withOpacity(0.95),
      ));
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: _colors.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_forever_rounded, size: 40, color: AppColors.error)),
            const SizedBox(height: 16),
            Text('حذف المجموعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _colors.textMain)),
            const SizedBox(height: 8),
            Text('هل أنت متأكد من حذف "${group['name']}"؟\nهذا الإجراء لا يمكن التراجع عنه.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _colors.textSub)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: BorderSide(color: _colors.cardBorder)), child: Text('إلغاء', style: TextStyle(color: _colors.textSub)))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await notifier.deleteGroup(group['id']);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_rounded, size: 18), label: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, elevation: 0),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    // 🚀 الاستماع لمزود البيانات الخاص بالمجموعات
    final asyncGroups = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg, foregroundColor: colors.appBarFg, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.of(context).pop()),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('المجموعات', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
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
          child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.success.withOpacity(0.6), AppColors.navy]))),
        ),
      ),
      body: _buildBody(colors, asyncGroups),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: colors.fabBg, foregroundColor: colors.fabFg, elevation: 4,
        child: const Icon(Icons.add_rounded, size: 24),
      ),
    );
  }

  Widget _buildBody(AppThemeColors colors, AsyncValue<List<Map<String, dynamic>>> asyncGroups) {
    return Column(children: [
      if (_showSearch)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: colors.scaffoldBg == AppColors.navy ? AppColors.navyMedium.withOpacity(0.5) : AppColors.success.withOpacity(0.05),
          child: TextField(
            controller: _searchController, autofocus: true,
            style: TextStyle(color: colors.textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'بحث باسم المجموعة أو الوصف...', hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: colors.textHint, size: 20),
              suffixIcon: IconButton(icon: Icon(Icons.clear_rounded, color: colors.textHint, size: 18), onPressed: () => _searchController.clear()),
              filled: true, fillColor: colors.inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.success, width: 1.5)),
            ),
          ),
        ),
      Expanded(
        child: asyncGroups.when(
          loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.success))),
          error: (err, stack) => Center(child: Text('حدث خطأ: $err', style: const TextStyle(color: AppColors.error))),
          data: (groups) {
            // 🚀 فلترة البيانات محلياً
            final query = _searchController.text.trim().toLowerCase();
            final filteredList = query.isEmpty
                ? groups
                : groups.where((g) => (g['name'] ?? '').toLowerCase().contains(query) || (g['description'] ?? '').toLowerCase().contains(query)).toList();

            if (groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_outlined, size: 60, color: colors.textHint),
                    const SizedBox(height: 16),
                    Text('لا توجد مجموعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textMain)),
                    const SizedBox(height: 4),
                    Text('اضغط على زر + لإضافة مجموعة', style: TextStyle(fontSize: 12, color: colors.textHint)),
                  ],
                ),
              );
            }

            if (filteredList.isEmpty) {
              return Center(child: Text('لا توجد نتائج', style: TextStyle(color: colors.textSub)));
            }

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(groupsProvider),
              color: AppColors.success,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) => _buildGroupCard(filteredList[index], colors),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildGroupCard(Map<String, dynamic> group, AppThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CategoriesScreen(groupId: group['id'], groupName: group['name'])),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.cardBorder)),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Center(child: Icon(Icons.folder_rounded, color: AppColors.primary, size: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textMain)),
                  if (group['description'] != null && group['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(group['description'], style: TextStyle(fontSize: 12, color: colors.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: AppColors.primary.withOpacity(0.7), size: 20),
              onPressed: () => _showAddEditDialog(group: group),
              tooltip: 'تعديل',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error.withOpacity(0.7), size: 20),
              onPressed: () => _confirmDelete(group),
              tooltip: 'حذف',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero,
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textHint, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, AppThemeColors colors) => Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: colors.textMain, fontSize: 13));

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon, int maxLines = 1, required AppThemeColors colors}) {
    return Container(
      decoration: BoxDecoration(color: colors.inputFill, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: TextStyle(color: colors.textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.success, size: 20), border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}