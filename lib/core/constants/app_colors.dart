// lib/core/constants/app_colors.dart
// ✅ ملف واحد موحد لجميع الألوان (ثابتة + ديناميكية)
import 'package:flutter/material.dart';

// ============================================================
//  🆕 الثيم الجديد: كحلي داكن (#0C1A2E) + ذهبي (#D4AF37)
// ============================================================

class AppColors {
  // ==================== الذهبي — اللون الأساسي ====================
  static const Color primary = Color(0xFFD4AF37); // ذهبي أصيل
  static const Color primaryLight = Color(0xFFEDD057); // ذهبي فاتح
  static const Color primaryDark = Color(0xFFB8941F); // ذهبي داكن

  // ==================== الكحلي — لون الخلفيات ====================
  static const Color navy = Color(0xFF0C1A2E); // كحلي داكن جداً (الخلفية)
  static const Color navyMedium = Color(0xFF162236); // كحلي متوسط (السطوح)
  static const Color navyLight = Color(0xFF1E3050); // كحلي فاتح (العناصر)
  static const Color navyCard = Color(0xFF1A2B44); // كحلي للبطاقات
  static const Color navyBorder = Color(0xFF2A3F5F); // كحلي للحدود

  static const Color lightSurface = Color(0xFFF8FAFC);

  // ==================== الثانوي ====================
  static const Color secondary = Color(0xFFD4AF37); // ذهبي
  static const Color secondaryLight = Color(0xFFEDD057); // ذهبي فاتح

  // ==================== ألوان الحالات ====================
  static const Color success = Color(0xFF10B981); // أخضر
  static const Color warning = Color(0xFFF59E0B); // برتقالي
  static const Color error = Color(0xFFEF4444); // أحمر
  static const Color info = Color(0xFF60A5FA); // أزرق فاتح

  // ==================== الخلفيات (مضيء) ====================
  static const Color background = Color(0xFF0C1A2E); // كحلي داكن
  static const Color surface = Color(0xFF162236); // سطح البطاقات
  static const Color cardColor = Color(0xFF1A2B44); // بطاقة

  // ==================== النصوص ====================
  static const Color textPrimary = Color(0xFFF8FAFC); // أبيض ناصع
  static const Color textSecondary = Color(0xFFCBD5E1); // رمادي فاتح
  static const Color textHint = Color(0xFF64748B); // رمادي باهت

  // ==================== الحدود والظلال ====================
  static const Color border = Color(0xFF2A3F5F);
  static const Color shadow = Color(0x60000000);

  // ==================== ألوان الوضع الفاتح ====================
  static const Color lightTextPrimary = Color(0xFF0F172A); // slate-900
  static const Color lightTextSecondary = Color(0xFF334155); // slate-700
  static const Color lightTextHint = Color(0xFF64748B); // slate-500
  static const Color lightBorder = Color(0xFFE2E8F0); // slate-200
  static const Color lightCardBg = Color(0xFFFFFFFF); // أبيض
  static const Color lightSurfaceAlt = Color(0xFFF8FAFC); // slate-50

  // ==================== الوضع الليلي ====================
  static const Color darkBackground = Color(0xFF0C1A2E);
  static const Color darkSurface = Color(0xFF162236);
  static const Color darkCardColor = Color(0xFF1A2B44);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextHint = Color(0xFF64748B);
  static const Color darkBorder = Color(0xFF2A3F5F);
  static const Color darkShadow = Color(0x60000000);
}

// ============================================================
//  🆕 AppThemeColors - ألوان ديناميكية حسب الوضع (فاتح/داكن)
// ============================================================
class AppThemeColors {
  final bool isDark;

  const AppThemeColors({required this.isDark});

  // ===== ألوان الخلفيات =====
  Color get scaffoldBg => isDark ? AppColors.darkBackground : AppColors.lightSurface;
  Color get cardBg => isDark ? AppColors.darkCardColor : Colors.white;
  Color get cardBorder => isDark ? AppColors.darkBorder : Colors.grey.shade300;

  // ===== ألوان النصوص =====
  Color get textMain => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSub => isDark ? AppColors.darkTextSecondary : Colors.grey.shade700;
  Color get textHint => isDark ? AppColors.darkTextHint : Colors.grey.shade500;

  // ===== ألوان حقول الإدخال =====
  Color get inputFill => isDark ? AppColors.navyLight : Colors.grey.shade50;
  Color get inputBg => inputFill;
  Color get inputBorder => isDark ? AppColors.navyBorder : Colors.grey.shade300;

  // ===== ألوان AppBar =====
  Color get appBarBg => isDark ? AppColors.navyMedium : AppColors.navy;
  Color get appBarFg => AppColors.primary;

  // ===== ألوان FloatingActionButton =====
  Color get fabBg => AppColors.primary;
  Color get fabFg => AppColors.navy;

  // ===== ألوان Switch =====
  Color get switchActive => AppColors.primary;
  Color get switchInactive => isDark ? AppColors.textHint : Colors.grey.shade400;

  // ===== ألوان Divider =====
  Color get dividerColor => isDark ? AppColors.navyBorder : Colors.grey.shade300;

  // ===== ألوان الظلال =====
  Color get shadowColor => isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08);

  // ===== ألوان الأيقونات =====
  Color get iconPrimary => AppColors.primary;
  Color get iconSecondary => isDark ? AppColors.textSecondary : Colors.grey.shade600;
}

// ============================================================
//  🆕 ألوان الأقسام — ذهبية بدلاً من الخضراء
// ============================================================
class CategoryColors {
  static const Color dashboard = Color(0xFFD4AF37);
  static const Color groups = Color(0xFFD4AF37);
  static const Color subcategories = Color(0xFF818CF8);
  static const Color products = Color(0xFF60A5FA);
  static const Color suppliers = Color(0xFFCBD5E1);
  static const Color customers = Color(0xFF34D399);
  static const Color warehouses = Color(0xFFD4AF37);
  static const Color units = Color(0xFFFBBF24);
  static const Color profit = Color(0xFF34D399);
  static const Color invoices = Color(0xFF818CF8);
  static const Color notifications = Color(0xFFEF4444);
  static const Color backup = Color(0xFF60A5FA);
  static const Color export = Color(0xFF06B6D4);
  static const Color users = Color(0xFFA78BFA);
  static const Color barcode = Color(0xFFA78BFA);
}

// ============================================================
//  🆕 ألوان المعاملات المالية
// ============================================================
class FinancialColors {
  static const Color purchase = Color(0xFFF97316);
  static const Color sales = Color(0xFF34D399);
  static const Color invoice = Color(0xFF818CF8);
  static const Color barcode = Color(0xFFA78BFA);
}

// ============================================================
//  🆕 التدرجات — كحلي + ذهبي
// ============================================================
class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0C1A2E), Color(0xFF1E3050)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFB8941F), Color(0xFFD4AF37), Color(0xFFEDD057)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient welcomeGradient = LinearGradient(
    colors: [Color(0xFF0C1A2E), Color(0xFF162236), Color(0xFF1E3050)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient salesGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purchaseGradient = LinearGradient(
    colors: [Color(0xFF9A3412), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient productsGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient customersGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient treasuryGradient = LinearGradient(
    colors: [Color(0xFF78350F), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient voucherGradient = LinearGradient(
    colors: [Color(0xFF3730A3), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient debtorsGradient = LinearGradient(
    colors: [Color(0xFF991B1B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient creditorsGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backupGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient barcodeGradient = LinearGradient(
    colors: [Color(0xFF4C1D95), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dashboardGradient = LinearGradient(
    colors: [Color(0xFF78350F), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // للتوافق مع الكود القديم
  static const LinearGradient salesGradients = primaryGradient;
  static const LinearGradient invoiceGradient = voucherGradient;
}