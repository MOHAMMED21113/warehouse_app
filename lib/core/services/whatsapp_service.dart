// lib/utils/whatsapp_service.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  // إرسال فاتورة عبر واتساب متضمنة كافة التفاصيل
  static Future<bool> sendInvoiceToWhatsApp({
    required String phoneNumber,
    required String customerName,
    required String invoiceNumber,
    required String date,
    required double totalAmount,
    required String paymentStatus,
    required double paidAmount,
    required List<Map<String, dynamic>> items,
    required String shopName,
    // ✅ الحقول الجديدة المضافة (اختيارية لتجنب تعطل الكود القديم)
    double subtotal = 0.0,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    String paymentType = 'كاش',
    String notes = '',
  }) async {
    try {
      // 1. تنظيف رقم الهاتف
      if (phoneNumber.isEmpty) return false;
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }

      String finalPhone = cleanPhone;

      // 2. معالجة مفاتيح الدول بذكاء
      if (cleanPhone.startsWith('966') ||
          cleanPhone.startsWith('967') ||
          cleanPhone.startsWith('20') ||
          cleanPhone.startsWith('971')) {
        finalPhone = cleanPhone;
      } else if (cleanPhone.startsWith('5') && cleanPhone.length == 9) {
        finalPhone = '966$cleanPhone';
      } else if (cleanPhone.startsWith('7') && cleanPhone.length == 9) {
        finalPhone = '967$cleanPhone';
      } else if ((cleanPhone.startsWith('10') ||
              cleanPhone.startsWith('11') ||
              cleanPhone.startsWith('12')) &&
          cleanPhone.length == 10) {
        finalPhone = '20$cleanPhone';
      } else {
        // مفتاح اليمن الافتراضي لتطابق الأرقام المحلية
        finalPhone = '967$cleanPhone';
      }

      if (finalPhone.length < 10 || finalPhone.length > 15) {
        debugPrint(' رقم الهاتف غير صالح: $finalPhone');
        return false;
      }

      // 3. بناء قائمة المنتجات
      String itemsText = '';
      double calculatedSubtotal = 0; // لحساب المجموع الفرعي إذا لم يتم تمريره

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final String name = item['productName']?.toString() ?? 'صنف غير معروف';

        final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final double price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final double totalItem = qty * price;

        calculatedSubtotal += totalItem;

        itemsText += '▪️ $name\n';
        itemsText +=
            '    $qty × ${price.toStringAsFixed(2)} = *${totalItem.toStringAsFixed(2)}* ريال\n';

        if (i < items.length - 1) itemsText += '┄┄┄┄┄┄┄┄┄┄┄┄\n';
      }

      // إذا كان المجموع الفرعي الممرر صفر، نستخدم المحسوب من الأصناف
      if (subtotal == 0) subtotal = calculatedSubtotal;

      // 4. بناء الكتل النصية الديناميكية (Dynamic Blocks)

      // -- كتلة التفاصيل المالية --
      String financialBlock = '';
      if (subtotal > 0) {
        financialBlock +=
            ' المجموع الفرعي: ${subtotal.toStringAsFixed(2)} ريال\n';
      }
      if (discountAmount > 0) {
        financialBlock +=
            '  الخصم: -${discountAmount.toStringAsFixed(2)} ريال\n';
      }
      if (taxAmount > 0) {
        financialBlock += '  الضريبة: +${taxAmount.toStringAsFixed(2)} ريال\n';
      }
      financialBlock +=
          ' *الإجمالي النهائي: ${totalAmount.toStringAsFixed(2)} ريال*';

      // -- كتلة الدفع --
      final double remainingAmount = totalAmount - paidAmount;
      String paymentBlock = '';
      paymentBlock += ' طريقة الدفع: $paymentType\n';
      paymentBlock +=
          ' حالة الدفع: ${paymentStatus == 'كامل' ? ' كامل' : ' آجل / جزئي'}\n';
      paymentBlock += ' المدفوع: ${paidAmount.toStringAsFixed(2)} ريال';
      if (remainingAmount > 0) {
        paymentBlock +=
            '\n المتبقي: *${remainingAmount.toStringAsFixed(2)} ريال*';
      }

      // -- كتلة الملاحظات --
      String notesBlock = '';
      if (notes.trim().isNotEmpty) {
        notesBlock = '\n➖➖➖➖➖➖➖➖➖➖\n *ملاحظات:*\n${notes.trim()}';
      }

      final String safeDate = date.length >= 10 ? date.substring(0, 10) : date;

      // 5. تجميع الرسالة النهائية
      final message =
          '''
 *فاتورة إلكترونية* | *$shopName*
➖➖➖➖➖➖➖➖➖➖
 التاريخ: $safeDate
 رقم الفاتورة: $invoiceNumber
 العميل: $customerName

 *المنتجات:*
$itemsText
➖➖➖➖➖➖➖➖➖➖
$financialBlock
➖➖➖➖➖➖➖➖➖➖
$paymentBlock$notesBlock

 *شكراً لثقتكم بنا*
''';

      // 6. الإرسال عبر واتساب
      final encodedMessage = Uri.encodeComponent(message);

      final Uri whatsappUri = Uri.parse(
        'whatsapp://send?phone=$finalPhone&text=$encodedMessage',
      );
      final Uri webUri = Uri.parse(
        'https://wa.me/$finalPhone?text=$encodedMessage',
      );

      try {
        if (await canLaunchUrl(whatsappUri)) {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
          return true;
        } else if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          debugPrint(' لم يتم العثور على تطبيق واتساب');
          return false;
        }
      } catch (e) {
        debugPrint(' خطأ في فتح واتساب: $e');
        return false;
      }
    } catch (e) {
      debugPrint(' خطأ غير متوقع: $e');
      return false;
    }
  }
}
