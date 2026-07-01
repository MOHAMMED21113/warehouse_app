// lib/modules/accounting/providers/debtors_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class DebtorsState {
  final List<Map<String, dynamic>> allDebtors;
  final double totalDebt;
  final bool isLoading;

  const DebtorsState({
    this.allDebtors = const [],
    this.totalDebt = 0.0,
    this.isLoading = false,
  });
}

final debtorsProvider =
AutoDisposeAsyncNotifierProvider<DebtorsNotifier, DebtorsState>(
  DebtorsNotifier.new,
);

class DebtorsNotifier extends AutoDisposeAsyncNotifier<DebtorsState> {
  @override
  Future<DebtorsState> build() async {
    return await _loadData();
  }

  Future<DebtorsState> _loadData() async {
    final db = ref.read(databaseHelperProvider);
    final customerDebtors = await db.getDebtors();
    final supplierDebtors = await db.getSupplierDebtors();

    final allDebtors = <Map<String, dynamic>>[];
    for (var c in customerDebtors) {
      allDebtors.add({...c, 'person_type': 'customer'});
    }
    for (var s in supplierDebtors) {
      allDebtors.add({...s, 'person_type': 'supplier'});
    }
    allDebtors.sort((a, b) => (b['balance'] as num).abs().compareTo((a['balance'] as num).abs()));

    double total = 0;
    for (var d in allDebtors) {
      total += (d['balance'] as num).toDouble().abs();
    }

    return DebtorsState(allDebtors: allDebtors, totalDebt: total);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}