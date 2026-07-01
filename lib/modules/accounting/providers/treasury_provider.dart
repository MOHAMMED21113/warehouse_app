// lib/modules/accounting/providers/treasury_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_helper.dart';

// 1. كلاس الحالة (State)
class TreasuryState {
  final bool isLoading;
  final double treasuryBalance;
  final List<Map<String, dynamic>> transactions;

  TreasuryState({
    this.isLoading = true,
    this.treasuryBalance = 0.0,
    this.transactions = const [],
  });

  TreasuryState copyWith({
    bool? isLoading,
    double? treasuryBalance,
    List<Map<String, dynamic>>? transactions,
  }) {
    return TreasuryState(
      isLoading: isLoading ?? this.isLoading,
      treasuryBalance: treasuryBalance ?? this.treasuryBalance,
      transactions: transactions ?? this.transactions,
    );
  }
}

// 2. كلاس التحكم (Notifier)
class TreasuryNotifier extends StateNotifier<TreasuryState> {
  final DatabaseHelper db;

  TreasuryNotifier(this.db) : super(TreasuryState()) {
    refreshTreasury();
  }

  // تحديث البيانات من قاعدة البيانات فوراً
  Future<void> refreshTreasury() async {
    state = state.copyWith(isLoading: true);
    try {
      // جلب الصندوق الرئيسي (ID = 1)
      final treasuries = await db.getAllTreasuries();
      double balance = 0.0;
      if (treasuries.isNotEmpty) {
        balance = (treasuries.first['balance'] as num).toDouble();
      }

      // جلب سجل الحركات المحدث
      final list = await db.getTreasuryStatement(1);

      state = state.copyWith(
        treasuryBalance: balance,
        transactions: list,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('خطأ في تحميل بيانات الخزينة: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // إجراء حركة مالية آمنة (إيداع أو سحب)
  Future<Map<String, dynamic>> makeTransaction({
    required String type, // 'in' أو 'out'
    required double amount,
    required String refType, // 'deposit' أو 'withdrawal'
    required String notes,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await db.processTreasuryTransaction(
        treasuryId: 1,
        transactionType: type,
        amount: amount,
        referenceType: refType,
        referenceId: null,
        notes: notes,
      );

      if (result['success'] == true) {
        await refreshTreasury(); // تحديث الرصيد تلقائياً بعد النجاح
      } else {
        state = state.copyWith(isLoading: false);
      }

      return result; // إرجاع النتيجة للواجهة للتعامل مع الـ Snackbar والـ Pop
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return {'success': false, 'error': e.toString()};
    }
  }
}

// 3. مزود الخدمة (Provider)
final treasuryProvider = StateNotifierProvider.autoDispose<TreasuryNotifier, TreasuryState>((ref) {
  return TreasuryNotifier(DatabaseHelper.instance);
});