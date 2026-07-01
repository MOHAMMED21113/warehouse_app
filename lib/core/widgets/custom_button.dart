// lib/core/widgets/custom_button.dart
// 🆕 تصميم كحلي + ذهبي — متوافق مع كل الشاشات
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final bool isOutlined;
  final double width;
  final double height;
  final IconData? icon;

  /// حجم خط النص (الافتراضي 15)
  final double fontSize;

  /// حجم الأيقونة (الافتراضي 20)
  final double iconSize;

  /// درجة تدوير الزوايا (الافتراضي 16)
  final double borderRadius;

  /// إظهار ظل ذهبي أسفل الزر (الافتراضي true للزر العادي)
  final bool showShadow;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.isOutlined = false,
    this.width = double.infinity,
    this.height = 52,
    this.icon,
    this.fontSize = 15,
    this.iconSize = 20,
    this.borderRadius = 16,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? AppColors.primary;
    final Color fg = textColor ?? AppColors.navy;
    final radius = BorderRadius.circular(borderRadius);

    // ─── محتوى الزر ───
    final Widget child = isLoading
        ? SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          isOutlined ? bg : fg,
        ),
      ),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    // ─── زر مفرّغ (Outlined) ───
    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: bg,
            side: BorderSide(color: bg, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: radius),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: child,
        ),
      );
    }

    // ─── زر عادي (Elevated) مع ظل ───
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: showShadow && !isLoading
            ? [
          BoxShadow(
            color: bg.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withOpacity(0.5),
          disabledForegroundColor: fg.withOpacity(0.5),
          elevation: 0, // الظل يأتي من Container
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: child,
      ),
    );
  }
}