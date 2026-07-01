// lib/core/widgets/custom_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../providers/global_providers.dart';

class CustomCard extends ConsumerWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget child;
  final VoidCallback? onAddPressed;
  final List<Widget>? actions;
  final bool showHeader;
  final EdgeInsetsGeometry? contentPadding;

  const CustomCard({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    required this.child,
    this.onAddPressed,
    this.actions,
    this.showHeader = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    // ✅ استخدام الكلاس الجديد بدلاً من getters المكررة
    final colors = AppThemeColors(isDark: isDark);
    final Color accent = iconColor ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.06),
                  border: Border(bottom: BorderSide(color: colors.dividerColor)),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textMain,
                        ),
                      ),
                    ),
                    if (onAddPressed != null)
                      InkWell(
                        onTap: onAddPressed,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add_rounded, color: accent, size: 18),
                        ),
                      ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            Padding(
              padding: contentPadding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}