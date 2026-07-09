// lib/modules/accounting/providers/financial_vouchers_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_helper.dart';

class FinancialVouchersState {
  final bool isLoading;
  final List<Map<String, dynamic>> vouchers;
  final List<Map<String, dynamic>> expenseCategories;
  final List<Map<String, dynamic>> incomeCategories;

  FinancialVouchersState({
    this.isLoading = true,
    this.vouchers = const [],
    this.expenseCategories = const [],
    this.incomeCategories = const [],
  });

  FinancialVouchersState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? vouchers,
    List<Map<String, dynamic>>? expenseCategories,
    List<Map<String, dynamic>>? incomeCategories,
  }) {
    return FinancialVouchersState(
      isLoading: isLoading ?? this.isLoading,
      vouchers: vouchers ?? this.vouchers,
      expenseCategories: expenseCategories ?? this.expenseCategories,
      incomeCategories: incomeCategories ?? this.incomeCategories,
    );
  }
}

class FinancialVouchersNotifier extends StateNotifier<FinancialVouchersState> {
  final DatabaseHelper db;

  FinancialVouchersNotifier(this.db) : super(FinancialVouchersState()) {
    loadAllData();
  }

  // 🚀 جلب البيانات وتحديث الشاشة
  Future<void> loadAllData() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final vouchersList = await db.getAllFinancialVouchers();
      final expenses = await db.getFinancialCategories('expense');
      final incomes = await db.getFinancialCategories('income');

      if (!mounted) return;
      state = state.copyWith(
        vouchers: vouchersList,
        expenseCategories: expenses,
        incomeCategories: incomes,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('خطأ في تحميل السندات: $e');
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  // 🚀 إضافة سند
  Future<Map<String, dynamic>> addVoucher({
    required int categoryId,
    required String type,
    required double amount,
    required String notes,
    String? personName,
  }) async {
    if (!mounted) return {'success': false, 'error': 'Disposed'};
    state = state.copyWith(isLoading: true);
    try {
      final result = await db.createFinancialVoucher(
        categoryId: categoryId,
        treasuryId: 1,
        type: type,
        amount: amount,
        notes: notes,
        personName: personName,
      );

      if (result['success'] == true) {
        await loadAllData();
      } else {
        if (mounted) state = state.copyWith(isLoading: false);
      }

      return result;
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🟠 إصلاح عالٍ 5: تعديل سند مع ضبط رصيد الخزينة — داخل معاملة ذرية
  Future<Map<String, dynamic>> updateVoucher({
    required int voucherId,
    required int categoryId,
    required double amount,
    required String notes,
    String? personName,
  }) async {
    if (!mounted) return {'success': false, 'error': 'Disposed'};
    state = state.copyWith(isLoading: true);
    try {
      final oldVoucher = state.vouchers.firstWhere((v) => v['id'] == voucherId);
      final type = oldVoucher['type'] as String;
      final oldAmount = (oldVoucher['amount'] as num).toDouble();
      final difference = amount - oldAmount;

      final database = await db.database;

      // 🔴 تغليف جميع العمليات الثلاث في معاملة ذرية واحدة
      await database.transaction((txn) async {
        // 1. تحديث بيانات السند
        await txn.update(
          'financial_vouchers',
          {
            'category_id': categoryId,
            'amount': amount,
            'notes': notes,
            if (personName != null) 'person_name': personName,
          },
          where: 'id = ?',
          whereArgs: [voucherId],
        );

        // 2. تحديث الرصيد بناءً على الفرق
        if (difference != 0) {
          if (type == 'payment') {
            await txn.rawUpdate(
                'UPDATE treasuries SET balance = balance - ? WHERE id = 1',
                [difference]);
          } else {
            await txn.rawUpdate(
                'UPDATE treasuries SET balance = balance + ? WHERE id = 1',
                [difference]);
          }

          // 3. تحديث حركة الخزينة المرتبطة
          await txn.update(
            'treasury_transactions',
            {'amount': amount, 'notes': notes},
            where: 'reference_type IN (?, ?) AND reference_id = ?',
            whereArgs: ['expense_voucher', 'income_voucher', voucherId],
          );
        }
      });

      await loadAllData();
      return {'success': true};
    } catch (e) {
      debugPrint('خطأ في التحديث: $e');
      if (mounted) state = state.copyWith(isLoading: false);
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🟠 إصلاح عالٍ 5: حذف سند واسترجاع رصيد الخزينة — داخل معاملة ذرية
  Future<Map<String, dynamic>> deleteVoucher(int voucherId) async {
    if (!mounted) return {'success': false, 'error': 'Disposed'};
    state = state.copyWith(isLoading: true);
    try {
      final oldVoucher = state.vouchers.firstWhere((v) => v['id'] == voucherId);
      final type = oldVoucher['type'] as String;
      final amount = (oldVoucher['amount'] as num).toDouble();

      final database = await db.database;

      // 🔴 تغليف جميع العمليات الثلاث في معاملة ذرية واحدة
      await database.transaction((txn) async {
        // 1. إرجاع الرصيد
        if (type == 'payment') {
          await txn.rawUpdate(
              'UPDATE treasuries SET balance = balance + ? WHERE id = 1',
              [amount]);
        } else {
          await txn.rawUpdate(
              'UPDATE treasuries SET balance = balance - ? WHERE id = 1',
              [amount]);
        }

        // 2. حذف العملية من سجل الخزينة
        await txn.delete(
            'treasury_transactions',
            where: 'reference_type IN (?, ?) AND reference_id = ?',
            whereArgs: ['expense_voucher', 'income_voucher', voucherId]);

        // 3. حذف السند المالي
        await txn.delete('financial_vouchers',
            where: 'id = ?', whereArgs: [voucherId]);
      });

      await loadAllData();
      return {'success': true};
    } catch (e) {
      debugPrint('خطأ في الحذف: $e');
      if (mounted) state = state.copyWith(isLoading: false);
      return {'success': false, 'error': e.toString()};
    }
  }

  // 🚀 إعادة تنشيط وتحديث البيانات بأمان
  Future<void> refreshData() async {
    if (!mounted) return;
    await loadAllData();
  }
}

final financialVouchersProvider =
    StateNotifierProvider.autoDispose<FinancialVouchersNotifier, FinancialVouchersState>(
        (ref) {
  final notifier = FinancialVouchersNotifier(DatabaseHelper.instance);
  ref.onDispose(() {
    debugPrint('🗑️ تم تنظيف FinancialVouchersNotifier بأمان');
  });
  return notifier;
});