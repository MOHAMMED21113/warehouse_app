// lib/modules/invoices/providers/due_reminders_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class DueRemindersState {
  final List<Map<String, dynamic>> invoices;
  final bool isLoading;
  final int? sendingToId;
  final int reminderDaysBefore;

  const DueRemindersState({
    this.invoices = const [],
    this.isLoading = false,
    this.sendingToId,
    this.reminderDaysBefore = 3,
  });

  DueRemindersState copyWith({
    List<Map<String, dynamic>>? invoices,
    bool? isLoading,
    int? sendingToId,
    int? reminderDaysBefore,
    bool clearSendingToId = false,
  }) {
    return DueRemindersState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      sendingToId: clearSendingToId ? null : (sendingToId ?? this.sendingToId),
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    );
  }
}

final dueRemindersProvider =
AutoDisposeAsyncNotifierProvider<DueRemindersNotifier, DueRemindersState>(
  DueRemindersNotifier.new,
);

class DueRemindersNotifier extends AutoDisposeAsyncNotifier<DueRemindersState> {
  @override
  Future<DueRemindersState> build() async {
    final days = ref.read(settingsProvider).value?.reminderDaysBefore ?? 3;
    return await _loadInvoices(days);
  }

  Future<DueRemindersState> _loadInvoices(int days) async {
    final db = ref.read(databaseHelperProvider);
    final invoices = await db.getUpcomingDueInvoices(days);
    return DueRemindersState(invoices: invoices, reminderDaysBefore: days);
  }

  Future<void> setReminderDays(int days) async {
    await ref.read(settingsProvider.notifier).setReminderDays(days);
    state = AsyncValue.data(await _loadInvoices(days));
  }

  Future<void> refresh() async {
    final days = state.value?.reminderDaysBefore ?? 3;
    state = AsyncValue.data(await _loadInvoices(days));
  }
}