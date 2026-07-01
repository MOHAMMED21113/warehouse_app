// lib/modules/invoices/providers/invoices_list_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class InvoicesListState {
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> filteredInvoices;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;

  final String searchQuery;
  final String activeFilter;
  final String sortMode;
  final DateTimeRange? dateRange;

  final double totalAmount;
  final double paidAmount;
  final double unpaidAmount;

  final Map<int, List<Map<String, dynamic>>> invoiceItems;
  final Map<int, List<Map<String, dynamic>>> invoicePayments;

  // الحقول الجديدة للفلترة والتحديد المتعدد
  final int? selectedPersonId;
  final String? selectedPersonName;
  final List<Map<String, dynamic>> personsList;
  final bool isMultiSelectMode;
  final Set<int> selectedInvoiceIds;

  InvoicesListState({
    required this.invoices,
    required this.filteredInvoices,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.currentPage,
    required this.searchQuery,
    required this.activeFilter,
    required this.sortMode,
    this.dateRange,
    required this.totalAmount,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.invoiceItems,
    required this.invoicePayments,
    this.selectedPersonId,
    this.selectedPersonName,
    required this.personsList,
    required this.isMultiSelectMode,
    required this.selectedInvoiceIds,
  });

  factory InvoicesListState.initial() => InvoicesListState(
    invoices: [], filteredInvoices: [],
    isLoading: true, isLoadingMore: false, hasMore: true, currentPage: 1,
    searchQuery: '', activeFilter: 'الكل', sortMode: 'الأحدث', dateRange: null,
    totalAmount: 0.0, paidAmount: 0.0, unpaidAmount: 0.0,
    invoiceItems: {}, invoicePayments: {},
    selectedPersonId: null, selectedPersonName: null, personsList: [],
    isMultiSelectMode: false, selectedInvoiceIds: const {},
  );

  InvoicesListState copyWith({
    List<Map<String, dynamic>>? invoices,
    List<Map<String, dynamic>>? filteredInvoices,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? searchQuery,
    String? activeFilter,
    String? sortMode,
    DateTimeRange? dateRange,
    double? totalAmount,
    double? paidAmount,
    double? unpaidAmount,
    Map<int, List<Map<String, dynamic>>>? invoiceItems,
    Map<int, List<Map<String, dynamic>>>? invoicePayments,
    int? selectedPersonId,
    String? selectedPersonName,
    List<Map<String, dynamic>>? personsList,
    bool? isMultiSelectMode,
    Set<int>? selectedInvoiceIds,
    bool clearDateRange = false,
    bool clearPersonFilter = false,
  }) {
    return InvoicesListState(
      invoices: invoices ?? this.invoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      sortMode: sortMode ?? this.sortMode,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      unpaidAmount: unpaidAmount ?? this.unpaidAmount,
      invoiceItems: invoiceItems ?? this.invoiceItems,
      invoicePayments: invoicePayments ?? this.invoicePayments,
      selectedPersonId: clearPersonFilter ? null : (selectedPersonId ?? this.selectedPersonId),
      selectedPersonName: clearPersonFilter ? null : (selectedPersonName ?? this.selectedPersonName),
      personsList: personsList ?? this.personsList,
      isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
      selectedInvoiceIds: selectedInvoiceIds ?? this.selectedInvoiceIds,
    );
  }
}

final invoicesListProvider = AutoDisposeNotifierProviderFamily<InvoicesListNotifier, InvoicesListState, String>(
  InvoicesListNotifier.new,
);

class InvoicesListNotifier extends AutoDisposeFamilyNotifier<InvoicesListState, String> {
  final int _limit = 20;
  Timer? _debounceTimer;

  @override
  InvoicesListState build(String arg) {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    Future.microtask(() => loadInitialInvoices());
    return InvoicesListState.initial();
  }

  bool get _isSales => arg == 'sales';

  Future<void> loadInitialInvoices() async {
    state = state.copyWith(isLoading: true, currentPage: 1, hasMore: true);
    final db = ref.read(databaseHelperProvider);
    final query = state.searchQuery.trim();
    try {
      final invoices = _isSales
          ? await db.getSaleInvoicesPaginated(page: 1, limit: _limit, searchQuery: query.isNotEmpty ? query : null)
          : await db.getPurchaseInvoicesPaginated(page: 1, limit: _limit, searchQuery: query.isNotEmpty ? query : null);

      final persons = _isSales ? await db.getAllCustomers() : await db.getAllSuppliers();

      state = state.copyWith(personsList: persons);
      _applyFiltersAndCalculateStats(invoices);
    } catch (e) {
      debugPrint('Error loading invoices: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMoreInvoices() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    final db = ref.read(databaseHelperProvider);
    final nextPage = state.currentPage + 1;
    final query = state.searchQuery.trim();

    try {
      final newInvoices = _isSales
          ? await db.getSaleInvoicesPaginated(page: nextPage, limit: _limit, searchQuery: query.isNotEmpty ? query : null)
          : await db.getPurchaseInvoicesPaginated(page: nextPage, limit: _limit, searchQuery: query.isNotEmpty ? query : null);

      if (newInvoices.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
      } else {
        final combined = [...state.invoices, ...newInvoices];
        state = state.copyWith(currentPage: nextPage, isLoadingMore: false);
        _applyFiltersAndCalculateStats(combined);
      }
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> loadInvoiceDetails(int invoiceId, Map<String, dynamic> invoice) async {
    final db = ref.read(databaseHelperProvider);
    final currentItems = Map<int, List<Map<String, dynamic>>>.from(state.invoiceItems);
    final currentPayments = Map<int, List<Map<String, dynamic>>>.from(state.invoicePayments);

    if (!currentItems.containsKey(invoiceId)) {
      currentItems[invoiceId] = _isSales
          ? await db.getSaleInvoiceItems(invoiceId)
          : await db.getPurchaseInvoiceItems(invoiceId);
    }

    if (!currentPayments.containsKey(invoiceId)) {
      final personId = _isSales ? invoice['customer_id'] : invoice['supplier_id'];
      if (personId != null) {
        final personType = _isSales ? 'customer' : 'supplier';
        final invoiceDate = invoice['date']?.toString() ?? invoice['created_at']?.toString() ?? '';
        currentPayments[invoiceId] = await db.getRelatedPayments(personId, personType, invoiceDate);
      } else {
        currentPayments[invoiceId] = [];
      }
    }

    state = state.copyWith(invoiceItems: currentItems, invoicePayments: currentPayments);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      loadInitialInvoices();
    });
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
    _applyFiltersAndCalculateStats(state.invoices);
  }

  void setSortMode(String sortMode) {
    state = state.copyWith(sortMode: sortMode);
    _applyFiltersAndCalculateStats(state.invoices);
  }

  void setDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: range, clearDateRange: range == null);
    _applyFiltersAndCalculateStats(state.invoices);
  }

  void setPersonFilter(int? personId, String? personName) {
    state = state.copyWith(
      selectedPersonId: personId,
      selectedPersonName: personName,
      clearPersonFilter: personId == null,
    );
    _applyFiltersAndCalculateStats(state.invoices);
  }

  void toggleMultiSelectMode() {
    state = state.copyWith(
      isMultiSelectMode: !state.isMultiSelectMode,
      selectedInvoiceIds: const {},
    );
  }

  void toggleInvoiceSelection(int invoiceId) {
    final newSet = Set<int>.from(state.selectedInvoiceIds);
    if (newSet.contains(invoiceId)) {
      newSet.remove(invoiceId);
    } else {
      newSet.add(invoiceId);
    }
    state = state.copyWith(selectedInvoiceIds: newSet);
  }

  void selectAllInvoices() {
    final allIds = state.filteredInvoices.map((i) => i['id'] as int).toSet();
    state = state.copyWith(selectedInvoiceIds: allIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedInvoiceIds: const {});
  }

  void removeInvoiceLocally(int invoiceId) {
    final newInvoices = state.invoices.where((i) => i['id'] != invoiceId).toList();
    _applyFiltersAndCalculateStats(newInvoices);
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final db = ref.read(databaseHelperProvider);
    _isSales ? await db.deleteSaleInvoice(invoiceId) : await db.deletePurchaseInvoice(invoiceId);
    await loadInitialInvoices();
  }

  void _applyFiltersAndCalculateStats(List<Map<String, dynamic>> sourceInvoices) {
    List<Map<String, dynamic>> result = List.from(sourceInvoices);
    final query = state.searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((i) =>
      (i['invoice_number'] ?? '').toString().toLowerCase().contains(query) ||
          (i['customer_name'] ?? '').toString().toLowerCase().contains(query) ||
          (i['supplier_name'] ?? '').toString().toLowerCase().contains(query)).toList();
    }

    if (state.selectedPersonId != null) {
      final idField = _isSales ? 'customer_id' : 'supplier_id';
      result = result.where((i) => i[idField] == state.selectedPersonId).toList();
    }

    switch (state.activeFilter) {
      case 'مدفوع': result = result.where((i) => (i['payment_status'] ?? '') == 'كامل').toList(); break;
      case 'جزئي': result = result.where((i) => (i['payment_status'] ?? '') == 'جزئي').toList(); break;
      case 'آجل': result = result.where((i) {
        final st = i['payment_status'] ?? '';
        return st != 'كامل' && st != 'جزئي';
      }).toList(); break;
    }

    if (state.dateRange != null) {
      final range = state.dateRange!;
      result = result.where((i) {
        final dateStr = i['date']?.toString() ?? i['created_at']?.toString() ?? '';
        if (dateStr.isEmpty) return false;
        try {
          final date = DateTime.parse(dateStr);
          return !date.isBefore(range.start) && !date.isAfter(range.end.add(const Duration(days: 1)));
        } catch (_) { return false; }
      }).toList();
    }

    switch (state.sortMode) {
      case 'الأحدث': result.sort((a, b) => (b['date'] ?? b['created_at'] ?? '').toString().compareTo((a['date'] ?? a['created_at'] ?? '').toString())); break;
      case 'الأقدم': result.sort((a, b) => (a['date'] ?? a['created_at'] ?? '').toString().compareTo((b['date'] ?? b['created_at'] ?? '').toString())); break;
      case 'الأعلى مبلغاً': result.sort((a, b) => ((b['total_amount'] ?? 0) as num).compareTo((a['total_amount'] ?? 0) as num)); break;
      case 'الأقل مبلغاً': result.sort((a, b) => ((a['total_amount'] ?? 0) as num).compareTo((b['total_amount'] ?? 0) as num)); break;
    }

    double total = 0, paid = 0, unpaid = 0;
    for (var inv in result) {
      final amount = (inv['total_amount'] ?? 0).toDouble();
      final paidAmt = (inv['paid_amount'] ?? 0).toDouble();
      total += amount;
      paid += paidAmt;
      unpaid += (amount - paidAmt).clamp(0, double.infinity);
    }

    state = state.copyWith(
      invoices: sourceInvoices,
      filteredInvoices: result,
      totalAmount: total,
      paidAmount: paid,
      unpaidAmount: unpaid,
      isLoading: false,
    );
  }
}