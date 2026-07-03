// lib/core/services/inventory_adjustment_printer.dart

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryAdjustmentPrinter {
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

  /// طباعة إذن تسوية أو تقرير تلف لصنف محدد
  static Future<void> printSingleAdjustment(Map<String, dynamic> adj) async {
    final pdf = pw.Document();
    final font = await _getArabicFont(bold: false);
    final fontBold = await _getArabicFont(bold: true);

    final diff = (adj['difference'] as num?)?.toDouble() ?? 0.0;
    final diffStr = '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)}';
    final typeStr = diff < 0 ? 'عجز / تلف / فقدان' : (diff > 0 ? 'فائض مخزني' : 'مطابق');

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
                child: pw.Text('نظام المخازن الذكية - إذن تسوية وإتلاف مخزني', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text('Inventory Reconciliation & Damage Voucher', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم التسوية: #${adj['id'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('التاريخ: ${(adj['adjustment_date'] ?? '').toString().split('T').first}', style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRow('اسم المنتج:', adj['product_name']?.toString() ?? 'غير محدد'),
                    pw.SizedBox(height: 8),
                    _buildRow('نوع التسوية:', typeStr),
                    pw.SizedBox(height: 8),
                    _buildRow('الرصيد الدفتري (بالنظام):', '${adj['system_quantity']} وحدة'),
                    pw.SizedBox(height: 8),
                    _buildRow('الرصيد الفعلي (بعد الجرد):', '${adj['actual_quantity']} وحدة'),
                    pw.SizedBox(height: 8),
                    _buildRow('الفارق (الكمية المسواة):', '$diffStr وحدة'),
                    pw.Divider(),
                    _buildRow('السبب (بيان التلف أو التسوية):', adj['reason']?.toString() ?? 'جرد دوري'),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('توقيع أمين المخزن', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 30),
                      pw.Text('.......................................'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('اعتماد المدير المالي / الإدارة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 30),
                      pw.Text('.......................................'),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'تسوية_مخزون_${adj['id'] ?? ''}.pdf');
  }

  /// طباعة قائمة سجل التوالف والتسويات بالكامل
  static Future<void> printAdjustmentReport(List<Map<String, dynamic>> adjustments) async {
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
              child: pw.Text('تقرير تسويات المخزون وسجل التوالف والعجز', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              headers: ['رقم', 'الصنف', 'دفتري', 'فعلي', 'الفارق', 'السبب', 'التاريخ'],
              data: adjustments.map((a) {
                final diff = (a['difference'] as num?)?.toDouble() ?? 0.0;
                final diffStr = '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)}';
                final dateStr = (a['adjustment_date'] ?? '').toString().split('T').first;
                return [
                  '#${a['id'] ?? ''}',
                  a['product_name']?.toString() ?? 'منتج',
                  '${a['system_quantity']}',
                  '${a['actual_quantity']}',
                  diffStr,
                  a['reason']?.toString() ?? '',
                  dateStr,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'تقرير_التوالف_والتسويات.pdf');
  }

  static pw.Widget _buildRow(String label, String val) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.Text(val, style: const pw.TextStyle(fontSize: 13)),
      ],
    );
  }
}
