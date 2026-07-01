// lib/core/widgets/custom_appbar.dart
// 🆕 تصميم كحلي + ذهبي — متوافق مع كل الشاشات (Riverpod + Clean Architecture)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../modules/ai_chat/views/ai_chat_screen.dart';
import '../constants/app_colors.dart';
import '../providers/global_providers.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  /// لون النقطة بجانب العنوان + طرف التدرج السفلي.
  /// الافتراضي = AppColors.primary (ذهبي).
  final Color? accentColor;

  /// إظهار خط التدرج الذهبي أسفل الشريط (الافتراضي = true).
  final bool showGradientLine;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.centerTitle = true,
    this.backgroundColor,
    this.bottom,
    this.accentColor,
    this.showGradientLine = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final Color bg =
        backgroundColor ?? (isDark ? AppColors.navyMedium : AppColors.navy);
    final Color accent = accentColor ?? AppColors.primary;

    return AppBar(
      backgroundColor: bg,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: centerTitle,
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppColors.primary),
        onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
      )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
      // 2️⃣ التعديل الجوهري هنا: دمج زر الذكاء الاصطناعي مع باقي الأزرار إن وجدت
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
          tooltip: 'المساعد الذكي',
          onPressed: () {
            // 👇 التنقل باستخدام Navigator.push بدلاً من Get.to()
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            );
          },
        ),
        // هذا السطر يضمن عدم ضياع أي أزرار أخرى يتم تمريرها من الشاشات
        if (actions != null) ...actions!,
      ],
      bottom: bottom ??
          (showGradientLine
              ? PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    bg,
                    AppColors.primary.withOpacity(0.6),
                    accent,
                  ],
                ),
              ),
            ),
          )
              : null),
    );
  }

  @override
  Size get preferredSize {
    double extraHeight = 0;
    if (bottom != null) {
      extraHeight = bottom!.preferredSize.height;
    } else if (showGradientLine) {
      extraHeight = 2; // ارتفاع خط التدرج
    }
    return Size.fromHeight(kToolbarHeight + extraHeight);
  }
}