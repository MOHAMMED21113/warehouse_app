// lib/core/services/lifecycle_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../modules/auth/views/login_screen.dart';
import '../providers/global_providers.dart';
import '../../data/models/current_user.dart';

class LifecycleManager extends WidgetsBindingObserver {
  final WidgetRef _ref;
  final GlobalKey<NavigatorState> _navigatorKey;
  bool _isLoginScreenShown = false;
  DateTime? _pausedTime; // متغير جديد لحفظ وقت الخروج

  LifecycleManager(this._ref, this._navigatorKey);

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // ✅ التطبيق ذهب إلى الخلفية -> نسجل وقت الخروج
      _pausedTime = DateTime.now();
      _ref.read(sharedPreferencesProvider).setString('last_active_time', _pausedTime!.toIso8601String());
      print('⏸️ LifecycleManager: التطبيق في الخلفية (تم تسجيل الوقت: $_pausedTime)');

    } else if (state == AppLifecycleState.resumed) {
      // ✅ عند العودة للتطبيق
      if (CurrentUser.id != null && _pausedTime != null) {

        // جلب الإعدادات لمعرفة المدة المسموحة
        final settings = _ref.read(settingsProvider).valueOrNull;
        final timeoutMinutes = settings?.sessionTimeoutMinutes ?? 0;

        // حساب الوقت المنقضي منذ الخروج
        final difference = DateTime.now().difference(_pausedTime!);
        print('⏳ LifecycleManager: عاد التطبيق بعد ${difference.inSeconds} ثانية');

        // Lock if timeout = 0, or if time difference exceeds the defined minutes (and it's not -1)
        if (timeoutMinutes == 0 || (timeoutMinutes != -1 && difference.inMinutes >= timeoutMinutes)) {
          _showLoginScreen();
          print('🔒 LifecycleManager: انتهت مدة الجلسة، تم القفل!');
        } else {
          print('✅ LifecycleManager: لم تنته الجلسة (${timeoutMinutes} دقيقة). دخول مباشر.');
        }

        _pausedTime = null; // تصفير الوقت
      }
    }
  }

  void _showLoginScreen() {
    if (_isLoginScreenShown) return;

    _isLoginScreenShown = true;
    _navigatorKey.currentState
        ?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    )
        .then((_) {
      _isLoginScreenShown = false;
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}