// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/providers/global_providers.dart';
import 'core/services/notification_service.dart';
import 'core/themes/app_themes.dart';
import 'core/services/lifecycle_manager.dart';
import 'database/database_helper.dart';
import 'modules/auth/views/login_screen.dart';
import 'modules/main_menu/views/main_menu_screen.dart';
import 'data/models/user_model.dart';
import 'data/models/current_user.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Timer? globalBackgroundExpiryTimer;

void startBackgroundExpiryTimer() {
  globalBackgroundExpiryTimer?.cancel();
  globalBackgroundExpiryTimer = Timer.periodic(const Duration(hours: 6), (_) {
    NotificationService().checkAndNotifyExpiredProducts();
  });
}

void disposeBackgroundExpiryTimer() {
  globalBackgroundExpiryTimer?.cancel();
  globalBackgroundExpiryTimer = null;
  NotificationService().stopPeriodicCheck();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();  // ✅ سيقرأ الملف من جذر المشروع

  await GetStorage.init();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('خطأ أثناء تهيئة Firebase: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  await Permission.storage.request();
  await Permission.camera.request();

  await NotificationService().init();
  startBackgroundExpiryTimer();
  NotificationService().checkAndNotifyExpiredProducts();

  // ✅ إنشاء قاعدة البيانات وإضافة الصلاحيات الافتراضية
  final db = DatabaseHelper.instance;
  await db.seedDefaultPermissions();

  UserModel? initialUser;
  final users = await db.getAllUsers();
  
  bool isLoggedIn = prefs.getBool('is_logged_in') ?? prefs.getBool('skip_login') ?? false;
  int timeoutMinutes = prefs.getInt('session_timeout_minutes') ?? -1;
  String? targetLoginUser = prefs.getString('last_logged_in_username');

  // fallback for old users
  if (isLoggedIn && targetLoginUser == null && users.isNotEmpty) {
    targetLoginUser = users.first['username'] as String;
  }

  // التحقق من انتهاء الجلسة إذا كان التطبيق مغلقاً
  if (isLoggedIn && timeoutMinutes != -1) {
    if (timeoutMinutes == 0) {
      isLoggedIn = false;
      await prefs.setBool('is_logged_in', false);
    } else {
      final lastActiveStr = prefs.getString('last_active_time');
      if (lastActiveStr != null) {
        final lastActive = DateTime.tryParse(lastActiveStr);
        if (lastActive != null && DateTime.now().difference(lastActive).inMinutes >= timeoutMinutes) {
          isLoggedIn = false;
          await prefs.setBool('is_logged_in', false);
        }
      }
    }
  }

  // الدخول المباشر كضيف إذا لم تكن هناك أي حسابات في النظام
  if (users.isEmpty) {
    isLoggedIn = true;
    targetLoginUser = null;
  }

  if (isLoggedIn && targetLoginUser != null) {
    final userMap = await db.getUserByUsername(targetLoginUser);
    if (userMap != null) {
      initialUser = UserModel.fromMap(userMap);
      CurrentUser.id = initialUser.id;
      CurrentUser.username = initialUser.username;
      CurrentUser.fullName = initialUser.fullName;
      CurrentUser.role = initialUser.role;
      CurrentUser.hasBiometric = initialUser.hasBiometric;
      CurrentUser.securePermissions = initialUser.securePermissions;
    }
  } else if (isLoggedIn && targetLoginUser == null) {
    // وضع الضيف بصلاحيات كاملة
    initialUser = const UserModel(
      id: null,
      username: 'مستخدم محلي',
      fullName: 'مستخدم محلي',
      role: 'admin',
      permissions: ['*'],
      securePermissions: [],
      hasBiometric: false,
    );
    CurrentUser.id = initialUser.id;
    CurrentUser.username = initialUser.username;
    CurrentUser.fullName = initialUser.fullName;
    CurrentUser.role = initialUser.role;
    CurrentUser.hasBiometric = initialUser.hasBiometric;
    CurrentUser.securePermissions = initialUser.securePermissions;
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (initialUser != null)
          initialUserProvider.overrideWithValue(initialUser),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  late final LifecycleManager _lifecycleManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleManager = LifecycleManager(ref, navigatorKey);
    _lifecycleManager.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      disposeBackgroundExpiryTimer();
    } else if (state == AppLifecycleState.resumed) {
      if (globalBackgroundExpiryTimer == null || !globalBackgroundExpiryTimer!.isActive) {
        startBackgroundExpiryTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeBackgroundExpiryTimer();
    _lifecycleManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(securityProvider); // نُراقب securityProvider لإعادة البناء عند تغير حالة الجلسة

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'المخازن الذكي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'YE'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'YE')],
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeMode,

      home: ref.watch(initialUserProvider) != null ? const MainMenuScreen() : const LoginScreen(),
    );
  }
}
