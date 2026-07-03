import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/global_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/current_user.dart';
import '../../../core/constants/app_permissions.dart';

// Screens
import '../../../modules/dashboard/views/dashboard_screen.dart';
import '../../../modules/groups/views/groups_screen.dart';
import '../../../modules/subcategories/views/subcategories_screen.dart';
import '../../../modules/products/views/products_list_screen.dart';
import '../../../modules/suppliers/views/suppliers_screen.dart';
import '../../../modules/customers/views/customers_screen.dart';
import '../../../modules/warehouses/views/warehouses_screen.dart';
import '../../../modules/units/views/units_screen.dart';
import '../../../modules/invoices/views/purchase_invoice_screen.dart';
import '../../../modules/invoices/views/sales_invoice_screen.dart';
import '../../../modules/invoices/views/invoices_list_screen.dart';
import '../../../modules/reports/views/expired_products_screen.dart';
import '../../../modules/reports/views/backup_screen.dart';
import '../../../modules/reports/views/profit_reports_screen.dart';
import '../../../modules/products/views/barcode_scanner_screen.dart';
import '../../../modules/users/views/users_screen.dart';
import '../../../modules/accounting/views/debtors_screen.dart';
import '../../../modules/accounting/views/creditors_screen.dart';
import '../../ai_chat/views/ai_chat_screen.dart';
import '../../accounting/views/treasury_screen.dart';
import '../../../modules/settings/views/settings_screen.dart';
import '../../accounting/views/financial_vouchers_screen.dart';
import '../../invoices/views/due_reminders_screen.dart';
import '../../returns/views/purchase_return_screen.dart';
import '../../returns/views/returns_list_screen.dart';
import '../../returns/views/sales_return_screen.dart';
import '../../settings/views/shop_settings_screen.dart';
import '../../../modules/tasks/views/tasks_screen.dart';
import '../../warehouses/views/damaged_products_screen.dart';
import '../../auth/views/login_screen.dart';

// 🚀 الشاشات المؤسسية الجديدة (Enterprise ERP Screens)
import '../../loans/views/loans_screen.dart';
import '../../reports/views/aging_report_screen.dart';
import '../../reports/views/cash_flow_screen.dart';
import '../../reports/views/balance_sheet_screen.dart';
import '../../inventory/views/inventory_count_screen.dart';
import '../../settings/views/audit_log_screen.dart';
import '../../dashboard/views/executive_dashboard_screen.dart';

// 🚀 استدعاء الـ Provider الخاص بالإحصائيات
import '../providers/main_menu_provider.dart';

class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});
  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  int _currentTab = 0;

  static const Color _purchaseAccent = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    // 🚀 تحديث ValueNotifier فقط دون إعادة بناء شجرة الـ Widgets بالكامل كل ثانية
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) _nowNotifier.value = DateTime.now(); },
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _nowNotifier.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  bool _hasPerm(String perm) {
    final user = ref.watch(currentUserProvider);
    return user?.hasPermission(perm) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final scaffoldBg = dark ? AppColors.navy : const Color(0xFFF1F5F9);

    // 🚀 قراءة الإحصائيات عبر Riverpod 100%
    final statsAsyncValue = ref.watch(dashboardStatsProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: dark ? AppColors.navyMedium : AppColors.navy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'المخازن الذكية',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            tooltip: 'المساعد الذكي',
            onPressed: () => _go(const AiChatScreen()),
          ),
        ],
      ),
      drawer: _buildDrawer(dark),
      floatingActionButton: _hasPerm(AppPermissions.salesInvoice) ? SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
          onPressed: () => _go(const SalesInvoiceScreen()),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.navy,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: const Icon(Icons.point_of_sale_rounded, size: 28),
        ),
      ) : const SizedBox(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildNotchedBottomBar(dark),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          // 🚀 التحديث بالسحب يتم عن طريق عمل ريفريش للـ Provider
          onRefresh: () => ref.refresh(dashboardStatsProvider.future),
          color: AppColors.primary,
          backgroundColor: dark ? AppColors.navyCard : Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 🚀 تمرير بيانات الـ AsyncValue للهيدر
              SliverToBoxAdapter(child: _buildHeroHeader(dark, statsAsyncValue)),
              SliverToBoxAdapter(child: _buildQuickActions(dark)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _sectionLabel('⚡ العمليات السريعة', dark),
                    const SizedBox(height: 12),
                    _buildMainGrid(dark),
                    const SizedBox(height: 24),

                    _sectionLabel(' الحسابات المالية', dark),
                    const SizedBox(height: 12),
                    _buildAccountsGrid(dark),
                    const SizedBox(height: 24),

                    _sectionLabel(' أدوات وتقارير', dark),
                    const SizedBox(height: 12),
                    _buildToolsGrid(dark),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotchedBottomBar(bool dark) {
    final Color barBg = dark ? AppColors.navyMedium : AppColors.navy;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          if (!dark) BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: BottomAppBar(
        color: barBg,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        elevation: 0,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _navItem(index: 0, icon: Icons.home_rounded, label: 'الرئيسية', activeColor: AppColors.primary, onTap: () => setState(() => _currentTab = 0))),
              const SizedBox(width: 80),
              Expanded(
                child: _hasPerm(AppPermissions.tasks) ? _navItem(
                  index: 1,
                  icon: Icons.task_rounded,
                  label: 'المهام',
                  activeColor: const Color(0xFFA78BFA),
                  onTap: () {
                    setState(() => _currentTab = 1);
                    _go(const TasksScreen());
                  },
                ) : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({required int index, required IconData icon, required String label, required Color activeColor, required VoidCallback onTap}) {
    final bool active = _currentTab == index;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(horizontal: active ? 20 : 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? activeColor.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: active ? activeColor : Colors.white54, size: active ? 24 : 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? activeColor : Colors.white54,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool dark) {
    final List<Widget> chips = [];
    if (_hasPerm(AppPermissions.salesInvoice)) {
      chips.add(_quickChip(Icons.sell_rounded, 'فواتير البيع', AppColors.success, dark, () => _go(const InvoicesListScreen(type: 'sales'))));
    }
    if (_hasPerm(AppPermissions.purchaseInvoice)) {
      chips.add(_quickChip(Icons.local_shipping_rounded, 'فواتير الشراء', _purchaseAccent, dark, () => _go(const InvoicesListScreen(type: 'purchase'))));
    }
    if (_hasPerm(AppPermissions.returnsList)) {
      chips.add(_quickChip(Icons.assignment_return_rounded, 'المرتجعات', const Color(0xFFF97316), dark, () => _go(const ReturnsListScreen())));
    }
    if (_hasPerm(AppPermissions.dueReminders)) {
      chips.add(_quickChip(Icons.alarm_rounded, 'تذكير الديون', AppColors.warning, dark, () => _go(const DueRemindersScreen())));
    }
    if (_hasPerm(AppPermissions.barcodeScanner)) {
      chips.add(_quickChip(Icons.qr_code_scanner_rounded, 'باركود', const Color(0xFFA78BFA), dark, () async {
        final s = await Permission.camera.request();
        if (s.isGranted) _go(BarcodeScannerScreen(onBarcodeScanned: (_) {}));
      }));
    }

    if (chips.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: chips,
        ),
      ),
    );
  }

  Widget _quickChip(IconData icon, String label, Color color, bool dark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? color.withOpacity(0.1) : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool dark, AsyncValue<DashboardStats> statsAsyncValue) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.navyMedium : AppColors.navy,
        border: const Border(bottom: BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          ValueListenableBuilder<DateTime>(
            valueListenable: _nowNotifier,
            builder: (context, now, _) {
              final timeStr = DateFormat('hh:mm a', 'ar').format(now);
              final dateStr = DateFormat('EEEE، d MMMM y', 'ar').format(now);
              final hour = now.hour;
              final String greeting = hour >= 5 && hour < 12 ? 'صباح الخير ☀️' : hour < 18 ? 'مساء الخير 🌤️' : 'مساء النور 🌙';

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              CurrentUser.fullName ?? 'المدير',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(gradient: AppGradients.goldGradient, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                CurrentUser.role == 'admin' ? '👑 مدير النظام' : '👤 موظف',
                                style: const TextStyle(color: AppColors.navy, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.navyLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2.5),
                            ),
                            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                            ),
                            child: Text(
                              timeStr,
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 12),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // 🚀 التعامل مع حالة التحميل والبيانات من Riverpod (لا يوجد setState بعد الآن)
          statsAsyncValue.when(
            loading: () => Row(
              children: [
                _heroStat(Icons.trending_up_rounded, 'مبيعات اليوم', '...', AppColors.success),
                const SizedBox(width: 10),
                _heroStat(Icons.account_balance_rounded, 'الخزينة', '...', AppColors.primary),
                const SizedBox(width: 10),
                _heroStat(Icons.money_off_rounded, 'المدينون', '...', AppColors.error),
              ],
            ),
            error: (err, stack) => Center(child: Text('خطأ في جلب البيانات', style: const TextStyle(color: AppColors.error))),
            data: (stats) => Row(
              children: [
                _heroStat(Icons.trending_up_rounded, 'مبيعات اليوم', _formatNumber(stats.todaySales), AppColors.success),
                const SizedBox(width: 10),
                _heroStat(Icons.account_balance_rounded, 'الخزينة', _formatNumber(stats.treasuryBalance), AppColors.primary),
                const SizedBox(width: 10),
                _heroStat(Icons.money_off_rounded, 'المدينون', _formatNumber(stats.debtorsTotal), AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == 0) return '0';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    // Format with commas for standard numbers
    return NumberFormat('#,##0', 'en_US').format(value);
  }

  Widget _heroStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 16),
                if (value == '...') SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
              ],
            ),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, bool dark) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(gradient: AppGradients.goldGradient, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: dark ? AppColors.textPrimary : AppColors.navy, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildMainGrid(bool dark) {
    final Color cardBg = dark ? AppColors.navyCard : Colors.white;
    final Color cardBorder = dark ? AppColors.navyBorder : const Color(0xFFE2E8F0);

    final allItems = [
      _GridItem(Icons.point_of_sale_rounded, 'نقطة البيع', 'إنشاء فاتورة بيع جديدة', AppColors.success, 'sales', () => _go(const SalesInvoiceScreen())),
      _GridItem(Icons.shopping_cart_rounded, 'فاتورة شراء', 'تسجيل بضاعة واردة', _purchaseAccent, 'purchase', () => _go(const PurchaseInvoiceScreen())),
      _GridItem(Icons.inventory_2_rounded, 'المنتجات', 'إدارة المخزون والأصناف', const Color(0xFF60A5FA), 'products', () => _go(const ProductsListScreen())),
      _GridItem(Icons.people_rounded, 'العملاء', 'سجل العملاء والحسابات', const Color(0xFF34D399), 'customers', () => _go(const CustomersScreen())),
      _GridItem(Icons.undo_rounded, 'مرتجع مبيعات', 'إرجاع منتجات من عميل', const Color(0xFFF97316), 'sales_returns', () => _go(const SalesReturnScreen())),
      _GridItem(Icons.replay_rounded, 'مرتجع مشتريات', 'إرجاع منتجات لمورد', const Color(0xFF10B981), 'purchase_returns', () => _go(const PurchaseReturnScreen())),
    ];

    final items = allItems.where((item) => _hasPerm(item.permission)).toList();

    if (items.isEmpty) return const SizedBox();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 80)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _premiumCard(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            accentColor: item.color,
            cardBg: cardBg,
            cardBorder: cardBorder,
            dark: dark,
            onTap: item.onTap,
          ),
        );
      },
    );
  }

  Widget _buildAccountsGrid(bool dark) {
    final Color cardBg = dark ? AppColors.navyCard : Colors.white;
    final Color cardBorder = dark ? AppColors.navyBorder : const Color(0xFFE2E8F0);

    final allItems = [
      _GridItem(Icons.account_balance_rounded, 'الخزينة', '', AppColors.primary, 'treasury', () => _go(const TreasuryScreen())),
      _GridItem(Icons.receipt_long_rounded, 'السندات', '', const Color(0xFF818CF8), 'financial_vouchers', () => _go(const FinancialVouchersScreen())),
      _GridItem(Icons.money_off_rounded, 'المدينون', '', AppColors.error, 'debtors', () => _go(const DebtorsScreen())),
      _GridItem(Icons.savings_rounded, 'الدائنون', '', AppColors.success, 'creditors', () => _go(const CreditorsScreen())),
    ];

    final items = allItems.where((item) => _hasPerm(item.permission)).toList();
    if (items.isEmpty) return const SizedBox();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: items.map((item) => _compactCard(item.icon, item.title, item.color, cardBg, cardBorder, dark, item.onTap)).toList(),
    );
  }

  Widget _buildToolsGrid(bool dark) {
    final Color cardBg = dark ? AppColors.navyCard : Colors.white;
    final Color cardBorder = dark ? AppColors.navyBorder : const Color(0xFFE2E8F0);

    final allItems = [
      _GridItem(Icons.dashboard_rounded, 'لوحة التحكم', '', AppColors.primary, 'dashboard', () => _go(const DashboardScreen())),
      _GridItem(Icons.trending_up_rounded, 'الأرباح', '', AppColors.success, 'profit_reports', () => _go(const ProfitReportsScreen())),
      _GridItem(Icons.qr_code_scanner_rounded, 'باركود', '', const Color(0xFFA78BFA), 'barcode_scanner', () async {
        final s = await Permission.camera.request();
        if (s.isGranted) _go(BarcodeScannerScreen(onBarcodeScanned: (_) {}));
      }),
      _GridItem(Icons.warning_amber_rounded, 'التنبيهات', '', AppColors.warning, 'expired_products', () => _go(const ExpiredProductsScreen())),
      _GridItem(Icons.delete_sweep_rounded, 'سجل التوالف', '', Colors.redAccent, 'damaged_products', () => _go(const DamagedProductsScreen())),
      _GridItem(Icons.cloud_upload_rounded, 'نسخ احتياطي', '', const Color(0xFF60A5FA), 'backup', () => _go(const BackupScreen())),
      _GridItem(Icons.folder_copy_rounded, 'الفواتير', '', const Color(0xFF818CF8), 'invoices_list', _showInvoicesDialog),
    ];

    final items = allItems.where((item) => _hasPerm(item.permission)).toList();
    if (items.isEmpty) return const SizedBox();

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: items.map((item) => _toolCard(item.icon, item.title, item.color, cardBg, cardBorder, dark, item.onTap)).toList(),
    );
  }

  Widget _premiumCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color cardBg,
    required Color cardBorder,
    required bool dark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accentColor.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.3)]),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
                          ),
                          child: Icon(icon, color: accentColor, size: 24),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(color: dark ? AppColors.textPrimary : AppColors.navy, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(subtitle, style: TextStyle(color: dark ? AppColors.textHint : const Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                        Align(alignment: AlignmentDirectional.bottomEnd, child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accentColor.withOpacity(0.6))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactCard(IconData icon, String title, Color accentColor, Color cardBg, Color cardBorder, bool dark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accentColor, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: dark ? AppColors.textPrimary : AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13))),
              Icon(Icons.chevron_right_rounded, color: accentColor.withOpacity(0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolCard(IconData icon, String title, Color accentColor, Color cardBg, Color cardBorder, bool dark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardBorder, width: 1)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.25), width: 1)),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: dark ? AppColors.textPrimary : AppColors.navy, fontWeight: FontWeight.w600, fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(bool dark) {
    final Color bg = dark ? AppColors.navyMedium : const Color(0xFF0F2847);
    return Drawer(
      backgroundColor: bg,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: BoxDecoration(
              color: dark ? AppColors.navy : const Color(0xFF0C1A2E),
              border: const Border(bottom: BorderSide(color: AppColors.primary, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: AppColors.navyLight, shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2.5)),
                  child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
                ),
                const SizedBox(height: 12),
                Text(CurrentUser.fullName ?? 'المدير', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(gradient: AppGradients.goldGradient, borderRadius: BorderRadius.circular(20)),
                  child: Text(CurrentUser.role == 'admin' ? '👑 مدير النظام' : '👤 موظف', style: const TextStyle(color: AppColors.navy, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerGroup('العمليات', Icons.shopping_bag_rounded, [
                  if (_hasPerm(AppPermissions.salesInvoice)) _dItem(Icons.point_of_sale_rounded, 'فاتورة بيع', AppColors.success, () => _go(const SalesInvoiceScreen())),
                  if (_hasPerm(AppPermissions.purchaseInvoice)) _dItem(Icons.shopping_cart_rounded, 'فاتورة شراء', _purchaseAccent, () => _go(const PurchaseInvoiceScreen())),
                  if (_hasPerm(AppPermissions.invoicesList)) _dItem(Icons.folder_copy_rounded, 'سجل الفواتير', const Color(0xFF818CF8), _showInvoicesDialog),
                  if (_hasPerm(AppPermissions.barcodeScanner)) _dItem(Icons.qr_code_scanner_rounded, 'مسح باركود', const Color(0xFFA78BFA), () async {
                    final s = await Permission.camera.request();
                    if (s.isGranted) _go(BarcodeScannerScreen(onBarcodeScanned: (_) {}));
                  }),
                  if (_hasPerm(AppPermissions.salesReturn)) _dItem(Icons.undo_rounded, 'مرتجع مبيعات', const Color(0xFFF97316), () => _go(const SalesReturnScreen())),
                  if (_hasPerm(AppPermissions.purchaseReturn)) _dItem(Icons.replay_rounded, 'مرتجع مشتريات', const Color(0xFF10B981), () => _go(const PurchaseReturnScreen())),
                ]),
                _drawerGroup('الحسابات', Icons.account_balance_wallet_rounded, [
                  _dItem(Icons.account_balance_wallet_outlined, 'سلف العملاء والموردين', const Color(0xFFF59E0B), () => _go(const LoansScreen())),
                  if (_hasPerm(AppPermissions.treasury)) _dItem(Icons.account_balance_rounded, 'الخزينة والصندوق', AppColors.primary, () => _go(const TreasuryScreen())),
                  if (_hasPerm(AppPermissions.returnsList)) _dItem(Icons.swap_horiz_rounded, 'فواتير المرتجعات', const Color(0xFFA78BFA), () => _go(const ReturnsListScreen())),
                  if (_hasPerm(AppPermissions.financialVouchers)) _dItem(Icons.receipt_long_rounded, 'المصروفات والإيرادات', const Color(0xFF818CF8), () => _go(const FinancialVouchersScreen())),
                  if (_hasPerm(AppPermissions.debtors)) _dItem(Icons.money_off_rounded, 'المدينون', AppColors.error, () => _go(const DebtorsScreen())),
                  if (_hasPerm(AppPermissions.creditors)) _dItem(Icons.savings_rounded, 'الدائنون', AppColors.success, () => _go(const CreditorsScreen())),
                  if (_hasPerm(AppPermissions.customers)) _dItem(Icons.people_rounded, 'العملاء', const Color(0xFF34D399), () => _go(const CustomersScreen())),
                  if (_hasPerm(AppPermissions.suppliers)) _dItem(Icons.local_shipping_rounded, 'الموردون', Colors.white54, () => _go(const SuppliersScreen())),
                ]),
                _drawerGroup('الإدارة', Icons.admin_panel_settings_rounded, [
                  _dItem(Icons.fact_check_rounded, 'الجرد الفعلي وتسوية المخزون', const Color(0xFF34D399), () => _go(const InventoryCountScreen())),
                  if (_hasPerm(AppPermissions.productsList)) _dItem(Icons.inventory_2_rounded, 'المنتجات', const Color(0xFF60A5FA), () => _go(const ProductsListScreen())),
                  if (_hasPerm(AppPermissions.categories)) _dItem(Icons.folder_rounded, 'المجموعات', AppColors.primary, () => _go(const GroupsScreen())),
                  if (_hasPerm(AppPermissions.subcategories)) _dItem(Icons.category_rounded, 'الأصناف', const Color(0xFF818CF8), () => _go(const SubcategoriesScreen())),
                  if (_hasPerm(AppPermissions.warehouses)) _dItem(Icons.warehouse_rounded, 'المستودعات', const Color(0xFF06B6D4), () => _go(const WarehousesScreen())),
                  if (_hasPerm(AppPermissions.units)) _dItem(Icons.straighten_rounded, 'وحدات القياس', AppColors.warning, () => _go(const UnitsScreen())),
                ]),
                _drawerGroup('التقارير المالية والرقابية', Icons.assessment_rounded, [
                  _dItem(Icons.pie_chart_outline_rounded, 'لوحة التحكم التنفيذية (KPIs)', const Color(0xFF10B981), () => _go(const ExecutiveDashboardScreen())),
                  _dItem(Icons.history_toggle_off_rounded, 'أعمار الذمم (Aging Report)', const Color(0xFFF97316), () => _go(const AgingReportScreen())),
                  _dItem(Icons.waterfall_chart_rounded, 'قائمة التدفقات النقدية', const Color(0xFF60A5FA), () => _go(const CashFlowScreen())),
                  _dItem(Icons.balance_rounded, 'الميزانية العمومية', const Color(0xFFA78BFA), () => _go(const BalanceSheetScreen())),
                  if (_hasPerm(AppPermissions.profitReports)) _dItem(Icons.trending_up_rounded, 'تحليل الأرباح', AppColors.success, () => _go(const ProfitReportsScreen())),
                  if (_hasPerm(AppPermissions.dashboard)) _dItem(Icons.dashboard_rounded, 'لوحة التحكم السريعة', AppColors.primary, () => _go(const DashboardScreen())),
                  if (_hasPerm(AppPermissions.backup)) _dItem(Icons.cloud_upload_rounded, 'نسخ احتياطي', const Color(0xFF60A5FA), () => _go(const BackupScreen())),
                  if (_hasPerm(AppPermissions.expiredProducts)) _dItem(Icons.warning_amber_rounded, 'التنبيهات', AppColors.error, () => _go(const ExpiredProductsScreen())),
                  if (_hasPerm(AppPermissions.damagedProducts)) _dItem(Icons.delete_sweep_rounded, 'سجل التوالف', Colors.redAccent, () => _go(const DamagedProductsScreen())),
                  if (_hasPerm(AppPermissions.dueReminders)) _dItem(Icons.alarm_rounded, 'تذكير الديون', AppColors.warning, () => _go(const DueRemindersScreen())),
                ]),
                _drawerGroup('الإعدادات والأمان', Icons.settings_rounded, [
                  _dItem(Icons.security_rounded, 'سجل الرقابة والتدقيق (Audit Log)', const Color(0xFFEF4444), () => _go(const AuditLogScreen())),
                  if (_hasPerm(AppPermissions.users)) _dItem(Icons.group_rounded, 'المستخدمين', const Color(0xFFA78BFA), () => _go(const UsersScreen())),
                  if (_hasPerm(AppPermissions.settings)) _dItem(Icons.tune_rounded, 'الإعدادات العامة', AppColors.primary, () => _go(const SettingsScreen())),
                  if (_hasPerm(AppPermissions.shopSettings)) _dItem(Icons.store_rounded, 'بيانات المحل', const Color(0xFF06B6D4), () => _go(const ShopSettingsScreen())),
                ]),
              ],
            ),
          ),
          if (ref.watch(usersProvider).valueOrNull?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _drawerGroup(String title, IconData icon, List<Widget> items) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
          ]),
        ),
        ...items,
        const Divider(height: 8, color: Color(0xFF1E3050)),
      ],
    );
  }

  Widget _dItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.25), width: 1)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
      dense: true,
      horizontalTitleGap: 8,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showInvoicesDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.navyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر نوع الفاتورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              _dialogOpt(Icons.sell_rounded, 'فواتير البيع', AppColors.success, () {
                Navigator.pop(context);
                _go(const InvoicesListScreen(type: 'sales'));
              }),
              const SizedBox(height: 12),
              _dialogOpt(Icons.shopping_cart_rounded, 'فواتير الشراء', _purchaseAccent, () {
                Navigator.pop(context);
                _go(const InvoicesListScreen(type: 'purchase'));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogOpt(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.35))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: AppColors.primary))),
          ElevatedButton(
            onPressed: () {
              ref.read(securityProvider.notifier).logout(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}

class _GridItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String permission;
  final VoidCallback onTap;
  _GridItem(this.icon, this.title, this.subtitle, this.color, this.permission, this.onTap);
}