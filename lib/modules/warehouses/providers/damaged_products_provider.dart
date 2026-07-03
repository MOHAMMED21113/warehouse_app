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
  final String searchQuery;

  const DamagedProductsState({
    this.damagedLog = const [],
    this.filteredLog = const [],
    this.isLoading = false,
    this.totalLoss = 0.0,
    this.startDate,
    this.endDate,
    this.searchQuery = '',
  });

  DamagedProductsState copyWith({
    List<Map<String, dynamic>>? damagedLog,
    List<Map<String, dynamic>>? filteredLog,
    bool? isLoading,
    double? totalLoss,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
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
      searchQuery: searchQuery ?? this.searchQuery,
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
    return _applyFilter(log, null, null, '');
  }

  DamagedProductsState _applyFilter(
      List<Map<String, dynamic>> log, DateTime? startDate, DateTime? endDate, String query) {
    List<Map<String, dynamic>> filtered = List.from(log);

    if (startDate != null && endDate != null) {
      filtered = filtered.where((item) {
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

    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((item) {
        final prodName = (item['product_name'] ?? '').toString().toLowerCase();
        final barcode = (item['barcode'] ?? '').toString().toLowerCase();
        final reason = (item['reason'] ?? '').toString().toLowerCase();
        final notes = (item['notes'] ?? '').toString().toLowerCase();
        final status = (item['status'] ?? '').toString().toLowerCase();
        return prodName.contains(q) ||
            barcode.contains(q) ||
            reason.contains(q) ||
            notes.contains(q) ||
            status.contains(q);
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
      searchQuery: query,
    );
  }

  Future<void> setSearchQuery(String query) async {
    final currentState = state.value!;
    state = AsyncValue.data(_applyFilter(currentState.damagedLog, currentState.startDate, currentState.endDate, query));
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    final currentState = state.value!;
    state = AsyncValue.data(_applyFilter(currentState.damagedLog, start, end, currentState.searchQuery));
  }

  Future<void> clearFilter() async {
    final currentState = state.value!;
    state = AsyncValue.data(_applyFilter(currentState.damagedLog, null, null, ''));
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