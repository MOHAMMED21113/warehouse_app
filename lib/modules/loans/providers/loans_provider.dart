// lib/modules/loans/providers/loans_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../accounting/providers/debtors_provider.dart';
import '../../accounting/providers/creditors_provider.dart';
import '../../accounting/providers/financial_vouchers_provider.dart';

final loansFilterProvider = StateProvider<String>((ref) => 'all'); // 'all', 'active', 'paid', 'overdue'

final loansProvider = AsyncNotifierProvider<LoansNotifier, List<Map<String, dynamic>>>(
  LoansNotifier.new,
);

class LoansNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchLoans();
  }

  Future<List<Map<String, dynamic>>> _fetchLoans() async {
    final db = ref.read(databaseHelperProvider);
    return await db.getAllLoans();
  }

  Future<void> refreshLoans() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => _fetchLoans());
  }

  Future<void> addLoan(Map<String, dynamic> loanData) async {
    final db = ref.read(databaseHelperProvider);
    final amount = (loanData['amount'] as num?)?.toDouble() ?? 0.0;
    final loanType = loanData['loan_type'] as String?;

    // 1. التحقق من رصيد الخزينة عند صرف سلفة لعميل
    if (loanType == 'customer') {
      final hasBalance = await db.checkTreasuryBalance(amount);
      if (!hasBalance) {
        throw Exception('رصيد الخزينة الحالي لا يكفي لصرف هذه السلفة ($amount ﷼)');
      }
    }

    // 2. إدراج السلفة وتحديث الأرصدة في سجل القيود وجداول العملاء والموردين
    final loanId = await db.insertLoan(loanData);

    // 3. إنشاء السند المالي وتوثيقه في الخزينة وسجل السندات
    await _createVoucherForLoan(loanId, loanData, isPayment: false);

    // 4. تحديث كافة المزودات المحاسبية المرتبطة
    await refreshLoans();
    ref.invalidate(debtorsProvider);
    ref.invalidate(creditorsProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(suppliersProvider);
    ref.invalidate(financialVouchersProvider);
  }

  Future<void> makePayment(int loanId, double amount, String paymentMethod) async {
    final db = ref.read(databaseHelperProvider);
    final loan = await db.getLoanById(loanId);
    if (loan == null) throw Exception('السلفة غير موجودة');

    final loanType = loan['loan_type'] as String?;
    // عند سداد سلفة لمورد يتم صرف مبلغ نقدي من الخزينة، لذا يجب التحقق من الرصيد
    if (loanType == 'supplier') {
      final hasBalance = await db.checkTreasuryBalance(amount);
      if (!hasBalance) {
        throw Exception('رصيد الخزينة الحالي لا يكفي لسداد هذا المبلغ ($amount ﷼)');
      }
    }

    await db.recordLoanPayment(loanId, amount, paymentMethod);
    await _createVoucherForLoan(loanId, loan, isPayment: true, paymentAmount: amount, paymentMethod: paymentMethod);

    await refreshLoans();
    ref.invalidate(debtorsProvider);
    ref.invalidate(creditorsProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(suppliersProvider);
    ref.invalidate(financialVouchersProvider);
  }

  Future<void> _createVoucherForLoan(
    int loanId,
    Map<String, dynamic> loanData, {
    required bool isPayment,
    double? paymentAmount,
    String? paymentMethod,
  }) async {
    final db = ref.read(databaseHelperProvider);
    final amount = isPayment ? (paymentAmount ?? 0.0) : ((loanData['amount'] as num?)?.toDouble() ?? 0.0);
    final loanType = loanData['loan_type'] as String?;
    final partyName = loanData['party_name']?.toString() ?? 'طرف غير محدد';
    final notes = loanData['notes']?.toString() ?? '';

    if (amount <= 0 || loanType == null) return;

    String voucherType;
    String voucherNotes;

    if (!isPayment) {
      if (loanType == 'customer') {
        voucherType = 'payment'; // صرف نقدية لعميل كسلفة
        voucherNotes = 'صرف سلفة للعميل: $partyName (سلفة #$loanId)${notes.isNotEmpty ? " - $notes" : ""}';
      } else {
        voucherType = 'receipt'; // استلام نقدية من مورد كسلفة
        voucherNotes = 'استلام سلفة من المورد: $partyName (سلفة #$loanId)${notes.isNotEmpty ? " - $notes" : ""}';
      }
    } else {
      if (loanType == 'customer') {
        voucherType = 'receipt'; // تحصيل دفعة سداد من عميل
        voucherNotes = 'تحصيل سداد سلفة من العميل: $partyName (سلفة #$loanId) طريقة الدفع: ${paymentMethod ?? "نقدي"}';
      } else {
        voucherType = 'payment'; // دفع سداد سلفة لمورد
        voucherNotes = 'دفع سداد سلفة للمورد: $partyName (سلفة #$loanId) طريقة الدفع: ${paymentMethod ?? "نقدي"}';
      }
    }

    await db.createFinancialVoucher(
      categoryId: 1,
      treasuryId: 1,
      type: voucherType,
      amount: amount,
      notes: voucherNotes,
    );
  }
}

final customersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbHelper = ref.read(databaseHelperProvider);
  final db = await dbHelper.database;
  return await db.query('customers', orderBy: 'name ASC');
});

final suppliersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbHelper = ref.read(databaseHelperProvider);
  final db = await dbHelper.database;
  return await db.query('suppliers', orderBy: 'name ASC');
});


