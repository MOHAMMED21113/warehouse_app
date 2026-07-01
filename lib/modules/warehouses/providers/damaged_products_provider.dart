// lib/modules/warehouses/providers/damaged_products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class DamagedProductsState {
  final List<Map<String, dynamic>> damagedLog;
  final List<Map<String, dynamic>> filteredLog;
  final bool isLoading;
  final double totalLoss;
  final DateTime? startDate;
  final DateTime? endDate;

  const DamagedProductsState({
    this.damagedLog = const [],
    this.filteredLog = const [],
    this.isLoading = false,
    this.totalLoss = 0.0,
    this.startDate,
    this.endDate,
  });

  DamagedProductsState copyWith({
    List<Map<String, dynamic>>? damagedLog,
    List<Map<String, dynamic>>? filteredLog,
    bool? isLoading,
    double? totalLoss,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return DamagedProductsState(
      damagedLog: damagedLog ?? this.damagedLog,
      filteredLog: filteredLog ?? this.filteredLog,
      isLoading: isLoading ?? this.isLoading,
      totalLoss: totalLoss ?? this.totalLoss,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

final damagedProductsProvider =
AutoDisposeAsyncNotifierProvider<DamagedProductsNotifier, DamagedProductsState>(
  DamagedProductsNotifier.new,
);

class DamagedProductsNotifier extends AutoDisposeAsyncNotifier<DamagedProductsState> {
  @override
  Future<DamagedProductsState> build() async {
    final db = ref.read(databaseHelperProvider);
    final log = await db.getDamagedProductsLog();
    return _applyFilter(log, null, null);
  }

  DamagedProductsState _applyFilter(
      List<Map<String, dynamic>> log, DateTime? startDate, DateTime? endDate) {
    List<Map<String, dynamic>> filtered;
    if (startDate == null || endDate == null) {
      filtered = List.from(log);
    } else {
      filtered = log.where((item) {
        if (item['move_date'] == null) return false;
        try {
          final moveDate = DateTime.parse(item['move_date']);
          final dateOnly = DateTime(moveDate.year, moveDate.month, moveDate.day);
          final start = DateTime(startDate.year, startDate.month, startDate.day);
          final end = DateTime(endDate.year, endDate.month, endDate.day);
          return dateOnly.isAfter(start.subtract(const Duration(days: 1))) &&
              dateOnly.isBefore(end.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    double total = 0;
    for (var p in filtered) {
      total += (p['total_loss'] as num?)?.toDouble() ?? 0.0;
    }

    return DamagedProductsState(
      damagedLog: log,
      filteredLog: filtered,
      totalLoss: total,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    final currentState = state.value!;
    state = AsyncValue.data(_applyFilter(currentState.damagedLog, start, end));
  }

  Future<void> clearFilter() async {
    final currentState = state.value!;
    state = AsyncValue.data(_applyFilter(currentState.damagedLog, null, null));
  }

  Future<bool> returnToInventory(int id) async {
    final db = ref.read(databaseHelperProvider);
    final success = await db.returnDamagedToInventory(id);
    if (success) {
      ref.invalidateSelf();
    }
    return success;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}