// lib/modules/settings/providers/shop_settings_provider.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../core/providers/global_providers.dart';

class ShopSettingsState {
  final String shopName;
  final String shopNameEn;
  final String shopPhone;
  final String shopAddress;
  final String shopAddressEn;
  final String crNumber;
  final String taxNumber;
  final String shopActivityAr;
  final String shopActivityEn;
  final String logoPath; // مسار حفظ الصورة
  final bool isLoading;
  final bool isSaving;

  const ShopSettingsState({
    this.shopName = '',
    this.shopNameEn = '',
    this.shopPhone = '',
    this.shopAddress = '',
    this.shopAddressEn = '',
    this.crNumber = '',
    this.taxNumber = '',
    this.shopActivityAr = '',
    this.shopActivityEn = '',
    this.logoPath = '',
    this.isLoading = false,
    this.isSaving = false,
  });

  ShopSettingsState copyWith({
    String? shopName,
    String? shopNameEn,
    String? shopPhone,
    String? shopAddress,
    String? shopAddressEn,
    String? crNumber,
    String? taxNumber,
    String? shopActivityAr,
    String? shopActivityEn,
    String? logoPath,
    bool? isLoading,
    bool? isSaving,
  }) {
    return ShopSettingsState(
      shopName: shopName ?? this.shopName,
      shopNameEn: shopNameEn ?? this.shopNameEn,
      shopPhone: shopPhone ?? this.shopPhone,
      shopAddress: shopAddress ?? this.shopAddress,
      shopAddressEn: shopAddressEn ?? this.shopAddressEn,
      crNumber: crNumber ?? this.crNumber,
      taxNumber: taxNumber ?? this.taxNumber,
      shopActivityAr: shopActivityAr ?? this.shopActivityAr,
      shopActivityEn: shopActivityEn ?? this.shopActivityEn,
      logoPath: logoPath ?? this.logoPath,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

final shopSettingsProvider = AutoDisposeAsyncNotifierProvider<ShopSettingsNotifier, ShopSettingsState>(
  ShopSettingsNotifier.new,
);

class ShopSettingsNotifier extends AutoDisposeAsyncNotifier<ShopSettingsState> {
  @override
  Future<ShopSettingsState> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    return ShopSettingsState(
      shopName: prefs.getString('shop_name') ?? '',
      shopNameEn: prefs.getString('shop_name_en') ?? '',
      shopPhone: prefs.getString('shop_phone') ?? '',
      shopAddress: prefs.getString('shop_address') ?? '',
      shopAddressEn: prefs.getString('shop_address_en') ?? '',
      crNumber: prefs.getString('cr_number') ?? '',
      taxNumber: prefs.getString('tax_number') ?? '',
      shopActivityAr: prefs.getString('shop_activity_ar') ?? '',
      shopActivityEn: prefs.getString('shop_activity_en') ?? '',
      logoPath: prefs.getString('shop_logo_path') ?? '', 
    );
  }

  Future<void> saveSettings({
    required String shopName,
    required String shopNameEn,
    required String shopPhone,
    required String shopAddress,
    required String shopAddressEn,
    required String crNumber,
    required String taxNumber,
    required String shopActivityAr,
    required String shopActivityEn,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('shop_name', shopName);
    await prefs.setString('shop_name_en', shopNameEn);
    await prefs.setString('shop_phone', shopPhone);
    await prefs.setString('shop_address', shopAddress);
    await prefs.setString('shop_address_en', shopAddressEn);
    await prefs.setString('cr_number', crNumber);
    await prefs.setString('tax_number', taxNumber);
    await prefs.setString('shop_activity_ar', shopActivityAr);
    await prefs.setString('shop_activity_en', shopActivityEn);

    // الحفاظ على مسار الشعار كما هو
    final currentLogoPath = state.value?.logoPath ?? '';

    state = AsyncValue.data(ShopSettingsState(
      shopName: shopName,
      shopNameEn: shopNameEn,
      shopPhone: shopPhone,
      shopAddress: shopAddress,
      shopAddressEn: shopAddressEn,
      crNumber: crNumber,
      taxNumber: taxNumber,
      shopActivityAr: shopActivityAr,
      shopActivityEn: shopActivityEn,
      logoPath: currentLogoPath,
    ));
  }

  // 💡 دالة جديدة لحفظ الشعار في ملفات التطبيق (لضمان بقائه للأبد)
  Future<void> saveLogo(String imagePath) async {
    if (imagePath.isEmpty) return;

    try {
      final File sourceFile = File(imagePath);
      final directory = await getApplicationDocumentsDirectory();

      // استخراج امتداد الملف (مثلاً .png أو .jpg)
      final String extension = path.extension(imagePath);

      // إنشاء مسار دائم داخل مجلد التطبيق
      final String savedPath = '${directory.path}/shop_logo$extension';
      final File savedFile = await sourceFile.copy(savedPath);

      // حفظ المسار الدائم في الإعدادات
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('shop_logo_path', savedFile.path);

      // تحديث الحالة
      if (state.hasValue) {
        state = AsyncValue.data(state.value!.copyWith(logoPath: savedFile.path));
      }
    } catch (e) {
      throw Exception('فشل حفظ الشعار: $e');
    }
  }

  // 💡 دالة لإزالة الشعار
  Future<void> removeLogo() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('shop_logo_path');

    if (state.hasValue) {
      state = AsyncValue.data(state.value!.copyWith(logoPath: ''));
    }
  }
}