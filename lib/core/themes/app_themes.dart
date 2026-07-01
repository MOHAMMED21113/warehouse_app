// lib/core/theme/app_themes.dart
// 🆕 ثيم كحلي داكن + ذهبي فاخر — نفس بنية AppThemes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AppThemes {
  static const double _radius = 16.0;

  // ============================================================
  //  🆕 الثيم المضيء — كحلي AppBar + ذهبي Primary + خلفية بيضاء
  // ============================================================
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: const Color(0xFFF1F5F9), // رمادي فاتح جداً
    primaryColor: AppColors.navy,

    colorScheme: const ColorScheme.light(
      primary:    AppColors.navy,         // كحلي للعناصر الأساسية
      secondary:  AppColors.primary,      // ذهبي للعناصر الثانوية
      surface:    Colors.white,
      background: Color(0xFFF1F5F9),
      error:      AppColors.error,
      onPrimary:  AppColors.primary,      // ذهبي على الكحلي
      onSecondary: AppColors.navy,
      onSurface:  AppColors.navy,
    ),

    // AppBar — كحلي داكن + ذهبي
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.primary, // أيقونات ذهبية
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.primary, // عنوان ذهبي
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),

    // الأزرار الرئيسية — كحلي بنص ذهبي
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ),

    // أزرار الإطار — ذهبي
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(fontFamily: 'Cairo'),
      ),
    ),

    // حقول الإدخال
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF475569), fontFamily: 'Cairo'),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Cairo'),
      prefixIconColor: AppColors.navy,
      suffixIconColor: Color(0xFF64748B),
    ),

    // البطاقات
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
    ),

    // النصوص — على خلفية فاتحة
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.navy, fontFamily: 'Cairo'),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy, fontFamily: 'Cairo'),
      headlineSmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy, fontFamily: 'Cairo'),
      titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy, fontFamily: 'Cairo'),
      titleMedium:    TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy, fontFamily: 'Cairo'),
      titleSmall:     TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.navy, fontFamily: 'Cairo'),
      bodyLarge:      TextStyle(fontSize: 16, color: AppColors.navy,       fontFamily: 'Cairo'),
      bodyMedium:     TextStyle(fontSize: 14, color: Color(0xFF475569),    fontFamily: 'Cairo'),
      bodySmall:      TextStyle(fontSize: 12, color: Color(0xFF94A3B8),    fontFamily: 'Cairo'),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
    ),

    // Drawer
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFFF8FAFC),
    ),

    // Dialog 🆕 DialogThemeData
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: AppColors.navy,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.primary,
      elevation: 4,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(fontFamily: 'Cairo'),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontFamily: 'Cairo',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primary,
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
            (s) => s.contains(MaterialState.selected) ? AppColors.primary : Colors.white,
      ),
      trackColor: MaterialStateProperty.resolveWith(
            (s) => s.contains(MaterialState.selected)
            ? AppColors.primary.withOpacity(0.4)
            : const Color(0xFFCBD5E1),
      ),
    ),
  );

  // ============================================================
  //  🆕 الثيم الداكن — كحلي داكن كامل + ذهبي (الثيم الافتراضي الموصى به)
  // ============================================================
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.navy,         // كحلي داكن #0C1A2E
    primaryColor: AppColors.primary,                 // ذهبي

    colorScheme: const ColorScheme.dark(
      primary:      AppColors.primary,               // ذهبي #D4AF37
      secondary:    AppColors.primaryLight,           // ذهبي فاتح
      surface:      AppColors.navyMedium,             // كحلي متوسط #162236
      background:   AppColors.navy,                  // كحلي داكن #0C1A2E
      error:        AppColors.error,
      onPrimary:    AppColors.navy,                  // نص على الذهبي = كحلي
      onSecondary:  AppColors.navy,
      onSurface:    AppColors.textPrimary,            // أبيض
      onBackground: AppColors.textPrimary,
      onError:      Colors.white,
    ),

    // AppBar — كحلي متوسط + ذهبي
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyMedium,         // #162236
      foregroundColor: AppColors.primary,            // ذهبي
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.primary,                    // عنوان ذهبي
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),

    // الأزرار الرئيسية — ذهبي بنص كحلي
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,          // ذهبي
        foregroundColor: AppColors.navy,             // نص كحلي
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    ),

    // أزرار الإطار — ذهبي
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: const TextStyle(fontFamily: 'Cairo'),
      ),
    ),

    // حقول الإدخال — كحلي فاتح + حدود ذهبية عند التركيز
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.navyLight,                // #1E3050
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.navyBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
      hintStyle: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
      prefixIconColor: AppColors.primary,
      suffixIconColor: AppColors.textSecondary,
    ),

    // البطاقات — كحلي البطاقات + حدود ناعمة
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: AppColors.navyBorder, width: 1),
      ),
      color: AppColors.navyCard,                     // #1A2B44
    ),

    // النصوص — أبيض على كحلي
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      headlineSmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      titleMedium:    TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      titleSmall:     TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      bodyLarge:      TextStyle(fontSize: 16, color: AppColors.textPrimary,   fontFamily: 'Cairo'),
      bodyMedium:     TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Cairo'),
      bodySmall:      TextStyle(fontSize: 12, color: AppColors.textHint,      fontFamily: 'Cairo'),
    ),

    // Divider — كحلي الحدود
    dividerTheme: const DividerThemeData(
      color: AppColors.navyBorder,
      thickness: 1,
    ),

    // Drawer — كحلي متوسط
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.navyMedium,
      elevation: 0,
    ),

    // ListTile — أيقونات ذهبية
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primary,
      textColor: AppColors.textPrimary,
    ),

    // Dialog — كحلي متوسط 🆕 DialogThemeData
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.navyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontFamily: 'Cairo',
      ),
    ),

    // FloatingActionButton — ذهبي بنص كحلي
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.navy,
      elevation: 4,
    ),

    // BottomSheet — كحلي متوسط
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.navyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    // Chip — كحلي فاتح + ذهبي عند الاختيار
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.navyLight,
      selectedColor: AppColors.primary,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
      side: const BorderSide(color: AppColors.navyBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // SnackBar — كحلي بنص أبيض + زر ذهبي
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navyMedium,
      contentTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'Cairo',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primary,
    ),

    // Switch — ذهبي عند التفعيل
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
            (s) => s.contains(MaterialState.selected) ? AppColors.primary : AppColors.textHint,
      ),
      trackColor: MaterialStateProperty.resolveWith(
            (s) => s.contains(MaterialState.selected)
            ? AppColors.primary.withOpacity(0.35)
            : AppColors.navyBorder,
      ),
    ),

    // PopupMenu — كحلي
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.navyMedium,
      textStyle: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),

    // DropdownMenu
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: MaterialStatePropertyAll(AppColors.navyMedium),
      ),
    ),

    // TabBar — ذهبي 🆕 TabBarThemeData
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontFamily: 'Cairo'),
    ),
  );
}