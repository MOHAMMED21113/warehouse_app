// lib/core/providers/global_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../../main.dart';

// استيرادات المنتجات
import '../../data/repositories/product_repository_impl.dart';
import '../../database/database_helper.dart';
import '../../data/datasources/product_local_datasource.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/add_product_usecase.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../domain/usecases/get_products_paginated_usecase.dart';
import '../../domain/usecases/search_product_by_barcode_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';

// استيرادات المهام (الجديدة)
import '../../data/datasources/task_local_datasource.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/add_task_usecase.dart';
import '../../domain/usecases/complete_task_usecase.dart';
import '../../domain/usecases/delete_task_usecase.dart';
import '../../domain/usecases/get_overdue_tasks_usecase.dart';
import '../../domain/usecases/get_tasks_usecase.dart';
import '../../domain/usecases/update_task_partial_usecase.dart';
import '../../domain/usecases/update_task_usecase.dart';

// استيرادات المستخدمين والصلاحيات
import '../../data/models/user_model.dart';
import '../utils/hash_util.dart';

// استيرادات المزودين والشاشات لتسجيل الخروج
import '../../modules/warehouses/providers/warehouses_provider.dart';
import '../../modules/invoices/providers/invoices_list_provider.dart';
import '../../modules/dashboard/providers/dashboard_provider.dart';
import '../../modules/accounting/providers/financial_vouchers_provider.dart';
import '../../modules/accounting/providers/debtors_provider.dart';
import '../../modules/accounting/providers/creditors_provider.dart';
import '../../modules/loans/providers/loans_provider.dart';
import '../../modules/auth/views/login_screen.dart';

// ============================================================
//  1. Theme
// ============================================================
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeModeNotifier(this._prefs) : super(_loadTheme(_prefs));

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'light') return ThemeMode.light;
    return ThemeMode.light;
  }

  @override
  set state(ThemeMode value) {
    if (state != value) {
      super.state = value;
      _prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
    }
  }

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

// ============================================================
//  2. Storage
// ============================================================
final getStorageProvider = Provider<GetStorage>((ref) => GetStorage());
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main.dart');
});

// ============================================================
//  3. Database
// ============================================================
final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

// ============================================================
//  4. Security
// ============================================================
class SecurityState {
  final bool isBiometricEnabled;
  final bool isTransactionLockEnabled;
  final bool hasLockCredentials;
  final bool isSessionUnlocked;
  final String username;

  const SecurityState({
    this.isBiometricEnabled = false,
    this.isTransactionLockEnabled = false,
    this.hasLockCredentials = false,
    this.isSessionUnlocked = false,
    this.username = '',
  });

  SecurityState copyWith({
    bool? isBiometricEnabled,
    bool? isTransactionLockEnabled,
    bool? hasLockCredentials,
    bool? isSessionUnlocked,
    String? username,
  }) =>
      SecurityState(
        isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
        isTransactionLockEnabled:
        isTransactionLockEnabled ?? this.isTransactionLockEnabled,
        hasLockCredentials: hasLockCredentials ?? this.hasLockCredentials,
        isSessionUnlocked: isSessionUnlocked ?? this.isSessionUnlocked,
        username: username ?? this.username,
      );
}

// ================== طبقة البيانات (Data Layer / Repository) ==================
class SecurityRepository {
  final GetStorage _box;
  SecurityRepository(this._box);

  bool get isBiometricEnabled => _box.read<bool>('biometric_enabled') ?? false;
  bool get isTransactionLockEnabled => _box.read<bool>('transaction_lock_enabled') ?? false;
  String? get username => _box.read('app_username');
  String? get password => _box.read('app_password');
  bool get hasCredentials => username != null;

  Future<void> saveCredentials(String u, String p) async {
    await _box.write('app_username', u);
    await _box.write('app_password', p);
  }

  Future<void> savePassword(String newP) async {
    await _box.write('app_password', newP);
  }

  Future<void> removeAllSecurityData() async {
    await _box.remove('app_username');
    await _box.remove('app_password');
    await _box.remove('biometric_enabled');
    await _box.remove('transaction_lock_enabled');
  }

  Future<void> setBiometric(bool v) async => await _box.write('biometric_enabled', v);
  Future<void> setTransactionLock(bool v) async => await _box.write('transaction_lock_enabled', v);
}

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(ref.read(getStorageProvider));
});

// ================== طبقة التحكم (Domain / Presentation Notifier) ==================
final securityProvider = AsyncNotifierProvider<SecurityNotifier, SecurityState>(
  SecurityNotifier.new,
);

class SecurityNotifier extends AsyncNotifier<SecurityState> {
  late SecurityRepository _repo;

  @override
  Future<SecurityState> build() async {
    _repo = ref.read(securityRepositoryProvider);

    final biometric = _repo.isBiometricEnabled;
    final transLock = _repo.isTransactionLockEnabled;
    final hasCred = _repo.hasCredentials;
    final initialSessionUnlocked = !hasCred;

    return SecurityState(
      isBiometricEnabled: biometric,
      isTransactionLockEnabled: transLock,
      hasLockCredentials: hasCred,
      isSessionUnlocked: initialSessionUnlocked,
      username: _repo.username ?? '',
    );
  }

  Future<void> unlockSession() async {
    state = AsyncValue.data(state.value!.copyWith(isSessionUnlocked: true));
  }

  Future<void> lockSession() async {
    if (state.value!.hasLockCredentials) {
      state = AsyncValue.data(state.value!.copyWith(isSessionUnlocked: false));
    }
  }

  Future<void> setCredentials(String u, String p) async {
    await _repo.saveCredentials(u, p);
    state = AsyncValue.data(state.value!.copyWith(
      hasLockCredentials: true,
      isSessionUnlocked: true,
      username: u,
    ));
  }

  Future<bool> verifyCredentials(String u, String p) async {
    return _repo.username == u && _repo.password == p;
  }

  Future<bool> changePassword(String u, String oldP, String newP) async {
    if (await verifyCredentials(u, oldP)) {
      await _repo.savePassword(newP);
      return true;
    }
    return false;
  }

  Future<void> deleteCredentials() async {
    await _repo.removeAllSecurityData();
    state = const AsyncValue.data(SecurityState(
      hasLockCredentials: false,
      isSessionUnlocked: true,
    ));
  }

  Future<void> toggleBiometric(bool v) async {
    await _repo.setBiometric(v);
    state = AsyncValue.data(state.value!.copyWith(isBiometricEnabled: v));
  }

  Future<void> toggleTransactionLock(bool v) async {
    await _repo.setTransactionLock(v);
    state = AsyncValue.data(state.value!.copyWith(isTransactionLockEnabled: v));
  }

  Future<void> logout([BuildContext? context]) async {
    disposeBackgroundExpiryTimer();
    NotificationService().stopPeriodicCheck();
    await lockSession();
    ref.read(currentUserProvider.notifier).state = null;
    ref.invalidate(usersProvider);
    ref.invalidate(warehousesProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(suppliersProvider);
    ref.invalidate(invoicesListProvider);
    ref.invalidate(loansProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(financialVouchersProvider);
    ref.invalidate(debtorsProvider);
    ref.invalidate(creditorsProvider);
    ref.invalidate(databaseHelperProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (context != null && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

// ============================================================
//  5. Settings
// ============================================================
class SettingsState {
  final String valuationMethod;
  final int reminderDaysBefore;
  final int sessionTimeoutMinutes;

  const SettingsState({
    this.valuationMethod = 'WAC',
    this.reminderDaysBefore = 3,
    this.sessionTimeoutMinutes = 0,
  });

  SettingsState copyWith({
    String? valuationMethod,
    int? reminderDaysBefore,
    int? sessionTimeoutMinutes,
  }) =>
      SettingsState(
        valuationMethod: valuationMethod ?? this.valuationMethod,
        reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
        sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      );
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    return SettingsState(
      valuationMethod: prefs.getString('valuation_method') ?? 'WAC',
      reminderDaysBefore: prefs.getInt('reminder_days_before') ?? 3,
      sessionTimeoutMinutes: prefs.getInt('session_timeout_minutes') ?? -1,
    );
  }

  Future<void> setValuationMethod(String m) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('valuation_method', m);
    state = AsyncValue.data(state.value!.copyWith(valuationMethod: m));
  }

  Future<void> setReminderDays(int d) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('reminder_days_before', d);
    state = AsyncValue.data(state.value!.copyWith(reminderDaysBefore: d));
  }

  Future<void> setSessionTimeout(int minutes) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('session_timeout_minutes', minutes);
    state = AsyncValue.data(state.value!.copyWith(sessionTimeoutMinutes: minutes));
  }
}

// ============================================================
//  6. Product Dependencies
// ============================================================
final productLocalDataSourceProvider = Provider<ProductLocalDataSource>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return ProductLocalDataSource(db);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final ds = ref.watch(productLocalDataSourceProvider);
  return ProductRepositoryImpl(ds);
});

final addProductUseCaseProvider =
Provider((ref) => AddProductUseCase(ref.watch(productRepositoryProvider)));
final updateProductUseCaseProvider =
Provider((ref) => UpdateProductUseCase(ref.watch(productRepositoryProvider)));
final getProductsPaginatedUseCaseProvider =
Provider((ref) => GetProductsPaginatedUseCase(ref.watch(productRepositoryProvider)));
final searchProductByBarcodeUseCaseProvider =
Provider((ref) => SearchProductByBarcodeUseCase(ref.watch(productRepositoryProvider)));
final deleteProductUseCaseProvider =
Provider((ref) => DeleteProductUseCase(ref.watch(productRepositoryProvider)));

// ============================================================
//  7. Task Dependencies (NEW)
// ============================================================
// ملاحظة: هذا القسم تم إنشاؤه حديثاً ويحل محل التعريفات القديمة المكررة.
final taskLocalDataSourceProvider = Provider<TaskLocalDataSource>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return TaskLocalDataSource(db);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final ds = ref.watch(taskLocalDataSourceProvider);
  return TaskRepositoryImpl(ds);
});

final getTasksUseCaseProvider =
Provider((ref) => GetTasksUseCase(ref.watch(taskRepositoryProvider)));
final addTaskUseCaseProvider =
Provider((ref) => AddTaskUseCase(ref.watch(taskRepositoryProvider)));
final updateTaskUseCaseProvider =
Provider((ref) => UpdateTaskUseCase(ref.watch(taskRepositoryProvider)));
final updateTaskPartialUseCaseProvider =
Provider((ref) => UpdateTaskPartialUseCase(ref.watch(taskRepositoryProvider)));
final deleteTaskUseCaseProvider =
Provider((ref) => DeleteTaskUseCase(ref.watch(taskRepositoryProvider)));
final completeTaskUseCaseProvider =
Provider((ref) => CompleteTaskUseCase(ref.watch(taskRepositoryProvider)));
final getOverdueTasksUseCaseProvider =
Provider((ref) => GetOverdueTasksUseCase(ref.watch(taskRepositoryProvider)));

// ============================================================
//  8. User Management (RBAC)
// ============================================================
final initialUserProvider = Provider<UserModel?>((ref) => null);
final currentUserProvider = StateProvider<UserModel?>((ref) => ref.watch(initialUserProvider));

final usersProvider = AsyncNotifierProvider<UsersNotifier, List<UserModel>>(
      () => UsersNotifier(),
);

class UsersNotifier extends AsyncNotifier<List<UserModel>> {
  late DatabaseHelper _db;

  @override
  Future<List<UserModel>> build() async {
    _db = ref.read(databaseHelperProvider);
    return await _loadUsers();
  }

  Future<List<UserModel>> _loadUsers() async {
    final raw = await _db.getAllUsersRaw();
    return raw.map((e) => UserModel.fromMap(e)).toList();
  }

  Future<bool> addUser(UserModel user, String password) async {
    try {
      final map = user.toMap();
      map['password_hash'] = await HashUtil.hashPassword(password);
      map['created_at'] = DateTime.now().toIso8601String();
      map.remove('id');
      await _db.insertUserRaw(map);
      state = AsyncValue.data(await _loadUsers());
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> updateUser(UserModel user, {String? newPassword}) async {
    try {
      final map = user.toMap();
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        map['password_hash'] = await HashUtil.hashPassword(newPassword.trim());
      } else {
        final oldData = await _db.getUserByIdRaw(user.id!);
        if (oldData != null) {
          map['password_hash'] = oldData['password_hash'];
        }
      }
      await _db.updateUserRaw(map);
      state = AsyncValue.data(await _loadUsers());

      // تحديث المستخدم الحالي إذا كان هو نفسه
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null && currentUser.id == user.id) {
        final raw = await _db.getUserByIdRaw(user.id!);
        if (raw != null) {
          ref.read(currentUserProvider.notifier).state = UserModel.fromMap(raw);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null && currentUser.id == id) {
        throw Exception('لا يمكن حذف الحساب الذي تستخدمه حالياً');
      }
      await _db.deleteUserRaw(id);
      state = AsyncValue.data(await _loadUsers());
      return true;
    } catch (e) {
      return false;
    }
  }
}