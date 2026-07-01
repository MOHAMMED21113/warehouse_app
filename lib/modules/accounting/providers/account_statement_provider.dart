// lib/modules/accounting/providers/account_statement_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class AccountStatementState {
  final List<Map<String, dynamic>> ledger;
  final double totalDebit;
  final double totalCredit;
  final double balance;
  final bool isLoading;

  const AccountStatementState({
    this.ledger = const [],
    this.totalDebit = 0.0,
    this.totalCredit = 0.0,
    this.balance = 0.0,
    this.isLoading = false,
  });
}

final accountStatementProvider =
AutoDisposeAsyncNotifierProviderFamily<AccountStatementNotifier, AccountStatementState,
    ({int personId, String personType})>(
  AccountStatementNotifier.new,
);

class AccountStatementNotifier
    extends AutoDisposeFamilyAsyncNotifier<AccountStatementState,
        ({int personId, String personType})> {
  @override
  Future<AccountStatementState> build(
      ({int personId, String personType}) arg) async {
    return await _loadData(arg.personId, arg.personType);
  }

  Future<AccountStatementState> _loadData(
      int personId, String personType) async {
    final db = ref.read(databaseHelperProvider);
    final data = await db.getAccountLedger(personId, personType);

    double runningBalance = 0;
    final processed = <Map<String, dynamic>>[];

    for (var entry in data) {
      double debit = (entry['debit_amount'] as num).toDouble();
      double credit = (entry['credit_amount'] as num).toDouble();
      if (personType == 'customer') {
        runningBalance += debit - credit;
      } else {
        runningBalance += credit - debit;
      }
      processed.add({...entry, 'running_balance': runningBalance});
    }

    double totalDebit = 0, totalCredit = 0;
    for (var entry in data) {
      totalDebit += (entry['debit_amount'] as num).toDouble();
      totalCredit += (entry['credit_amount'] as num).toDouble();
    }

    return AccountStatementState(
      ledger: processed.reversed.toList(),
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      balance: processed.isNotEmpty ? processed.last['running_balance'] : 0,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}