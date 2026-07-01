// lib/modules/accounting/views/debtors_screen.dart
// ✅ تم تحويل تصميمك الفاخر بدقة 100% ليعمل مع Riverpod + ألوان كحلية مريحة للعين في الوضع الداكن
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/debtors_provider.dart';
import 'account_statement_screen.dart';

class DebtorsScreen extends ConsumerStatefulWidget {
  const DebtorsScreen({super.key});
  @override
  ConsumerState<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends ConsumerState<DebtorsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  // ===== ألوان =====
  static const _gold = Color(0xFFD4AF37);
  static const _emerald = Color(0xFF10B981);
  static const _emeraldDark = Color(0xFF059669);
  static const _sky = Color(0xFF3B82F6);
  static const _skyDark = Color(0xFF2563EB);
  static const _violet = Color(0xFF8B5CF6);
  static const _violetDark = Color(0xFF7C3AED);
  static const _rose = Color(0xFFF43F5E);
  // تم تفتيح اللون الأسود ليصبح كحلي أنيق ومريح (Navy Blue)
  static const _navyDeep = Color(0xFF16243A);

  // ألوان خاصة بالمدينين (أحمر)
  static const _debtAccent = Color(0xFFEF4444);
  static const _debtAccentDark = Color(0xFFDC2626);

  bool get _dark => ref.watch(themeModeProvider) == ThemeMode.dark;
  // تم ضبط ألوان الخلفيات لتكون مريحة في الوضع الداكن
  Color get _bg => _dark ? const Color(0xFF101B2E) : const Color(0xFFF0F4F8);
  Color get _cardBg => _dark ? const Color(0xFF1E2D43) : Colors.white;
  Color get _border => _dark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0);
  Color get _textMain => _dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSub => _dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _textHint => _dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get _inputFill => _dark ? const Color(0xFF101B2E) : const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _sumByType(List<Map<String, dynamic>> debtors, String type) =>
      debtors.where((d) => d['person_type'] == type).fold(0.0, (s, d) => s + (d['balance'] as num).toDouble().abs());

  int _countByType(List<Map<String, dynamic>> debtors, String type) =>
      debtors.where((d) => d['person_type'] == type).length;

  void _snack(String title, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(msg, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: (error ? _rose : _emerald).withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ==================== الواجهة ====================
  @override
  Widget build(BuildContext context) {
    final asyncDebtors = ref.watch(debtorsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: asyncDebtors.when(
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_debtAccent), strokeWidth: 2.5)),
        error: (err, stack) => Center(child: Text('خطأ: $err', style: TextStyle(color: _textMain))),
        data: (state) {
          final allDebtors = state.allDebtors;
          final query = _searchController.text.trim().toLowerCase();
          final filteredDebtors = query.isEmpty
              ? allDebtors
              : allDebtors.where((d) {
            final name = (d['name'] ?? '').toString().toLowerCase();
            final phone = (d['phone'] ?? '').toString().toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(debtorsProvider),
            color: _debtAccent,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildSliverAppBar(allDebtors, state.totalDebt),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: _buildContent(filteredDebtors),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== SliverAppBar ====================
  Widget _buildSliverAppBar(List<Map<String, dynamic>> allDebtors, double totalDebt) {
    final totalCustomers = _sumByType(allDebtors, 'customer');
    final totalSuppliers = _sumByType(allDebtors, 'supplier');

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _dark ? _navyDeep : AppColors.navy,
      foregroundColor: _gold,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), onPressed: () => Navigator.pop(context)),
      title: const Text('المدينين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, size: 22),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchController.clear();
            });
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _dark
                  ? [_navyDeep, const Color(0xFF1E304B), const Color(0xFF263C5C)]
                  : [AppColors.navy, const Color(0xFF162D50), const Color(0xFF1E3A5F)],
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
                  // الإجمالي الكبير
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, child) => Opacity(opacity: val, child: Transform.scale(scale: 0.85 + (0.15 * val), child: child)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_debtAccent.withOpacity(0.12), _debtAccent.withOpacity(0.04)]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _debtAccent.withOpacity(0.25)),
                      ),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.money_off_rounded, color: _debtAccent, size: 20),
                            const SizedBox(width: 8),
                            Text('إجمالي الديون المستحقة (لك)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                          ]),
                          const SizedBox(height: 10),
                          FittedBox(
                            child: Text(
                              '${NumberFormat('#,##0.00', 'en').format(totalDebt)} ﷼',
                              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // تقسيم حسب النوع
                  Row(
                    children: [
                      Expanded(child: _miniStat('عملاء', _countByType(allDebtors, 'customer'), totalCustomers, _sky, Icons.people_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _miniStat('موردين', _countByType(allDebtors, 'supplier'), totalSuppliers, _violet, Icons.local_shipping_rounded)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, int count, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label ($count)', style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
              const SizedBox(height: 2),
              FittedBox(child: Text(NumberFormat('#,##0', 'en').format(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
            ],
          ),
        ),
      ]),
    );
  }

  // ==================== المحتوى ====================
  Widget _buildContent(List<Map<String, dynamic>> filteredDebtors) {
    if (filteredDebtors.isEmpty && !_showSearch) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // بحث
        if (_showSearch) ...[
          const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 10),
        ] else
          const SizedBox(height: 14),

        // القائمة
        ...filteredDebtors.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (i.clamp(0, 8) * 50)),
            curve: Curves.easeOutCubic,
            builder: (_, val, child) => Transform.translate(
              offset: Offset(25 * (1 - val), 0),
              child: Opacity(opacity: val, child: child),
            ),
            child: _buildDebtorCard(d),
          );
        }),

        if (filteredDebtors.isEmpty && _showSearch)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text('لا توجد نتائج للبحث', style: TextStyle(color: _textSub, fontSize: 14))),
          ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: _textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'بحث باسم المدين أو رقم الهاتف...',
          hintStyle: TextStyle(color: _textHint, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: _debtAccent, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: Icon(Icons.clear_rounded, color: _textHint, size: 18), onPressed: () => _searchController.clear())
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [_emerald.withOpacity(0.12), _emerald.withOpacity(0.03)]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded, size: 56, color: _emerald.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text('لا يوجد مدينين 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
          const SizedBox(height: 6),
          Text('جميع الحسابات مسددة', style: TextStyle(color: _textSub, fontSize: 13)),
        ],
      ),
    );
  }

  // ==================== بطاقة المدين ====================
  Widget _buildDebtorCard(Map<String, dynamic> debtor) {
    final isCustomer = debtor['person_type'] == 'customer';
    final double currentBalance = (debtor['balance'] as num).toDouble().abs();
    final phone = debtor['phone']?.toString();
    final name = debtor['name'] ?? 'غير معروف';
    final color = isCustomer ? _sky : _violet;
    final colorDark = isCustomer ? _skyDark : _violetDark;
    final typeLabel = isCustomer ? 'عميل' : 'مورد';
    final typeIcon = isCustomer ? Icons.person_rounded : Icons.local_shipping_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: color.withOpacity(_dark ? 0.04 : 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // شريط جانبي
              Container(
                width: 5,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [color, colorDark], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
              // المحتوى
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الصف الأول
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.04)]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(typeIcon, size: 12, color: color),
                              const SizedBox(width: 4),
                              Text(typeLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          const Spacer(),
                          if (phone != null && phone.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.phone_android_rounded, size: 11, color: _textHint),
                              const SizedBox(width: 3),
                              Text(phone, style: TextStyle(fontSize: 10, color: _textHint)),
                            ]),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // الاسم
                      Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textMain)),
                      const SizedBox(height: 8),

                      // المبلغ
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_debtAccent.withOpacity(0.06), _debtAccent.withOpacity(0.02)]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _debtAccent.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.money_off_rounded, size: 16, color: _debtAccent),
                            const SizedBox(width: 8),
                            Text('الدين المتبقي:', style: TextStyle(fontSize: 11, color: _textSub)),
                            const SizedBox(width: 6),
                            Text(
                              '${NumberFormat('#,##0.00', 'en').format(currentBalance)} ﷼',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _debtAccent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // الأزرار
                      Row(
                        children: [
                          Expanded(
                            child: _outlineBtn(
                              label: 'كشف حساب',
                              icon: Icons.receipt_long_rounded,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountStatementScreen(
                                personId: debtor['id'],
                                personName: name,
                                personType: debtor['person_type'] ?? 'customer',
                              ))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _gradientBtn(
                              label: 'تسديد الدفعة',
                              icon: Icons.check_circle_rounded,
                              color: _emerald,
                              onTap: () => _openPaymentSheet(debtor['id'], debtor['person_type'], name, currentBalance),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn({required String label, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border, width: 1.2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: _textSub),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textMain)),
          ]),
        ),
      ),
    );
  }

  Widget _gradientBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }

  // ==================== Bottom Sheet التسديد ====================
  void _openPaymentSheet(int personId, String personType, String name, double maxAmount) {
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.success.withOpacity(0.3), width: 1.5)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: 12, left: 24, right: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 22),

                // عنوان
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.15), AppColors.success.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تسديد دفعة مالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
                      Text(name, style: const TextStyle(fontSize: 12, color: AppColors.success)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),

                // الدين الحالي
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_debtAccent.withOpacity(0.06), _debtAccent.withOpacity(0.02)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _debtAccent.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.money_off_rounded, color: _debtAccent, size: 18),
                    const SizedBox(width: 10),
                    Text('الدين المتبقي:', style: TextStyle(color: _textSub, fontSize: 12)),
                    const Spacer(),
                    Text('${NumberFormat('#,##0.00', 'en').format(maxAmount)} ﷼', style: const TextStyle(color: _debtAccent, fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ),
                const SizedBox(height: 18),

                // حقل المبلغ
                TextFormField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.success, fontSize: 22, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المستلم',
                    labelStyle: TextStyle(color: _textSub, fontSize: 13),
                    suffixText: '﷼',
                    suffixStyle: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.monetization_on_rounded, color: AppColors.success, size: 20),
                    filled: true,
                    fillColor: _inputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.success, width: 1.5)),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _rose, width: 1)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                    final val = double.tryParse(v.replaceAll(',', '').trim());
                    if (val == null || val <= 0) return 'أدخل مبلغ صحيح';
                    if (val > maxAmount + 0.01) return 'المبلغ لا يمكن أن يتجاوز الدين المستحق';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // أزرار الحفظ
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSub,
                          side: BorderSide(color: _border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: _textSub)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_emerald, _emeraldDark]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: _emerald.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              if (!formKey.currentState!.validate()) return;
                              Navigator.pop(ctx);
                              await _processPayment(personId, personType, name, maxAmount, double.parse(amountCtrl.text.replaceAll(',', '').trim()));
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: const Center(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 6),
                                Text('تأكيد الاستلام', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ==================== معالجة التسديد ====================
  Future<void> _processPayment(int personId, String personType, String name, double maxAmount, double amount) async {
    try {
      final db = ref.read(databaseHelperProvider);
      final result = await db.processSettlementPayment(
        personId: personId,
        personType: personType,
        amount: amount,
        personName: name,
        referenceNumber: 'سند قبض',
        notes: amount >= maxAmount ? 'تسديد كامل للحساب المستحق' : 'تسديد دفعة جزئية من الحساب',
      );

      if (result['success'] == true) {
        _showSuccessOverlay(name, amount);
        ref.invalidate(debtorsProvider);
      } else {
        _snack(' خطأ', result['message'] ?? 'فشلت العملية', error: true);
      }
    } catch (e) {
      _snack(' خطأ', 'حدث خطأ أثناء التسديد: $e', error: true);
    }
  }

  // ==================== نافذة النجاح ====================
  void _showSuccessOverlay(String name, double amount) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (_, a1, __, child) => Transform.scale(scale: Curves.easeOutBack.transform(a1.value), child: Opacity(opacity: a1.value, child: child)),
      pageBuilder: (ctx, _, __) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 290,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _emerald.withOpacity(0.3), width: 1.5),
                boxShadow: [BoxShadow(color: _emerald.withOpacity(0.15), blurRadius: 30, spreadRadius: 2)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (_, val, __) => Transform.scale(
                      scale: val,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_emerald, _emeraldDark]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _emerald.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('تم استلام الدفعة! ✅', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain)),
                  const SizedBox(height: 8),
                  Text(
                    'تم استلام ${NumberFormat('#,##0.00', 'en').format(amount)} ﷼ من $name',
                    style: TextStyle(fontSize: 12, color: _textSub),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final dotIndex = cleanText.indexOf('.');
    if (dotIndex != -1) {
      cleanText = cleanText.substring(0, dotIndex + 1) + cleanText.substring(dotIndex + 1).replaceAll('.', '');
    }
    if (cleanText.isEmpty || cleanText == '.') {
      return newValue.copyWith(text: cleanText, selection: TextSelection.collapsed(offset: cleanText.length));
    }
    final parts = cleanText.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';
    if (integerPart.isNotEmpty) {
      integerPart = NumberFormat('#,##0', 'en').format(int.parse(integerPart));
    }
    String formattedText = integerPart;
    if (cleanText.contains('.')) formattedText += '.$decimalPart';
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}