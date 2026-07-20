// lib/modules/settings/views/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colors = AppThemeColors(isDark: isDark);
    final settingsAsync = ref.watch(settingsProvider);

    // ✅ جميع الألوان من AppThemeColors و AppColors (بدون تكرار)
    final scaffoldBg = colors.scaffoldBg;
    final cardBg = colors.cardBg;
    final cardBorder = colors.cardBorder;
    final textMain = colors.textMain;
    final textSub = colors.textSub;
    final textHint = colors.textHint;
    final inputFill = colors.inputFill;

    // ✅ ألوان ثابتة من AppColors
    final gold = AppColors.primary;
    final goldLight = AppColors.primaryLight;
    final emerald = AppColors.success;
    final sky = AppColors.info;
    final rose = AppColors.error;
    final navy = AppColors.navy;
    final navyBorder = AppColors.navyBorder;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.navyMedium : AppColors.navy,
        foregroundColor: gold,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [gold, goldLight]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('الإعدادات العامة',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.primary)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [navy, gold.withOpacity(0.6), navy]),
            ),
          ),
        ),
      ),
      body: settingsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(gold),
            strokeWidth: 2.5,
          ),
        ),
        error: (err, stack) => Center(
          child: Text(
            'حدث خطأ: $err',
            style: TextStyle(color: rose),
          ),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            // ==================== 1. المظهر ====================
            _buildAnimatedSection(
              index: 0,
              child: _SectionCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                title: 'المظهر',
                icon: Icons.palette_rounded,
                iconColor: AppColors.info,
                textMain: textMain,
                child: _SettingTile(
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  iconBg: isDark
                      ? Colors.blue.withOpacity(0.15)
                      : Colors.amber.withOpacity(0.15),
                  iconColor: isDark ? sky : Colors.amber,
                  title: isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
                  subtitle: isDark ? 'اضغط للتبديل إلى الوضع الفاتح' : 'اضغط للتبديل إلى الوضع الداكن',
                  textMain: textMain,
                  textSub: textSub,
                  trailing: _AnimatedThemeSwitch(
                    isDark: isDark,
                    onTap: () {
                      final current = ref.read(themeModeProvider);
                      ref.read(themeModeProvider.notifier).state =
                      current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                    },
                  ),
                  onTap: () {
                    final current = ref.read(themeModeProvider);
                    ref.read(themeModeProvider.notifier).state =
                    current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ==================== 2. إعدادات الأمان والجلسة ====================
            _buildAnimatedSection(
              index: 1,
              child: _SectionCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                title: 'الأمان والجلسة',
                icon: Icons.security_rounded,
                iconColor: rose,
                textMain: textMain,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingTile(
                      icon: Icons.lock_rounded,
                      iconBg: rose.withOpacity(0.15),
                      iconColor: rose,
                      title: 'قفل العمليات المالية',
                      subtitle: 'يتطلب إدخال كلمة المرور عند حفظ الفواتير',
                      textMain: textMain,
                      textSub: textSub,
                      trailing: Switch(
                        value: ref.watch(securityProvider).value?.isTransactionLockEnabled ?? false,
                        onChanged: (v) => ref.read(securityProvider.notifier).toggleTransactionLock(v),
                        activeColor: AppColors.primary,
                      ),
                      onTap: () {
                        final current = ref.watch(securityProvider).value?.isTransactionLockEnabled ?? false;
                        ref.read(securityProvider.notifier).toggleTransactionLock(!current);
                      },
                    ),
                    Divider(height: 24, color: cardBorder.withOpacity(0.6)),
                    Text('مدة قفل التطبيق التلقائي',
                        style: TextStyle(fontSize: 13, color: textSub)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SessionChip(
                          label: 'أبداً',
                          minutes: -1,
                          currentValue: settings.sessionTimeoutMinutes,
                          onSelected: (val) =>
                              ref.read(settingsProvider.notifier).setSessionTimeout(val),
                          activeColor: AppColors.primary,
                          isDark: isDark,
                          cardBorder: cardBorder,
                          textSub: textSub,
                        ),
                        _SessionChip(
                          label: 'فوراً',
                          minutes: 0,
                          currentValue: settings.sessionTimeoutMinutes,
                          onSelected: (val) =>
                              ref.read(settingsProvider.notifier).setSessionTimeout(val),
                          activeColor: rose,
                          isDark: isDark,
                          cardBorder: cardBorder,
                          textSub: textSub,
                        ),
                        _SessionChip(
                          label: '1 دقيقة',
                          minutes: 1,
                          currentValue: settings.sessionTimeoutMinutes,
                          onSelected: (val) =>
                              ref.read(settingsProvider.notifier).setSessionTimeout(val),
                          activeColor: gold,
                          isDark: isDark,
                          cardBorder: cardBorder,
                          textSub: textSub,
                        ),
                        _SessionChip(
                          label: '5 دقائق',
                          minutes: 5,
                          currentValue: settings.sessionTimeoutMinutes,
                          onSelected: (val) =>
                              ref.read(settingsProvider.notifier).setSessionTimeout(val),
                          activeColor: emerald,
                          isDark: isDark,
                          cardBorder: cardBorder,
                          textSub: textSub,
                        ),
                        _SessionChip(
                          label: '15 دقيقة',
                          minutes: 15,
                          currentValue: settings.sessionTimeoutMinutes,
                          onSelected: (val) =>
                              ref.read(settingsProvider.notifier).setSessionTimeout(val),
                          activeColor: emerald,
                          isDark: isDark,
                          cardBorder: cardBorder,
                          textSub: textSub,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.navyLight
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: textHint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              settings.sessionTimeoutMinutes == -1
                                  ? 'لن يتم قفل التطبيق تلقائياً أبداً.'
                                  : settings.sessionTimeoutMinutes == 0
                                      ? 'سيتم قفل التطبيق فور خروجك منه مباشرة.'
                                      : 'لن يُطلب منك الرمز إذا عدت للتطبيق خلال ${settings.sessionTimeoutMinutes} دقائق من خروجك.',
                              style: TextStyle(fontSize: 11, color: textSub, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ==================== 3. إعدادات التذكير ====================
            _buildAnimatedSection(
              index: 2,
              child: _SectionCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                title: 'إعدادات التذكير بالديون',
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFFF59E0B),
                textMain: textMain,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gold.withOpacity(0.08), gold.withOpacity(0.02)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gold.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: gold, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('التذكير قبل',
                                    style: TextStyle(fontSize: 12, color: textSub)),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(fontFamily: 'Cairo', color: textMain),
                                    children: [
                                      TextSpan(
                                        text: '${settings.reminderDaysBefore} ',
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: gold),
                                      ),
                                      TextSpan(
                                        text: settings.reminderDaysBefore == 1
                                            ? 'يوم'
                                            : 'أيام',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textMain),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: gold,
                        inactiveTrackColor: cardBorder,
                        thumbColor: gold,
                        overlayColor: gold.withOpacity(0.15),
                        valueIndicatorColor: gold,
                        valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        trackHeight: 5,
                        thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: settings.reminderDaysBefore.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '${settings.reminderDaysBefore} أيام',
                        onChanged: (v) {
                          ref.read(settingsProvider.notifier).setReminderDays(v.toInt());
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1 يوم',
                              style: TextStyle(fontSize: 10, color: textHint)),
                          Text('30 يوم',
                              style: TextStyle(fontSize: 10, color: textHint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ==================== 4. إعدادات المخزون ====================
            _buildAnimatedSection(
              index: 3,
              child: _SectionCard(
                cardBg: cardBg,
                cardBorder: cardBorder,
                title: 'طريقة تقييم المخزون',
                icon: Icons.inventory_2_rounded,
                iconColor: emerald,
                textMain: textMain,
                child: Column(
                  children: [
                    _ValuationCard(
                      isDark: isDark,
                      isSelected: settings.valuationMethod == 'WAC',
                      title: 'المتوسط المرجح (WAC)',
                      icon: Icons.balance_rounded,
                      description:
                      'يتم حساب متوسط تكلفة جميع الوحدات بغض النظر عن تاريخ الشراء.',
                      hint: '✅ مناسب لمعظم الأنشطة التجارية العامة',
                      accentColor: sky,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textMain: textMain,
                      textSub: textSub,
                      onTap: () =>
                          ref.read(settingsProvider.notifier).setValuationMethod('WAC'),
                    ),
                    const SizedBox(height: 10),
                    _ValuationCard(
                      isDark: isDark,
                      isSelected: settings.valuationMethod == 'FIFO',
                      title: 'الأول فالأول (FIFO)',
                      icon: Icons.sort_rounded,
                      description:
                      'يفترض أن الوحدات الأقدم تُباع أولاً قبل الأحدث.',
                      hint: '✅ مثالي للمنتجات ذات الصلاحية أو سريعة التلف',
                      accentColor: const Color(0xFFF59E0B),
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textMain: textMain,
                      textSub: textSub,
                      onTap: () =>
                          ref.read(settingsProvider.notifier).setValuationMethod('FIFO'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ==================== معلومات التطبيق ====================
            _buildAnimatedSection(
              index: 4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warehouse_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المخازن الذكي',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textMain)),
                          const SizedBox(height: 2),
                          Text('الإصدار 1.0.0',
                              style: TextStyle(fontSize: 11, color: textHint)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: emerald.withOpacity(0.25)),
                      ),
                      child: Text('محدّث',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: emerald)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: c),
      ),
      child: child,
    );
  }
}

// ==============================================================================
//  Widgets مساعدة (مضمنة في نفس الملف - غير مكررة)
// ==============================================================================

class _SectionCard extends StatelessWidget {
  final Color cardBg, cardBorder, textMain, iconColor;
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.cardBg,
    required this.cardBorder,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.textMain,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withOpacity(0.15),
                        iconColor.withOpacity(0.05)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: iconColor.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cardBorder.withOpacity(0.6)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor, textMain, textSub;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textMain,
    required this.textSub,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: textSub),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedThemeSwitch extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedThemeSwitch({
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isDark ? AppColors.info : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        width: 56,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.blue.shade900, Colors.blue.shade700]
                : [Colors.amber.shade300, Colors.amber.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: isDark ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                )
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  key: ValueKey(isDark),
                  size: 14,
                  color: activeColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  final String label;
  final int minutes;
  final int currentValue;
  final Function(int) onSelected;
  final Color activeColor;
  final bool isDark;
  final Color cardBorder;
  final Color textSub;

  const _SessionChip({
    required this.label,
    required this.minutes,
    required this.currentValue,
    required this.onSelected,
    required this.activeColor,
    required this.isDark,
    required this.cardBorder,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = minutes == currentValue;
    return GestureDetector(
      onTap: () => onSelected(minutes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : textSub,
          ),
        ),
      ),
    );
  }
}

class _ValuationCard extends StatelessWidget {
  final bool isDark, isSelected;
  final String title, description, hint;
  final IconData icon;
  final Color accentColor, cardBg, cardBorder, textMain, textSub;
  final VoidCallback onTap;

  const _ValuationCard({
    required this.isDark,
    required this.isSelected,
    required this.title,
    required this.description,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.cardBg,
    required this.cardBorder,
    required this.textMain,
    required this.textSub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? accentColor.withOpacity(isDark ? 0.08 : 0.04)
        : (isDark ? AppColors.navyLight : AppColors.lightSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor.withOpacity(0.4) : cardBorder.withOpacity(0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2, left: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.7)])
                      : null,
                  border: Border.all(
                    color: isSelected ? accentColor : cardBorder,
                    width: isSelected ? 0 : 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16,
                            color: isSelected ? accentColor : textSub),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accentColor : textMain,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'مُفعّل',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: textSub, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withOpacity(0.08)
                            : (isDark ? AppColors.navy : AppColors.lightSurface),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? accentColor : textSub,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}