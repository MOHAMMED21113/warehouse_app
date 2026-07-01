// lib/core/widgets/transaction_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/global_providers.dart';
import 'transaction_lock_dialog.dart';

class TransactionGuard {
  static Future<bool> check({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final securityState = ref.read(securityProvider).value;
    
    // Check if the transaction lock is globally enabled
    if (securityState != null && securityState.isTransactionLockEnabled) {
      // Show the dialog and wait for result
      bool authenticated = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => TransactionLockDialog(
          onSuccess: () {
            authenticated = true;
          },
        ),
      );
      return authenticated;
    } else {
      // Execute directly
      return true;
    }
  }
}

