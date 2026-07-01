// lib/core/services/loan_print_service.dart

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LoanPrintService {
  static Future<pw.Font> _getArabicFont({bool bold = false}) async {
    try {
      if (bold) {
        final data = await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf');
        return pw.Font.ttf(data);
      } else {
        final data = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
        return pw.Font.ttf(data);
      }
    } catch (_) {
      try {
        if (bold) {
          final data = await rootBundle.load('assets/fonts/Alyamama-Bold.ttf');
          return pw.Font.ttf(data);
        } else {
          final data = await rootBundle.load('assets/fonts/Alyamama-Regular.ttf');
          return pw.Font.ttf(data);
        }
      } catch (_) {
        return bold ? await PdfGoogleFonts.cairoBold() : await PdfGoogleFonts.cairoRegular();
      }
    }
  }

  static Future<void> printLoanVoucher(Map<String, dynamic> loan) async {
    final pdf = pw.Document();
    final font = await _getArabicFont(bold: false);
    final fontBold = await _getArabicFont(bold: true);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold, fontFallback: [font, fontBold]),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('نظام المخازن الذكية - إذن سلفة', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم السلفة: #${loan['id']}', style: pw.TextStyle(fontSize: 14)),
                  pw.Text('التاريخ: ${loan['loan_date'] ?? ''}', style: pw.TextStyle(fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('اسم الطرف: ${loan['party_name']} (${loan['loan_type'] == 'customer' ? 'عميل' : 'مورد'})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('المبلغ الأساسي: ${loan['amount']} ريال سعودي', style: pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 6),
                    pw.Text('المبلغ المسدد: ${loan['paid_amount'] ?? 0} ريال سعودي', style: pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 6),
                    pw.Text('الرصيد المتبقي: ${loan['remaining_balance']} ريال سعودي', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    if (loan['due_date'] != null) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('تاريخ الاستحقاق: ${loan['due_date']}', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ],
                ),
              ),
              if (loan['notes'] != null && loan['notes'].toString().isNotEmpty) ...[
                pw.SizedBox(height: 15),
                pw.Text('ملاحظات: ${loan['notes']}', style: pw.TextStyle(fontSize: 13)),
              ],
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('توقيع المستلم: ............................'),
                  pw.Text('الختم المحاسبي: ............................'),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> printLoanPaymentReceipt(Map<String, dynamic> loan, double paymentAmount) async {
    final pdf = pw.Document();
    final font = await _getArabicFont(bold: false);
    final fontBold = await _getArabicFont(bold: true);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold, fontFallback: [font, fontBold]),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('إيصال استلام سداد سلفة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('رقم السلفة: #${loan['id']}'),
              pw.Text('اسم الطرف: ${loan['party_name']}'),
              pw.Text('المبلغ المدفوع في هذه الدفعة: $paymentAmount ريال سعودي', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text('التاريخ: ${DateTime.now().toIso8601String().substring(0, 10)}'),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('توقيع المستلم: ....................'),
                  pw.Text('توقيع أمين الصندوق: ....................'),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> printLoanReport(List<Map<String, dynamic>> loans) async {
    final pdf = pw.Document();
    final font = await _getArabicFont(bold: false);
    final fontBold = await _getArabicFont(bold: true);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold, fontFallback: [font, fontBold]),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text('تقرير سلف العملاء والموردين الشامل', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 15),
            pw.Table.fromTextArray(
              headers: ['المعرف', 'الطرف', 'النوع', 'المبلغ', 'المدفوع', 'المتبقي', 'الحالة'],
              data: loans.map((l) => [
                '#${l['id']}',
                l['party_name']?.toString() ?? '',
                l['loan_type'] == 'customer' ? 'عميل' : 'مورد',
                '${l['amount']}',
                '${l['paid_amount'] ?? 0}',
                '${l['remaining_balance']}',
                l['status']?.toString() ?? '',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
