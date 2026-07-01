// lib/modules/accounting/providers/creditors_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class CreditorsState {
  final List<Map<String, dynamic>> allCreditors;
  final double totalCredit;
  final bool isLoading;

  const CreditorsState({
    this.allCreditors = const [],
    this.totalCredit = 0.0,
    this.isLoading = false,
  });
}

final creditorsProvider =
AutoDisposeAsyncNotifierProvider<CreditorsNotifier, CreditorsState>(
  CreditorsNotifier.new,
);

class CreditorsNotifier extends AutoDisposeAsyncNotifier<CreditorsState> {
  @override
  Future<CreditorsState> build() async {
    return await _loadData();
  }

  Future<CreditorsState> _loadData() async {
    final db = ref.read(databaseHelperProvider);
    final customerCreditors = await db.getCreditors();
    final supplierCreditors = await db.getSupplierCreditors();

    final allCreditors = <Map<String, dynamic>>[];
    for (var c in customerCreditors) {
      allCreditors.add({...c, 'person_type': 'customer'});
    }
    for (var s in supplierCreditors) {
      allCreditors.add({...s, 'person_type': 'supplier'});
    }
    allCreditors.sort((a, b) => (b['balance'] as num).compareTo((a['balance'] as num)));

    double total = 0;
    for (var c in allCreditors) {
      total += (c['balance'] as num).toDouble();
    }

    return CreditorsState(allCreditors: allCreditors, totalCredit: total);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}