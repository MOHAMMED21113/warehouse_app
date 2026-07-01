// lib/modules/reports/views/expired_products_screen.dart
// 🆕 تصميم كحلي + ذهبي — محول إلى Riverpod مع AppThemeColors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/expired_products_provider.dart';

class ExpiredProductsScreen extends ConsumerStatefulWidget {
  const ExpiredProductsScreen({super.key});
  @override
  ConsumerState<ExpiredProductsScreen> createState() => _ExpiredProductsScreenState();
}

class _ExpiredProductsScreenState extends ConsumerState<ExpiredProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getDaysLeft(String? expiryDate) {
    if (expiryDate == null) return '';
    try {
      final expiry = DateTime.parse(expiryDate);
      final now = DateTime.now();
      final daysLeft = expiry.difference(now).inDays;
      if (daysLeft < 0) return 'منتهية منذ ${-daysLeft} يوم';
      if (daysLeft == 0) return 'تنتهي اليوم';
      return 'متبقي $daysLeft يوم';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(expiredProductsProvider);
    final colors = _colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg,
        foregroundColor: AppColors.primary,
        elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('تنبيهات الصلاحية', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(children: [
            Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.error.withOpacity(0.6), AppColors.navy]))),
            asyncState.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (state) => TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.primary.withOpacity(0.5),
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'منتهية (${state.expiredProducts.length})'),
                  Tab(text: 'قاربت (${state.expiringSoonProducts.length})'),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.error)),
        error: (err, _) => Center(child: Text('خطأ: $err', style: const TextStyle(color: AppColors.error))),
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _buildProductList(colors, state.expiredProducts, isExpired: true),
            _buildProductList(colors, state.expiringSoonProducts, isExpired: false),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(AppThemeColors colors, List<Map<String, dynamic>> products, {required bool isExpired}) {
    if (products.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, size: 60, color: colors.textHint),
          const SizedBox(height: 16),
          Text(isExpired ? 'لا توجد منتجات منتهية الصلاحية' : 'لا توجد منتجات قاربت على الانتهاء', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textMain)),
          const SizedBox(height: 4),
          Text('كل شيء على ما يرام ✅', style: TextStyle(fontSize: 12, color: colors.textHint)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(expiredProductsProvider),
      color: AppColors.error,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final daysLeft = _getDaysLeft(product['expiry_date']);
          final color = isExpired ? AppColors.error : AppColors.warning;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(colors.scaffoldBg == AppColors.navy ? 0.15 : 0.08), borderRadius: BorderRadius.circular(14)), child: Icon(isExpired ? Icons.cancel_rounded : Icons.warning_rounded, color: color, size: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(product['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textMain)),
                    const SizedBox(height: 4),
                    Text('تاريخ الصلاحية: ${product['expiry_date']?.toString().substring(0, 10) ?? ''}', style: TextStyle(fontSize: 11, color: colors.textSub)),
                    if (product['current_stock'] != null) Text('المخزون: ${product['current_stock']} ${product['unit_symbol'] ?? product['unit_name'] ?? ''}', style: TextStyle(fontSize: 11, color: colors.textSub)),
                  ]),
                ),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(colors.scaffoldBg == AppColors.navy ? 0.15 : 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2), width: 0.5)), child: Text(daysLeft, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
              ]),
            ),
          );
        },
      ),
    );
  }
}