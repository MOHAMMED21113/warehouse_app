// lib/modules/accounting/views/creditors_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/creditors_provider.dart';
import 'account_statement_screen.dart';

class CreditorsScreen extends ConsumerStatefulWidget {
  const CreditorsScreen({super.key});

  @override
  ConsumerState<CreditorsScreen> createState() => _CreditorsScreenState();
}

class _CreditorsScreenState extends ConsumerState<CreditorsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncCreditors = ref.watch(creditorsProvider);
    final colors = _colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: asyncCreditors.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.success)),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (state) {
          final query = _searchController.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? state.allCreditors
              : state.allCreditors.where((c) => (c['name'] ?? '').toLowerCase().contains(query) || (c['phone'] ?? '').toLowerCase().contains(query)).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildSliverAppBar(colors, state),
              if (_showSearch)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: colors.textMain),
                      decoration: InputDecoration(hintText: 'بحث باسم الدائن أو الهاتف...', hintStyle: TextStyle(color: colors.textHint), border: InputBorder.none, icon: Icon(Icons.search, color: colors.textHint)),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: filtered.isEmpty
                    ? SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.mood_rounded, size: 60, color: colors.textHint),
                      const SizedBox(height: 16),
                      Text('ليس عليك ديون لأحد', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textMain)),
                    ]),
                  ),
                )
                    : SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) => _buildCard(colors, filtered[i]), childCount: filtered.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(AppThemeColors colors, CreditorsState state) {
    final totalCustomers = state.allCreditors.where((c) => c['person_type'] == 'customer').fold(0.0, (s, c) => s + (c['balance'] as num).toDouble());
    final totalSuppliers = state.allCreditors.where((c) => c['person_type'] == 'supplier').fold(0.0, (s, c) => s + (c['balance'] as num).toDouble());

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: colors.appBarBg,
      foregroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), onPressed: () => Navigator.pop(context)),
      title: const Text('الدائنين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, size: 22),
          onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) _searchController.clear(); }),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors.scaffoldBg == AppColors.navy ? [AppColors.navy, AppColors.navyMedium] : [AppColors.navy, AppColors.navyMedium], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.12), AppColors.success.withOpacity(0.04)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success.withOpacity(0.25)),
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text('إجمالي الالتزامات (عليك)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ]),
                      const SizedBox(height: 10),
                      FittedBox(child: Text('${NumberFormat('#,##0.00', 'en').format(state.totalCredit)} ﷼', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _miniStat(colors, 'عملاء', state.allCreditors.where((c) => c['person_type'] == 'customer').length, totalCustomers, AppColors.info, Icons.people_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _miniStat(colors, 'موردين', state.allCreditors.where((c) => c['person_type'] == 'supplier').length, totalSuppliers, AppColors.secondary, Icons.local_shipping_rounded)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(AppThemeColors colors, String label, int count, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.18))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label ($count)', style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          const SizedBox(height: 2),
          FittedBox(child: Text(NumberFormat('#,##0', 'en').format(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
        ])),
      ]),
    );
  }

  Widget _buildCard(AppThemeColors colors, Map<String, dynamic> creditor) {
    final isCustomer = creditor['person_type'] == 'customer';
    final double balance = (creditor['balance'] as num).toDouble();
    final color = isCustomer ? AppColors.info : AppColors.secondary;
    final label = isCustomer ? 'عميل' : 'مورد';
    final icon = isCustomer ? Icons.person_rounded : Icons.local_shipping_rounded;
    final phone = creditor['phone']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: colors.cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.cardBorder)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.04)]), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
                child: Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]),
              ),
              const Spacer(),
              if (phone != null && phone.isNotEmpty) Row(children: [Icon(Icons.phone_android_rounded, size: 11, color: colors.textHint), const SizedBox(width: 3), Text(phone, style: TextStyle(fontSize: 10, color: colors.textHint))]),
            ]),
            const SizedBox(height: 10),
            Text(creditor['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textMain)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.06), AppColors.success.withOpacity(0.02)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.15))),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Text('المستحق:', style: TextStyle(fontSize: 11, color: colors.textSub)),
                const SizedBox(width: 6),
                Text('${NumberFormat('#,##0.00', 'en').format(balance)} ﷼', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountStatementScreen(personId: creditor['id'], personName: creditor['name'] ?? '', personType: creditor['person_type'] ?? 'customer'))),
                  style: OutlinedButton.styleFrom(foregroundColor: colors.textSub, side: BorderSide(color: colors.cardBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('كشف حساب', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openPaymentSheet(creditor['id'], creditor['person_type'] ?? 'customer', creditor['name'] ?? '', balance),
                  icon: const Icon(Icons.payment_rounded, size: 14),
                  label: const Text('دفع', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _openPaymentSheet(int personId, String personType, String name, double maxAmount) {
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final colors = _colors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: colors.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border(top: BorderSide(color: AppColors.success.withOpacity(0.3)))),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('دفع مستحقات $name', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textMain, fontSize: 18)),
                const SizedBox(height: 16),
                Text('المبلغ المستحق: ${NumberFormat('#,##0.00', 'en').format(maxAmount)} ﷼', style: TextStyle(color: AppColors.success)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'المبلغ', filled: true, fillColor: colors.inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'أدخل مبلغ صحيح';
                    if (val > maxAmount) return 'لا يمكن تجاوز المبلغ المستحق';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    final db = ref.read(databaseHelperProvider);
                    final result = await db.processSettlementPayment(personId: personId, personType: personType, amount: double.parse(amountCtrl.text), personName: name);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: result['success'] == true ? AppColors.success : AppColors.error));
                    ref.invalidate(creditorsProvider);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تأكيد الدفع'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}