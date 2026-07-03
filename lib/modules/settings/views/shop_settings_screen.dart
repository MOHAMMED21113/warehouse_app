// lib/modules/settings/views/shop_settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/vision/v1.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/shop_settings_provider.dart';

class ShopSettingsScreen extends ConsumerStatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  ConsumerState<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends ConsumerState<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressEnController = TextEditingController();
  final _crNumberController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _activityArController = TextEditingController();
  final _activityEnController = TextEditingController();
  bool _isSaving = false;

  // 💡 للتعامل مع مكتبة الصور
// 💡 للتعامل مع مكتبة الصور باستخدام الاسم المستعار
  final picker.ImagePicker _picker = picker.ImagePicker();
  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Just a fallback if it's already loaded synchronously
      final state = ref.read(shopSettingsProvider).value;
      if (state != null) {
        _nameController.text = state.shopName;
        _nameEnController.text = state.shopNameEn;
        _phoneController.text = state.shopPhone;
        _emailController.text = state.shopEmail;
        _addressController.text = state.shopAddress;
        _addressEnController.text = state.shopAddressEn;
        _crNumberController.text = state.crNumber;
        _taxNumberController.text = state.taxNumber;
        _activityArController.text = state.shopActivityAr;
        _activityEnController.text = state.shopActivityEn;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _addressEnController.dispose();
    _crNumberController.dispose();
    _taxNumberController.dispose();
    _activityArController.dispose();
    _activityEnController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(shopSettingsProvider.notifier).saveSettings(
        shopName: _nameController.text.trim(),
        shopNameEn: _nameEnController.text.trim(),
        shopPhone: _phoneController.text.trim(),
        shopEmail: _emailController.text.trim(),
        shopAddress: _addressController.text.trim(),
        shopAddressEn: _addressEnController.text.trim(),
        crNumber: _crNumberController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        shopActivityAr: _activityArController.text.trim(),
        shopActivityEn: _activityEnController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ بيانات المحل بنجاح'),
            backgroundColor: AppColors.success.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 💡 دالة اختيار الصورة
  Future<void> _pickImage() async {
    try {
      final picker.XFile? image = await _picker.pickImage(
        source: picker.ImageSource.gallery, // 💡 هنا حددنا أننا نقصد ImageSource الخاص بالـ picker
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await ref.read(shopSettingsProvider.notifier).saveLogo(image.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم رفع الشعار بنجاح'),
            backgroundColor: AppColors.success,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في اختيار الصورة: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final colors = _colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSub, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.success, size: 20),
      filled: true,
      fillColor: colors.inputFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.cardBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: AppColors.success, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final asyncState = ref.watch(shopSettingsProvider);

    ref.listen<AsyncValue<ShopSettingsState>>(shopSettingsProvider, (previous, next) {
      if (next.value != null && (previous == null || previous.isLoading)) {
        final state = next.value!;
        _nameController.text = state.shopName;
        _nameEnController.text = state.shopNameEn;
        _phoneController.text = state.shopPhone;
        _emailController.text = state.shopEmail;
        _addressController.text = state.shopAddress;
        _addressEnController.text = state.shopAddressEn;
        _crNumberController.text = state.crNumber;
        _taxNumberController.text = state.taxNumber;
        _activityArController.text = state.shopActivityAr;
        _activityEnController.text = state.shopActivityEn;
      }
    });

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('بيانات المحل التجاري',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
            ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.navy,
                AppColors.success.withOpacity(0.6),
                AppColors.navy,
              ]),
            ),
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.success)),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (state) => Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.cardBorder),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 💡 قسم الشعار الجديد ---
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: colors.inputFill,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.success.withOpacity(0.5), width: 2),
                                    image: state.logoPath.isNotEmpty
                                        ? DecorationImage(
                                      image: FileImage(File(state.logoPath)),
                                      fit: BoxFit.cover,
                                    )
                                        : null,
                                  ),
                                  child: state.logoPath.isEmpty
                                      ? Icon(Icons.storefront_rounded, size: 40, color: colors.textSub)
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(state.logoPath.isEmpty ? 'انقر لإضافة الشعار' : 'تغيير الشعار', style: TextStyle(color: colors.textSub, fontSize: 12)),
                          if (state.logoPath.isNotEmpty)
                            TextButton(
                              onPressed: () => ref.read(shopSettingsProvider.notifier).removeLogo(),
                              child: const Text('حذف الشعار', style: TextStyle(color: AppColors.error, fontSize: 12)),
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(height: 1, color: colors.dividerColor),
                    const SizedBox(height: 24),
                    // ----------------------------

                    // اسم المحل
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      decoration: _inputDecoration(
                        'اسم المحل / المؤسسة (عربي)',
                        Icons.business_rounded,
                      ),
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nameEnController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      textDirection: TextDirection.ltr,
                      decoration: _inputDecoration(
                        'اسم المحل / المؤسسة (إنجليزي)',
                        Icons.business_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // السجل التجاري
                    TextFormField(
                      controller: _crNumberController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      decoration: _inputDecoration(
                        'السجل التجاري (C.R)',
                        Icons.numbers_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // الرقم الضريبي
                    TextFormField(
                      controller: _taxNumberController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      decoration: _inputDecoration(
                        'الرقم الضريبي (Tax No.)',
                        Icons.request_quote_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // النشاط
                    TextFormField(
                      controller: _activityArController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      decoration: _inputDecoration(
                        'النشاط (عربي) - مثلاً: مقاولات عامة',
                        Icons.work_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _activityEnController,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      textDirection: TextDirection.ltr,
                      decoration: _inputDecoration(
                        'النشاط (إنجليزي) - مثلاً: Contracting',
                        Icons.work_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // رقم الجوال
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      textDirection: TextDirection.ltr,
                      decoration: _inputDecoration(
                        'أرقام الجوال (مثال: 05000 / 05555)',
                        Icons.phone_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // البريد الإلكتروني
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      textDirection: TextDirection.ltr,
                      decoration: _inputDecoration(
                        'البريد الإلكتروني (Email)',
                        Icons.email_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // العنوان
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      decoration: _inputDecoration(
                        'العنوان (عربي)',
                        Icons.location_on_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressEnController,
                      maxLines: 2,
                      style: TextStyle(color: colors.textMain, fontSize: 14),
                      textDirection: TextDirection.ltr,
                      decoration: _inputDecoration(
                        'العنوان (إنجليزي)',
                        Icons.location_on_rounded,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // زر الحفظ
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.navy,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save_rounded, size: 20),
                        label: const Text('حفظ الإعدادات',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.navy,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}