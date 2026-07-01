// lib/modules/dashboard/views/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../products/views/products_list_screen.dart';
import '../../suppliers/views/suppliers_screen.dart';
import '../../customers/views/customers_screen.dart';
import '../providers/dashboard_provider.dart'; // 🚀 استيراد المزود

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with TickerProviderStateMixin {
  String _greeting = '';
  String _currentDate = '';
// ===== ألوان متكيفة =====
  bool get _dark => ref.watch(themeModeProvider) == ThemeMode.dark;
  Color get _bg => _dark ? AppColors.navy : AppColors.lightSurface;
  Color get _cardBg => _dark ? AppColors.navyCard : Colors.white;
  Color get _border => _dark ? AppColors.navyBorder : Colors.grey.shade300;

// ✅ النصوص المحسّنة
  Color get _textMain => _dark ? AppColors.textPrimary : AppColors.navy;
  Color get _textSub => _dark ? AppColors.textSecondary : Colors.grey.shade700; // ✅ داكن بدلاً من رمادي فاتح
  Color get _textHint => _dark ? AppColors.textHint : Colors.grey.shade600; // ✅ داكن بدلاً من رمادي باهت

// ألوان إضافية
  Color get _shadowColor => _dark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);

  @override
  void initState() {
    super.initState();
    _updateGreeting();
  }

  // هذه دالة تعتمد على الوقت المحلي، لذلك من المنطقي بقاؤها في الـ UI
  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'صباح الخير ☀️';
    } else if (hour < 18) {
      _greeting = 'مساء الخير 🌤️';
    } else {
      _greeting = 'مساء الخير 🌙';
    }
    _currentDate = DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) {
      // تحديث البيانات عند العودة من شاشة أخرى لضمان تزامن الإحصائيات
      if (mounted) ref.read(dashboardProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 الاستماع لمزود البيانات المعماري
    final asyncData = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary), strokeWidth: 2.5)),
        error: (err, stack) => Center(child: Text('خطأ في تحميل البيانات: $err', style: const TextStyle(color: AppColors.error))),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.read(dashboardProvider.notifier).refresh(),
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildSliverAppBar(data),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildQuickActions(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(data),
                    const SizedBox(height: 16),
                    _buildSalesSection(data),
                    const SizedBox(height: 16),
                    _buildAlertsSection(data),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(DashboardData data) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      floating: false,
      backgroundColor: _dark ? AppColors.navy : AppColors.navy,
      foregroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 22),
          onPressed: () => ref.read(dashboardProvider.notifier).refreshDashboardSummary(),
          tooltip: 'تحديث البيانات',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _dark
                  ? [AppColors.navy, AppColors.navyMedium, AppColors.navyLight]
                  : [AppColors.navy, AppColors.navyMedium, AppColors.navy],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.dashboard_rounded, color: AppColors.navy, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting, style: TextStyle(color: AppColors.primary.withOpacity(0.8), fontSize: 13)),
                            const SizedBox(height: 3),
                            const Text('مرحباً بعودتك', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => ref.read(dashboardProvider.notifier).refreshDashboardSummary(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.primary.withOpacity(0.6), size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_currentDate, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11), overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.08)]),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${((data.monthSales / (data.totalInventoryValue + 1)) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return _animatedSection(
      index: 0,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            _quickAction('المنتجات', Icons.inventory_2_rounded, AppColors.info, () => _navigateTo(const ProductsListScreen())),
            const SizedBox(width: 8),
            _quickAction('الموردين', Icons.local_shipping_rounded, AppColors.secondary, () => _navigateTo(const SuppliersScreen())),
            const SizedBox(width: 8),
            _quickAction('العملاء', Icons.people_rounded, AppColors.success, () => _navigateTo(const CustomersScreen())),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(DashboardData data) {
    return _animatedSection(
      index: 1,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _statCard('المنتجات', '${data.totalProducts}', Icons.inventory_2_rounded, AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('الموردين', '${data.totalSuppliers}', Icons.local_shipping_rounded, AppColors.secondary)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _statCard('العملاء', '${data.totalCustomers}', Icons.people_rounded, AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('قيمة المخزون', NumberFormat('#,##0', 'en').format(data.totalInventoryValue), Icons.account_balance_wallet_rounded, AppColors.primary)),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: color.withOpacity(_dark ? 0.06 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _textHint),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _textMain)),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(title, style: TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSection(DashboardData data) {
    return _animatedSection(
      index: 2,
      child: () {
        final todayTarget = data.monthSales > 0 ? data.monthSales / 30 : 1;
        final todayProgress = (data.todaySales / todayTarget).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('المبيعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)), // ✅
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _dark ? [AppColors.navy, AppColors.navyMedium] : [AppColors.lightSurface, AppColors.lightSurface],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.today_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('مبيعات اليوم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSub)), // ✅
                        ]),
                        Text(
                          '${NumberFormat('#,##0', 'en').format(data.todaySales)} ريال',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: todayProgress),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (_, val, __) => LinearProgressIndicator(
                          value: val, minHeight: 8,
                          backgroundColor: _dark ? Colors.white.withOpacity(0.06) : AppColors.navyBorder,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${(todayProgress * 100).toStringAsFixed(0)}% من المتوسط اليومي', style: TextStyle(fontSize: 10, color: _textHint)), // ✅
                        Text('المتوسط: ${NumberFormat('#,##0', 'en').format(todayTarget)}', style: TextStyle(fontSize: 10, color: _textHint)), // ✅
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _dark ? [AppColors.success.withOpacity(0.08), AppColors.success.withOpacity(0.02)] : [AppColors.success.withOpacity(0.08), AppColors.success.withOpacity(0.02)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.success),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مبيعات الشهر', style: TextStyle(fontSize: 12, color: _textSub)), // ✅
                          const SizedBox(height: 4),
                          Text(
                            '${NumberFormat('#,##0', 'en').format(data.monthSales)} ريال',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up_rounded, size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('هذا الشهر', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }(),
    );
  }

  Widget _buildAlertsSection(DashboardData data) {
    return _animatedSection(
      index: 3,
      child: () {
        final hasAlerts = data.lowStockCount > 0 || data.expiredCount > 0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: hasAlerts ? AppColors.warning.withOpacity(0.3) : _border),
            boxShadow: [BoxShadow(color: (hasAlerts ? AppColors.warning : Colors.black).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [(hasAlerts ? AppColors.warning : AppColors.success).withOpacity(0.15), (hasAlerts ? AppColors.warning : AppColors.success).withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: hasAlerts ? AppColors.warning : AppColors.success, size: 18),
                ),
                const SizedBox(width: 10),
                Text('التنبيهات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textMain)), // ✅
                const Spacer(),
                if (hasAlerts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withOpacity(0.25))),
                    child: Text('${data.lowStockCount + data.expiredCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error)),
                  ),
              ]),
              const SizedBox(height: 14),
              if (!hasAlerts)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(_dark ? 0.06 : 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.thumb_up_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('كل شيء على ما يرام! 🎉', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textMain)), // ✅
                          const SizedBox(height: 2),
                          Text('لا توجد تنبيهات حالياً', style: TextStyle(fontSize: 11, color: _textSub)), // ✅
                        ],
                      ),
                    ),
                  ]),
                ),
              if (data.lowStockCount > 0)
                _alertTile(
                  icon: Icons.inventory_rounded, color: AppColors.warning,
                  title: 'مخزون منخفض', subtitle: '${data.lowStockCount} منتج يحتاج إعادة طلب',
                  onTap: () => _navigateTo(const ProductsListScreen()),
                ),
              if (data.lowStockCount > 0 && data.expiredCount > 0) const SizedBox(height: 8),
              if (data.expiredCount > 0)
                _alertTile(
                  icon: Icons.event_busy_rounded, color: AppColors.error,
                  title: 'منتهي الصلاحية', subtitle: '${data.expiredCount} منتج منتهي الصلاحية',
                  onTap: () => _navigateTo(const ProductsListScreen()),
                ),
            ],
          ),
        );
      }(),
    );
  }

  Widget _alertTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(_dark ? 0.08 : 0.05), color.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: _textSub)), // ✅
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }

  Widget _animatedSection({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 120)),
      curve: Curves.easeOutCubic,
      builder: (_, value, c) => Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: Opacity(opacity: value, child: c),
      ),
      child: child,
    );
  }
}