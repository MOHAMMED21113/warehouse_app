// lib/domain/usecases/ai_chat_usecase.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ استيراد flutter_dotenv
import '../../database/database_helper.dart';

class AiChatUseCase {
  final DatabaseHelper _dbHelper;

  // ✅ قراءة المفتاح من ملف .env (وليس من --dart-define)
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  AiChatUseCase(this._dbHelper);

  Future<String> processUserQuery(String query) async {
    // ✅ التحقق من وجود المفتاح
    if (_apiKey.isEmpty) {
      return "⚠️ لم يتم إعداد مفتاح API. يرجى إضافة GEMINI_API_KEY في ملف .env";
    }

    try {
      final db = await _dbHelper.database;

      String dbContext = "البيانات الفعلية المتاحة في النظام حالياً:\n\n";

      // 1. 📦 المنتجات المتوفرة (نظرة عامة)
      try {
        final productsResult = await db.rawQuery('SELECT name, current_stock, unit_price FROM products LIMIT 20');
        dbContext += " المنتجات:\n";
        for (var row in productsResult) {
          dbContext += "- ${row['name']} | الكمية: ${row['current_stock']} | السعر: ${row['unit_price']}\n";
        }
      } catch (_) {}

      // 2. 🚨 نظام النواقص (المنتجات التي وصلت للحد الأدنى)
      try {
        final lowStockResult = await db.rawQuery('SELECT name, current_stock, min_stock FROM products WHERE current_stock <= min_stock AND is_active = 1');
        dbContext += "\n تنبيهات النواقص:\n";
        if (lowStockResult.isEmpty) dbContext += "المخزون ممتاز، لا توجد نواقص.\n";
        for (var row in lowStockResult) {
          dbContext += "- ${row['name']} (متبقي: ${row['current_stock']} | الحد الأدنى: ${row['min_stock']})\n";
        }
      } catch (_) {}

      // 3. 🎁 نظام البونص (العروض)
      try {
        final bonusResult = await db.rawQuery('''
          SELECT p.name AS main_product, p.bonus_required_qty, p.bonus_free_qty, p2.name AS free_product
          FROM products p LEFT JOIN products p2 ON p.bonus_free_product_id = p2.id WHERE p.bonus_enabled = 1
        ''');
        dbContext += "\n عروض البونص:\n";
        if (bonusResult.isEmpty) dbContext += "لا توجد عروض بونص مفعلة.\n";
        for (var row in bonusResult) {
          dbContext += "- شراء ${row['bonus_required_qty']} من (${row['main_product']}) = يحصل على ${row['bonus_free_qty']} مجاناً من (${row['free_product'] ?? 'نفس المنتج'})\n";
        }
      } catch (_) {}

      // 4. 💰 الخزينة
      try {
        final treasuryResult = await db.rawQuery('SELECT name, balance FROM treasuries');
        dbContext += "\n أرصدة الخزينة:\n";
        for (var row in treasuryResult) {
          dbContext += "- ${row['name']}: ${row['balance']} ريال\n";
        }
      } catch (_) {}

      // 5. 📉 ديون العملاء (أموال لنا في السوق)
      try {
        final debtorsResult = await db.rawQuery('SELECT name, balance FROM customers WHERE balance > 0 LIMIT 10');
        dbContext += "\n📍 العملاء المدينون (لدينا أموال عندهم):\n";
        for (var row in debtorsResult) {
          dbContext += "- ${row['name']}: عليه ${row['balance']} ريال\n";
        }
      } catch (_) {}

      // 6. 🧾 فواتير البيع السابقة
      try {
        final salesRes = await db.rawQuery('SELECT invoice_number, customer_name, total_amount, paid_amount, date FROM sales_invoices ORDER BY date DESC LIMIT 15');
        dbContext += "\n📍 أحدث فواتير البيع:\n";
        for (var row in salesRes) {
          dbContext += "- رقم: ${row['invoice_number']} | العميل: ${row['customer_name'] ?? 'نقدي'} | الإجمالي: ${row['total_amount']} | المدفوع: ${row['paid_amount']} | التاريخ: ${row['date']}\n";
        }
      } catch (_) {}

      // 7. 🛒 فواتير الشراء السابقة
      try {
        final purchRes = await db.rawQuery('SELECT invoice_number, supplier_name, total_amount, paid_amount, date FROM purchase_invoices ORDER BY date DESC LIMIT 15');
        dbContext += "\n أحدث فواتير الشراء:\n";
        for (var row in purchRes) {
          dbContext += "- رقم: ${row['invoice_number']} | المورد: ${row['supplier_name'] ?? 'غير محدد'} | الإجمالي: ${row['total_amount']} | المدفوع: ${row['paid_amount']} | التاريخ: ${row['date']}\n";
        }
      } catch (_) {}

      // 8. 💸 أموال الموردين (ديون علينا)
      try {
        final credRes = await db.rawQuery('SELECT name, balance FROM suppliers WHERE balance > 0 LIMIT 10');
        dbContext += "\n الموردون الدائنون (لهم أموال علينا):\n";
        for (var row in credRes) {
          dbContext += "- ${row['name']}: يطالبنا بـ ${row['balance']} ريال\n";
        }
      } catch (_) {}

      // إعداد الموديل
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      // 🔥 التعليمات الخاصة بالتصنيف التلقائي والكود السري
      final String prompt = """
      أنت المساعد الذكي المالي والإداري الشامل لنظام إدارة ومرجع الحسابات ومساعدتي في ادارة النظام  المستودعات.
      استخدم البيانات الفعلية التالية للإجابة على استفسار المستخدم:
      
      $dbContext
      
      سؤال المستخدم: $query
      
      التعليمات الصارمة التي يجب اتباعها حرفياً:
      1. أنت الآن ترى كل شيء: فواتير الشراء، فواتير البيع، ديون العملاء، أموال الموردين، الخزينة، العروض، النواقص، والمنتجات، تحليل الارباح الصافي.
      2. ابحث في القسم المناسب حسب سؤال المستخدم وأجب بأسلوب مباشر واحترافي ودقيق.
      3. إذا كان السؤال عن "حالة" أو "كمية" منتج ولم تجده في البيانات، أخبره أنه غير مسجل.
      4.  استثناء هام جداً (اقتراح التصنيفات): إذا طلب منك المستخدم "اقتراح تصنيف" أو "معرفة تصنيف" (مجموعة، فئة، صنف الفرعي) لمنتج غير موجود في النظام (مثل دواء أو مشروبات او ملعلبات او بهارات او إلكترونيات جديدة)، لا تعتذر! بل استخدم معرفتك العامة (General Knowledge) تقم اقتراح بي اسلواب ذكي ومنظم وسهل الفهم أفضل شجرة تصنيف علمية وتجارية له،يوجب لك تساله ماهو المنتج الذي تريد تضيفه وبعد ذلك تقم بي"اقتراح تصنيف" أو "معرفة تصنيف" (مجموعة، فئة، صنف الفرعي) ويكن اقترح مختصر.
      5.  كود الإنشاء التلقائي: عندما تقترح تصنيفاً لمنتج جديد، يجب أن تنهي إجابتك دائماً بهذا الكود السري بالصيغة التالية تماماً (في سطر منفصل) ليقرأه النظام:
      [CREATE_CLASS|اسم_المجموعة|اسم_الفئة|اسم_الصنف]
      مثال عملي: [CREATE_CLASS|مواد غذائية|مشروبات|مياء]
      مثال عملي: [CREATE_CLASS|مواد غذائية|معلبات|بقوليات]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "لم أتمكن من توليد إجابة واضحة.";

    } catch (e) {
      return "حدث خطأ أثناء الاتصال: ${e.toString()}";
    }
  }
}