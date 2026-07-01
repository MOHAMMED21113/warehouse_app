import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../main.dart'; // ✅ استيراد navigatorKey من main.dart

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Timer? backgroundExpiryTimer;

  void startPeriodicCheck() {
    backgroundExpiryTimer?.cancel();
    backgroundExpiryTimer = Timer.periodic(const Duration(hours: 6), (_) {
      checkAndNotifyExpiredProducts();
    });
  }

  void stopPeriodicCheck() {
    backgroundExpiryTimer?.cancel();
    backgroundExpiryTimer = null;
  }

  // ==================== تهيئة الإشعارات ====================
  Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // أيقونة التطبيق الافتراضية
      [
        NotificationChannel(
          channelKey: 'warehouse_channel',
          channelName: 'تنبيهات المخازن الذكي',
          channelDescription: 'تنبيهات انتهاء الصلاحية والمخزون المنخفض',
          defaultColor: const Color(0xFF0C1A2E), // لون الهوية
          ledColor: const Color(0xFFD4AF37),
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );

    // تفعيل مستمع الضغط على الإشعار للتوجه للصفحة المطلوبة
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );

    debugPrint('🔔 NotificationService initialized');
  }

  // ==================== دالة التوجيه عند الضغط (معدلة - بدون GetX) ====================
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // ✅ التوجيه فوراً إلى صفحة التنبيهات باستخدام navigatorKey
    // navigatorKey معرف في main.dart
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushNamed('/expired');
    } else {
      debugPrint(' navigatorKey.currentContext is null, cannot navigate to /expired');
    }
  }

  // ==================== عرض إشعار فوري ====================
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'warehouse_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  // ==================== فحص وإرسال إشعارات ====================
  Future<void> checkAndNotifyExpiredProducts() async {
    final db = DatabaseHelper.instance;

    // 🔥 توليد مهام الفواتير الآجلة تلقائياً قبل فحص الإشعارات (تنبيه قبل 3 أيام)
    await db.autoGenerateInvoiceDueTasks(daysBefore: 3);

    // 1. منع التكرار المزعج: التحقق من إرسال الإشعارات اليوم
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? lastCheck = prefs.getString('last_notification_date');

    if (lastCheck == today) {
      debugPrint('تم إرسال الإشعارات مسبقاً اليوم. لن يتم إزعاج المستخدم.');
      return;
    }

    // 🚀 استخدام استعلام SQL الخفيف المخصص للمنتجات المنتهية وقريبة الانتهاء
    final products = await db.getExpiringProducts();
    final now = DateTime.now();

    List<Map<String, dynamic>> expired = [];
    List<Map<String, dynamic>> expiringSoon = [];

    for (var product in products) {
      // 2. تصفية التوالف: تجاهل المنتجات التي رصيدها صفر
      final double currentStock = (product['current_stock'] as num?)?.toDouble() ?? 0.0;
      if (currentStock <= 0) continue;

      final expiry = product['expiry_date'];
      if (expiry != null && expiry.toString().isNotEmpty) {
        try {
          final expiryDate = DateTime.parse(expiry);
          if (expiryDate.isBefore(now)) {
            expired.add(product);
          } else if (expiryDate.difference(now).inDays <= 7 && expiryDate.isAfter(now)) {
            expiringSoon.add(product);
          }
        } catch (e) {
          // تجاهل الأخطاء في صيغة التاريخ
        }
      }
    }

    bool notified = false;

    if (expired.isNotEmpty) {
      await showNotification(
        id: 1,
        title: ' منتجات منتهية الصلاحية',
        body: 'يوجد ${expired.length} منتج منتهي الصلاحية متبقي في المخزون',
      );
      notified = true;
    }

    if (expiringSoon.isNotEmpty) {
      await showNotification(
        id: 2,
        title: ' منتجات قاربت على الانتهاء',
        body: 'يوجد ${expiringSoon.length} منتج ستنتهي صلاحيته خلال 7 أيام',
      );
      notified = true;
    }

    final lowStock = await db.getLowStockReport();
    // تصفية المخزون المنخفض أيضاً لضمان عدم ظهور منتجات رصيدها 0 إذا كان الحد الأدنى 0
    final filteredLowStock = lowStock.where((item) => ((item['current_stock'] as num?)?.toDouble() ?? 0.0) > 0).toList();

    if (filteredLowStock.isNotEmpty) {
      await showNotification(
        id: 3,
        title: ' مخزون منخفض',
        body: 'يوجد ${filteredLowStock.length} منتج وصل إلى الحد الأدنى',
      );
      notified = true;
    }

    // 3. تحديث تاريخ الفحص لمنع التكرار حتى اليوم التالي
    if (notified) {
      await prefs.setString('last_notification_date', today);
    }
  }
}