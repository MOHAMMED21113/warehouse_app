// lib/modules/accounting/views/treasury_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/widgets/transaction_guard.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../providers/treasury_provider.dart';

class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _navyDeep = Color(0xFF16243A);
  static const Color _success = Color(0xFF10B981);
  static const Color _error = Color(0xFFF43F5E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final Color bg = dark ? const Color(0xFF101B2E) : const Color(0xFFF0F4F8);
    final Color cardBg = dark ? const Color(0xFF1E2D43) : Colors.white;
    final Color border = dark ? const Color(0xFF2C3E5A) : const Color(0xFFE2E8F0);
    final Color textMain = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color textSub = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color textHint = dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final state = ref.watch(treasuryProvider);

    return Scaffold(
      backgroundColor: bg,
      body: state.isLoading && state.transactions.isEmpty
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_gold), strokeWidth: 2.5))
          : RefreshIndicator(
        onRefresh: () async => ref.read(treasuryProvider.notifier).refreshTreasury(),
        color: _gold,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildSliverAppBar(context, ref, state, dark),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: _buildContent(state, dark, cardBg, border, textMain, textSub, textHint),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SliverAppBar ====================
  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, TreasuryState state, bool dark) {
    return SliverAppBar(
      expandedHeight: 310,
      pinned: true,
      backgroundColor: dark ? _navyDeep : AppColors.navy,
      foregroundColor: _gold,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('الخزينة والصندوق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [_navyDeep, const Color(0xFF1E304B), const Color(0xFF263C5C)]
                  : [AppColors.navy, const Color(0xFF162D50), const Color(0xFF1E3A5F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, child) => Opacity(
                      opacity: val,
                      child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_gold.withOpacity(0.15), _gold.withOpacity(0.02)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _gold.withOpacity(0.3), width: 1),
                        boxShadow: [BoxShadow(color: _gold.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: _gold.withOpacity(0.9), size: 20),
                              const SizedBox(width: 8),
                              Text('إجمالي السيولة النقدية المتاحة', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            child: Text(
                              '${NumberFormat('#,##0.00', 'en').format(state.treasuryBalance)} ﷼',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ==================== محتوى الصفحة (قائمة الحركات) ====================
  Widget _buildContent(TreasuryState state, bool dark, Color cardBg, Color border, Color textMain, Color textSub, Color textHint) {
    if (state.transactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(gradient: RadialGradient(colors: [_gold.withOpacity(0.15), _gold.withOpacity(0.03)]), shape: BoxShape.circle),
                child: Icon(Icons.receipt_long_rounded, size: 56, color: _gold.withOpacity(0.5)),
              ),
              const SizedBox(height: 20),
              Text('لا توجد حركات مالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
              const SizedBox(height: 6),
              Text('استخدم أزرار الإيداع أو السحب للبدء', style: TextStyle(color: textSub, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.history_rounded, size: 16, color: _gold)),
            const SizedBox(width: 10),
            Text('سجل حركة الأموال', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textMain)),
          ],
        ),
        const SizedBox(height: 16),
        ...state.transactions.asMap().entries.map((e) {
          final index = e.key;
          final trx = e.value;
          final bool isIn = trx['transaction_type'] == 'in';
          final double amt = (trx['amount'] as num).toDouble();
          final Color trxColor = isIn ? _success : _error;

          String dateOnly = '';
          String timeOnly = '';
          try {
            final parsedDate = DateTime.parse(trx['date'].toString());
            dateOnly = DateFormat('yyyy/MM/dd', 'en').format(parsedDate);
            timeOnly = DateFormat('hh:mm a', 'en').format(parsedDate);
          } catch (_) {
            dateOnly = trx['date'].toString();
          }

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index.clamp(0, 10) * 50)),
            curve: Curves.easeOutCubic,
            builder: (_, val, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - val)),
              child: Opacity(opacity: val, child: child),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(width: 5, decoration: BoxDecoration(gradient: LinearGradient(colors: [trxColor, trxColor.withOpacity(0.5)], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)))),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 12, color: textHint), const SizedBox(width: 4), Text(dateOnly, style: TextStyle(fontSize: 11, color: textSub)),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time_rounded, size: 12, color: textHint), const SizedBox(width: 4), Text(timeOnly, style: TextStyle(fontSize: 11, color: textSub)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: trxColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [Icon(isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: trxColor, size: 12), const SizedBox(width: 4), Text(isIn ? 'قبض (إيداع)' : 'صرف (سحب)', style: TextStyle(color: trxColor, fontSize: 10, fontWeight: FontWeight.bold))],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(trx['notes'] ?? 'بدون بيان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMain), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Text('${isIn ? '+' : '-'} ${NumberFormat('#,##0.00', 'en').format(amt)} ﷼', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: trxColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ==================== نافذة الإيداع/السحب ====================

  void _showSuccessOverlay(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24), const SizedBox(width: 12), Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')))]),
        backgroundColor: _success.withOpacity(0.95), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), duration: const Duration(seconds: 3),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final dotIndex = cleanText.indexOf('.');
    if (dotIndex != -1) cleanText = cleanText.substring(0, dotIndex + 1) + cleanText.substring(dotIndex + 1).replaceAll('.', '');
    if (cleanText.isEmpty || cleanText == '.') return newValue.copyWith(text: cleanText, selection: TextSelection.collapsed(offset: cleanText.length));
    final parts = cleanText.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';
    if (integerPart.isNotEmpty) integerPart = NumberFormat('#,##0', 'en').format(int.parse(integerPart));
    String formattedText = integerPart;
    if (cleanText.contains('.')) formattedText += '.$decimalPart';
    return TextEditingValue(text: formattedText, selection: TextSelection.collapsed(offset: formattedText.length));
  }
}