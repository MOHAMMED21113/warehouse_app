// lib/modules/accounting/views/account_statement_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/invoice_printer.dart';
import '../providers/account_statement_provider.dart';

class AccountStatementScreen extends ConsumerWidget {
  final int personId;
  final String personName;
  final String personType;

  const AccountStatementScreen({
    super.key,
    required this.personId,
    required this.personName,
    required this.personType,
  });

  // ==================== دالة عرض الرسائل ====================
  void _snack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(
      accountStatementProvider((personId: personId, personType: personType)),
    );
    final colors = AppThemeColors(
      isDark: ref.watch(themeModeProvider) == ThemeMode.dark,
    );

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: asyncState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Text('خطأ: $err', style: TextStyle(color: colors.textMain)),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(
            accountStatementProvider((personId: personId, personType: personType)),
          ),
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, colors, state),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                sliver: state.ledger.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty(colors))
                    : _buildLedgerList(context, ref, colors, state.ledger), // ✅ تمرير ref
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SliverAppBar ====================
  Widget _buildSliverAppBar(
      BuildContext context,
      AppThemeColors colors,
      AccountStatementState state,
      ) {
    final statusColor = state.balance < -0.01
        ? AppColors.error
        : state.balance > 0.01
        ? AppColors.success
        : AppColors.primary;

    final statusTitle = state.balance < -0.01
        ? (personType == 'customer' ? 'عليه (مدين)' : 'مستحق لنا')
        : state.balance > 0.01
        ? (personType == 'customer' ? 'له (دائن)' : 'مستحق لهم')
        : 'الحساب مصفر';

    return SliverAppBar(
      expandedHeight: 330,
      pinned: true,
      backgroundColor: colors.appBarBg,
      foregroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'كشف حساب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            personName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.print_rounded, size: 22),
          onPressed: () => InvoicePrinter.printAccountStatement(
            personName: personName,
            personType: personType,
            ledger: state.ledger.reversed.toList(),
            totalDebit: state.totalDebit,
            totalCredit: state.totalCredit,
            finalBalance: state.balance,
            shopName: 'المخازن الذكية',
            isShare: false,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded, size: 22),
          onPressed: () => InvoicePrinter.printAccountStatement(
            personName: personName,
            personType: personType,
            ledger: state.ledger.reversed.toList(),
            totalDebit: state.totalDebit,
            totalCredit: state.totalCredit,
            finalBalance: state.balance,
            shopName: 'المخازن الذكية',
            isShare: true,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors.scaffoldBg == AppColors.navy
                  ? [AppColors.navy, AppColors.navyMedium]
                  : [AppColors.navy, AppColors.navyMedium],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.15),
                          statusColor.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusTitle,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          NumberFormat('#,##0.00', 'en_US')
                              .format(state.balance.abs()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '﷼ ريال',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'مدين (عليه)',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat('#,##0.00', 'en_US')
                                          .format(state.totalDebit),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'دائن (له)',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat('#,##0.00', 'en_US')
                                          .format(state.totalCredit),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

  // ==================== قائمة الحركات (مع طباعة السند) ====================
  Widget _buildLedgerList(
      BuildContext context,
      WidgetRef ref, // ✅ إضافة ref كمعامل
      AppThemeColors colors,
      List<Map<String, dynamic>> ledger,
      ) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'سجل الحركات (الأحدث أولاً)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...ledger.asMap().entries.map((e) {
          final entry = e.value;
          final double debit = (entry['debit_amount'] as num).toDouble();
          final double credit = (entry['credit_amount'] as num).toDouble();
          final double balanceAfter = entry['running_balance'] as double;
          final bool isDebit = debit > 0;
          final double transactionAmount = isDebit ? debit : credit;
          final refNumber = entry['reference_number']?.toString() ?? '';

          String dateOnly = '';
          String timeOnly = '';
          try {
            final DateTime date = DateTime.parse(entry['date'].toString());
            dateOnly = DateFormat('yyyy/MM/dd', 'en').format(date);
            timeOnly = DateFormat('hh:mm a', 'en').format(date);
          } catch (_) {
            dateOnly = 'تاريخ غير صالح';
          }

          String title = entry['notes']?.toString() ?? 'حركة مالية';
          IconData icon = Icons.swap_horiz_rounded;
          Color iconColor = AppColors.primary;

          if (entry['entry_type'] == 'invoice') {
            icon = Icons.receipt_long_rounded;
            iconColor = AppColors.info;
          } else if (entry['entry_type'] == 'payment' ||
              entry['entry_type'] == 'settlement') {
            icon = Icons.payments_rounded;
            iconColor = AppColors.success;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.cardBorder),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [iconColor, iconColor.withOpacity(0.5)],
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(18),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══ الصف الأول: التاريخ والوقت والنوع ═══
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: colors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateOnly,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSub,
                                ),
                              ),
                              if (timeOnly.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: colors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeOnly,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.textSub,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 12, color: iconColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry['entry_type'] == 'invoice'
                                          ? 'فاتورة'
                                          : 'دفعة',
                                      style: TextStyle(
                                        color: iconColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ═══ الصف الثاني: الملاحظات ═══
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textMain,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // ═══ الصف الثالث: رقم المرجع مع زر الطباعة ═══
                          if (refNumber.isNotEmpty &&
                              refNumber != 'تسوية' &&
                              refNumber != 'تسوية كاملة') ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final db = ref.read(databaseHelperProvider);
                                final voucherData = await db.rawQuery(
                                  'SELECT * FROM financial_vouchers WHERE voucher_number = ?',
                                  [refNumber],
                                );
                                if (voucherData.isNotEmpty) {
                                  await InvoicePrinter.printFinancialVoucher(
                                    voucherData.first,
                                  );
                                } else {
                                  _snack(
                                    context,
                                    'لم يتم العثور على سند بهذا الرقم',
                                    AppColors.error,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.scaffoldBg == AppColors.navy
                                      ? AppColors.navy
                                      : AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colors.cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.print_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'طباعة السند: $refNumber',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // ═══ الصف الرابع: الرصيد والمبلغ ═══
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.scaffoldBg == AppColors.navy
                                      ? AppColors.navy
                                      : AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.account_balance_rounded,
                                      size: 12,
                                      color: colors.textSub,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'الرصيد: ${NumberFormat('#,##0.00', 'en_US').format(balanceAfter.abs())}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: balanceAfter == 0
                                            ? colors.textHint
                                            : balanceAfter < 0
                                            ? AppColors.error
                                            : AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${isDebit ? '+' : '-'} ${NumberFormat('#,##0.00', 'en_US').format(transactionAmount)} ﷼',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDebit
                                      ? AppColors.error
                                      : AppColors.success,
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
          );
        }),
      ]),
    );
  }

  // ==================== حالة فارغة ====================
  Widget _buildEmpty(AppThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 56,
            color: colors.textHint,
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد حركات مسجلة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}