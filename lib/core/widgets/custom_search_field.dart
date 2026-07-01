// lib/core/widgets/custom_search_field.dart
// 🆕 تصميم كحلي + ذهبي — خالٍ من GetX وألوان صلبة
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomSearchField extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onBarcodeTap;
  final String hintText;

  const CustomSearchField({
    super.key,
    this.onChanged,
    this.onBarcodeTap,
    this.hintText = 'بحث...',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fillColor = isDark ? AppColors.navyLight : AppColors.lightSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.navyBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          if (onBarcodeTap != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onBarcodeTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                // إزالة const من هنا لحل مشكلة const_with_non_const
                decoration: BoxDecoration(
                  gradient: AppGradients.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.navy),
              ),
            ),
          ],
        ],
      ),
    );
  }
}