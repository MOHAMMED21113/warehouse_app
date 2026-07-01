import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // 1. بناء التطبيق وتشغيله
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // 2. التحقق من أن التطبيق يعمل والشاشة ظهرت بنجاح
    expect(find.byType(MyApp), findsOneWidget);

    // 3. ضخ واجهة فارغة لإجبار التطبيق على استدعاء dispose() وإغلاق الـ Timer
    await tester.pumpWidget(Container());
    
    // الانتظار للحظة حتى تتوقف كل المؤقتات بشكل نهائي
    await tester.pumpAndSettle(); 
  });
}
