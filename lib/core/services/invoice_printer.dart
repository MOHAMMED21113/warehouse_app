// lib/core/services/invoice_printer.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/database/database_helper.dart';

class InvoicePrinter {
  // ===== ألوان الهوية الموحّدة =====
  static final _navy = PdfColor.fromHex('#0C1A2E');
  static final _navyMedium = PdfColor.fromHex('#0F4C81');
  static final _accentGold = PdfColor.fromHex('#D4AF37');
  static final _lightBg = PdfColor.fromHex('#F4F6F9');
  static final _borderColor = PdfColor.fromHex('#DDE1E6');
  static final _textDark = PdfColor.fromHex('#2C3E50');
  static final _textMuted = PdfColor.fromHex('#7F8C8D');

  static Future<pw.Font> _loadFont(String path) async {
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }

  static Future<pw.Font> _loadRegularFont() async {
    return await _loadFont('assets/fonts/NotoNaskhArabic-Regular.ttf');
  }

  static Future<pw.Font> _loadBoldFont() async {
    return await _loadFont('assets/fonts/NotoNaskhArabic-Bold.ttf');
  }

  static String _formatNumber(num value) {
    return NumberFormat('#,##0.00', 'en_US').format(value);
  }

  static String _formatDate(dynamic dateString) {
    if (dateString == null ||
        dateString.toString().trim().isEmpty ||
        dateString == 'غير محدد') {
      return 'غير محدد';
    }
    try {
      return dateString.toString().split('T')[0];
    } catch (e) {
      return dateString.toString();
    }
  }

  // 💡 الدالة السحرية لقراءة الشعار من ملفات الهاتف المرفوعة عبر الإعدادات
  static Future<pw.MemoryImage?> _getShopLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('shop_logo_path');
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          return pw.MemoryImage(file.readAsBytesSync());
        }
      }
    } catch (e) {
      print('خطأ في جلب الشعار: $e');
    }
    return null;
  }

  // ============================================================
  //  1. طباعة السند المالي
  // ============================================================
  static Future<void> printFinancialVoucher(
    Map<String, dynamic> voucher, {
    String? shopName,
    String? shopPhone,
    String? shopAddress,
    String? personName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Arabic fields
    shopName ??= prefs.getString('shop_name') ?? 'مؤسسة اتفاقية الأخوة';
    shopPhone ??= prefs.getString('shop_phone') ?? '';
    shopAddress ??= prefs.getString('shop_address') ?? '';
    String shopActivityAr = prefs.getString('shop_activity_ar') ?? 'مـقـاولات - كـشـف تـسـربات الميـاه\nعـوازل مـائـيــة حـراريــة - فـــوم';

    // English fields
    String shopNameEn = prefs.getString('shop_name_en') ?? 'Fraternity Agreement Est.';
    String _shopAddressEn = prefs.getString('shop_address_en') ?? '';
    String crNumber = prefs.getString('cr_number') ?? '';
    String taxNumber = prefs.getString('tax_number') ?? '';
    String shopActivityEn = prefs.getString('shop_activity_en') ?? 'Contracting - detecting water leaks\nThermal Water Insulators - Foam';

    final ttfRegular = await _loadRegularFont();
    final ttfBold = await _loadBoldFont();
    final logoImage = await _getShopLogo();
    final pdf = pw.Document();

    final bool isReceipt = voucher['type'] == 'receipt';
    final String voucherTitleAr = isReceipt ? 'سند قبض' : 'سند صرف';
    final String voucherTitleEn =
        isReceipt ? 'Receipt Voucher' : 'Payment Voucher';

    final String voucherDate = _formatDate(voucher['date']);
    final double amountVal = (voucher['amount'] as num?)?.toDouble() ?? 0.0;

    // Amount formatting to separate integer and fractional parts
    final int amountInt = amountVal.truncate();
    final int amountFraction = ((amountVal - amountInt) * 100).round();
    final String amountStr = amountInt.toString();
    final String _fractionStr = amountFraction.toString().padLeft(2, '0');

    final String voucherNumber = voucher['voucher_number']?.toString() ?? '---';

    String rawNotes = voucher['notes']?.toString() ?? '';
    String finalPersonName = personName ?? '';
    String cleanNotes = rawNotes;

    if (finalPersonName.isEmpty) {
      if (rawNotes.contains(' - ')) {
        final parts = rawNotes.split(' - ');
        finalPersonName = parts.last.trim();
        cleanNotes = parts.sublist(0, parts.length - 1).join(' - ').trim();
      } else {
        finalPersonName = isReceipt ? 'عميل نقدي' : 'مورد نقدي';
      }
    }

    // Default Bank and Cheque (can be adjusted if you add these to db later)
    bool isCash = voucher['payment_method'] != 'cheque' && voucher['payment_method'] != 'bank';

    final pageFormat = PdfPageFormat.a5.landscape.copyWith(
      marginLeft: 15,
      marginRight: 15,
      marginTop: 20,
      marginBottom: 20,
    );

    pw.Widget dottedLineContainer(pw.Widget child) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 5),
          decoration: pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(
                    color: _navyMedium, width: 1, style: pw.BorderStyle.dotted)),
          ),
          child: child,
        ),
      );
    }

    pw.Widget _buildCheckbox(bool checked) {
      return pw.Container(
        width: 12,
        height: 12,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _navyMedium, width: 1),
        ),
        child: checked ? pw.Center(child: pw.Text('X', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: _navyMedium))) : null,
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _navyMedium, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header (Arabic Right - Center - English Left due to RTL)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Arabic Right (First child in RTL goes to the Right)
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(shopName!,
                              style: pw.TextStyle(
                                  font: ttfBold,
                                  fontSize: 16,
                                  color: _navyMedium)),
                          if (shopActivityAr.isNotEmpty)
                            pw.Text(shopActivityAr,
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 12,
                                    color: _navyMedium,
                                    lineSpacing: 2)),
                          if (crNumber.isNotEmpty)
                            pw.Text('س.ت $crNumber',
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 12,
                                    color: _navyMedium)),
                          if (taxNumber.isNotEmpty)
                            pw.Text('الرقم الضريبي $taxNumber',
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 12,
                                    color: _navyMedium)),
                        ],
                      ),
                    ),

                    // Center Logo and Title
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 70,
                              height: 70,
                              margin: const pw.EdgeInsets.only(bottom: 4),
                              decoration: pw.BoxDecoration(
                                image: pw.DecorationImage(
                                    image: logoImage, fit: pw.BoxFit.contain),
                              ),
                            ),
                          pw.Text(voucherTitleAr,
                              style: pw.TextStyle(
                                  font: ttfBold,
                                  fontSize: 18,
                                  color: _navyMedium)),
                          pw.Container(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            decoration: pw.BoxDecoration(
                                border: pw.Border(
                                    bottom: pw.BorderSide(
                                        color: _navyMedium, width: 1.5))),
                            child: pw.Text(voucherTitleEn,
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 13,
                                    color: _navyMedium),
                                textDirection: pw.TextDirection.ltr),
                          ),
                        ],
                      ),
                    ),

                    // English Left (Last child in RTL goes to the Left)
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(shopNameEn,
                              style: pw.TextStyle(
                                  font: ttfBold,
                                  fontSize: 15,
                                  color: _navyMedium),
                              textDirection: pw.TextDirection.ltr),
                          if (shopActivityEn.isNotEmpty)
                            pw.Text(shopActivityEn,
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 11,
                                    color: _navyMedium,
                                    lineSpacing: 2),
                                textDirection: pw.TextDirection.ltr),
                          if (crNumber.isNotEmpty)
                            pw.Text('C.R. $crNumber',
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 11,
                                    color: _navyMedium),
                                textDirection: pw.TextDirection.ltr),
                          if (taxNumber.isNotEmpty)
                            pw.Text('Tax No. $taxNumber',
                                style: pw.TextStyle(
                                    font: ttfBold,
                                    fontSize: 11,
                                    color: _navyMedium),
                                textDirection: pw.TextDirection.ltr),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),

                // Amount and Meta Box
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Amount Box & Date (Right side in RTL)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.SizedBox(width: 25),
                            pw.Text('ريال', style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyMedium)),
                            pw.SizedBox(width: 30),
                          ]
                        ),
                        pw.Row(
                          children: [
                            // SR Box
                            pw.Container(
                              width: 90,
                              height: 30,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: _navyMedium, width: 1.5),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Center(
                                child: pw.Text(amountStr, style: pw.TextStyle(font: ttfBold, fontSize: 14, color: _navyMedium)),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            // Halala Box
                            // pw.Container(
                            //   width: 35,
                            //   height: 30,
                            //   decoration: pw.BoxDecoration(
                            //     border: pw.Border.all(color: _navyMedium, width: 1.5),
                            //     borderRadius: pw.BorderRadius.circular(6),
                            //   ),
                            //   child: pw.Center(
                            //     child: pw.Text(fractionStr, style: pw.TextStyle(font: ttfBold, fontSize: 14, color: _navyMedium)),
                            //   ),
                            // ),
                          ]
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('التاريخ :', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium)),
                            pw.SizedBox(width: 5),
                            pw.Text(voucherDate, style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium), textDirection: pw.TextDirection.ltr),
                          ]
                        )
                      ]
                    ),

                    // NO. (Left side in RTL)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 25),
                      child: pw.Text('NO.  $voucherNumber',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 14, color: _navyMedium),
                        textDirection: pw.TextDirection.ltr),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Body text (Receipt From, etc)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(isReceipt ? 'استلمنا من السيد/السادة' : 'صرفنا للسيد/السادة',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 12, color: _navyMedium)),
                    dottedLineContainer(
                      pw.Center(
                        child: pw.Text(finalPersonName,
                            style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium),
                            textAlign: pw.TextAlign.center),
                      ),
                    ),
                    pw.Text(isReceipt ? 'RECEIVED FROM M/s' : 'PAID TO M/s',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 11, color: _navyMedium),
                        textDirection: pw.TextDirection.ltr),
                  ],
                ),
                pw.SizedBox(height: 20),

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('مبلغ وقدره',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 12, color: _navyMedium)),
                    dottedLineContainer(
                      pw.Center(
                        child: pw.Text(' $amountStr ريال   ',
                            style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium),
                            textAlign: pw.TextAlign.center),
                      ),
                    ),
                    pw.Text('The sum of',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 11, color: _navyMedium),
                        textDirection: pw.TextDirection.ltr),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Checkboxes Line
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Right: Arabic Checkboxes
                    pw.Row(
                      children: [
                        pw.Text('نقداً', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium)),
                        pw.SizedBox(width: 4),
                        _buildCheckbox(isCash),
                        pw.SizedBox(width: 15),
                        pw.Text('شيك رقم', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium)),
                        pw.SizedBox(width: 4),
                        _buildCheckbox(!isCash),
                      ]
                    ),

                    pw.SizedBox(width: 15),

                    // Center: Bank
                    pw.Text('على بنك', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium)),
                    dottedLineContainer(pw.SizedBox()), // empty dotted line
                    pw.Text('Bank', style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyMedium), textDirection: pw.TextDirection.ltr),

                    pw.SizedBox(width: 15),

                    // Left: English Checkboxes
                    pw.Row(
                      children: [
                        _buildCheckbox(isCash),
                        pw.SizedBox(width: 4),
                        pw.Text('Cash', style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyMedium), textDirection: pw.TextDirection.ltr),
                        pw.SizedBox(width: 15),
                        _buildCheckbox(!isCash),
                        pw.SizedBox(width: 4),
                        pw.Text('Cheque No', style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyMedium), textDirection: pw.TextDirection.ltr),
                      ]
                    )
                  ],
                ),
                pw.SizedBox(height: 20),

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('وذلك عن قيمة',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 12, color: _navyMedium)),
                    dottedLineContainer(
                      pw.Center(
                        child: pw.Text(cleanNotes,
                            style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium),
                            textAlign: pw.TextAlign.center),
                      ),
                    ),
                    pw.Text('For',
                        style: pw.TextStyle(
                            font: ttfBold, fontSize: 11, color: _navyMedium),
                        textDirection: pw.TextDirection.ltr),
                  ],
                ),
                pw.SizedBox(height: 25),

                // Extra dotted line just like in the image
                pw.Row(
                  children: [
                    dottedLineContainer(pw.SizedBox()),
                  ]
                ),

                pw.Spacer(),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Receiver (Right)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('المستلم', style: pw.TextStyle(font: ttfBold, fontSize: 13, color: _navyMedium)),
                              pw.SizedBox(width: 8),
                              pw.Text('Receiver', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium), textDirection: pw.TextDirection.ltr),
                            ]
                          ),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            margin: const pw.EdgeInsets.symmetric(horizontal: 20),
                            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navyMedium, width: 1, style: pw.BorderStyle.dotted))),
                            child: pw.SizedBox(width: double.infinity, height: 1),
                          )
                        ]
                      ),
                    ),
                    // Accountant (Center)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('المحاسب', style: pw.TextStyle(font: ttfBold, fontSize: 13, color: _navyMedium)),
                              pw.SizedBox(width: 8),
                              pw.Text('Accountant', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium), textDirection: pw.TextDirection.ltr),
                            ]
                          ),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            margin: const pw.EdgeInsets.symmetric(horizontal: 20),
                            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navyMedium, width: 1, style: pw.BorderStyle.dotted))),
                            child: pw.SizedBox(width: double.infinity, height: 1),
                          )
                        ]
                      ),
                    ),
                    // Manager (Left)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('المدير', style: pw.TextStyle(font: ttfBold, fontSize: 13, color: _navyMedium)),
                              pw.SizedBox(width: 8),
                              pw.Text('Manager', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium), textDirection: pw.TextDirection.ltr),
                            ]
                          ),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            margin: const pw.EdgeInsets.symmetric(horizontal: 20),
                            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navyMedium, width: 1, style: pw.BorderStyle.dotted))),
                            child: pw.SizedBox(width: double.infinity, height: 1),
                          )
                        ]
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${isReceipt ? 'Receipt' : 'Payment'}_Voucher_$voucherNumber',
    );
  }

  // ============================================================
  //  2. طباعة فاتورة المبيعات/المشتريات
  // ============================================================

  static Future<void> printSaleInvoice({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    required bool isSaleInvoice,
    required double previousBalance,
    required List<Map<String, dynamic>> payments,
    double initialPaidAmount = 0.0,
    bool printFinancialDetails = true,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
  }) async {
    if (shopName == null ||
        shopName.isEmpty ||
        shopPhone == null ||
        shopAddress == null) {
      final prefs = await SharedPreferences.getInstance();
      shopName = prefs.getString('shop_name') ?? 'مؤسسة  التجارية';
      shopPhone = prefs.getString('shop_phone') ?? '771111111 \n 717777777';
      shopAddress = prefs.getString('shop_address') ?? 'صنعاء - شارع الثلاثين \n اليمن';
    }

    final prefs = await SharedPreferences.getInstance();
    final shopNameEn =
        prefs.getString('shop_name_en') ?? 'Raheel Trading Establishment';
    final shopPhoneEn =
        prefs.getString('shop_phone') ?? '771111111 \n 717777777';
    final shopAddressEn = prefs.getString('shop_address_en') ??
        'Dammam - Prince Faisal str.\n Kingdom of Saudi Arabia';
    final crNumber = prefs.getString('cr_number') ?? '';
    final taxNumber = prefs.getString('tax_number') ?? '';
    final shopActivityAr = prefs.getString('shop_activity_ar') ?? '';
    final shopActivityEn = prefs.getString('shop_activity_en') ?? '';
    final shopEmail = prefs.getString('shop_email') ?? 'hamadayazyd5@gmail.com';

    final ttfRegular = await _loadRegularFont();
    final ttfBold = await _loadBoldFont();
    final logoImage = await _getShopLogo();

    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 20,
      marginRight: 20,
      marginTop: 30,
      marginBottom: 30,
    );

    double totalVal = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
    double discountVal = (invoice['discount'] as num?)?.toDouble() ?? 0.0;
    double taxVal = (invoice['tax'] as num?)?.toDouble() ?? 0.0;
    double subtotalVal = (invoice['subtotal'] as num?)?.toDouble() ?? (totalVal + discountVal - taxVal);

    double actualTaxRate = (invoice['tax_rate'] as num?)?.toDouble() ?? 0.0;
    if (actualTaxRate == 0.0 && taxVal > 0 && (subtotalVal - discountVal) > 0) {
      actualTaxRate = (taxVal / (subtotalVal - discountVal)) * 100;
    }
    if ((actualTaxRate - actualTaxRate.round()).abs() < 0.01) {
      actualTaxRate = actualTaxRate.roundToDouble();
    }
    String taxRateStr = actualTaxRate > 0
        ? ' (${actualTaxRate.truncateToDouble() == actualTaxRate ? actualTaxRate.toInt() : actualTaxRate.toStringAsFixed(1)}%)'
        : '';
    String displayNotes = invoice['notes']?.toString() ?? '';
    String invoiceNumber = invoice['invoice_number'] ?? '---';
    String dateStr = _formatDate(invoice['date']);
    String customerName = invoice['customer_name'] ?? invoice['supplier_name'] ?? '';

    List<Map<String, dynamic>> actualPayments = payments;
    final invoiceId = invoice['id'] != null ? int.tryParse(invoice['id'].toString()) : null;
    if (invoiceId != null) {
      final db = DatabaseHelper.instance;
      final String invType = isSaleInvoice ? 'sales_invoice' : 'purchase_invoice';
      actualPayments = await db.getVouchersForInvoice(invoiceId, invType);
    }

    String invoiceTypeAr = isSaleInvoice ? 'فاتورة نقدية/آجلة' : 'فاتورة مشتريات';
    String invoiceTypeEn =
        isSaleInvoice ? 'Cash Credit Invoice' : 'Purchase Invoice';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (context) {
          final List<Map<String, dynamic>> fullLedger = [];
          if (printFinancialDetails) {
            fullLedger.add({
              'date': dateStr,
              'notes': isSaleInvoice ? 'فاتورة مبيعات رقم $invoiceNumber' : 'فاتورة مشتريات رقم $invoiceNumber',
              'debit': isSaleInvoice ? totalVal : 0.0,
              'credit': isSaleInvoice ? 0.0 : totalVal,
              'balance': totalVal,
            });
            for (var p in actualPayments) {
              double debit = (p['debit_amount'] as num?)?.toDouble() ?? 0.0;
              double credit = (p['credit_amount'] as num?)?.toDouble() ?? 0.0;
              if (debit == 0 && credit == 0) {
                final double amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                if (isSaleInvoice) {
                  credit = amount;
                } else {
                  debit = amount;
                }
              }
              final remBalance = (p['remaining_balance'] as num?)?.toDouble() ?? 0.0;
              final refNum = p['reference_number']?.toString() ?? p['voucher_number']?.toString() ?? '';
              final rawNotes = p['notes']?.toString() ?? '';
              final String notes = refNum.isNotEmpty && !rawNotes.contains(refNum)
                  ? 'سند رقم: $refNum | $rawNotes'
                  : (rawNotes.isNotEmpty ? rawNotes : (credit > 0 ? 'دفعة من العميل' : 'حركة سداد مالية'));
              fullLedger.add({
                'date': _formatDate(p['date']),
                'notes': notes,
                'debit': debit,
                'credit': credit,
                'balance': remBalance,
              });
            }
          }

          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Arabic Right
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(shopName!,
                              style: pw.TextStyle(font: ttfBold, fontSize: 16)),
                          if (shopActivityAr.isNotEmpty)
                            pw.Text(shopActivityAr,
                                style: pw.TextStyle(
                                    font: ttfBold, fontSize: 11, lineSpacing: 2)),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('جوال:  ',
                                  style: pw.TextStyle(
                                      font: ttfBold, fontSize: 12)),
                              pw.Expanded(
                                child: pw.Text(shopPhone!.replaceAll(' / ', '\n').replaceAll('/', '\n').replaceAll(' ', '\n'),
                                    style: pw.TextStyle(
                                        font: ttfBold, fontSize: 12),
                                    textDirection: pw.TextDirection.rtl),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(shopAddress!,
                              style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                          if (crNumber.isNotEmpty)
                            pw.Text('س.ت $crNumber',
                                style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                          if (taxNumber.isNotEmpty)
                            pw.Text('الرقم الضريبي $taxNumber',
                                style: pw.TextStyle(font: ttfBold, fontSize: 12)),

                          pw.Row(
                            children: [
                              pw.Text('الإيميل / Email : ', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _navy)),
                              pw.Text(shopEmail, style: pw.TextStyle(font: ttfBold, fontSize: 10), textDirection: pw.TextDirection.ltr),
                            ],
                          ),
                        ],

                      ),
                    ),

                    // Center
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 60,
                              height: 60,
                              margin: const pw.EdgeInsets.only(bottom: 6),
                              decoration: pw.BoxDecoration(
                                image: pw.DecorationImage(
                                    image: logoImage, fit: pw.BoxFit.contain),
                              ),
                            )
                          else
                            pw.SizedBox(height: 60),
                          pw.Text(invoiceTypeAr,
                              style: pw.TextStyle(font: ttfBold, fontSize: 16)),
                          pw.Container(
                            decoration: const pw.BoxDecoration(
                                border:
                                    pw.Border(bottom: pw.BorderSide(width: 1))),
                            child: pw.Text(invoiceTypeEn,
                                style: pw.TextStyle(
                                    font: ttfRegular, fontSize: 12),
                                textDirection: pw.TextDirection.rtl),
                          ),
                        ],
                      ),
                    ),

                    // English Left
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(shopNameEn,
                              style: pw.TextStyle(font: ttfBold, fontSize: 14),
                              textDirection: pw.TextDirection.ltr),
                          if (shopActivityEn.isNotEmpty)
                            pw.Text(shopActivityEn,
                                style: pw.TextStyle(
                                    font: ttfBold, fontSize: 10, lineSpacing: 2),
                                textDirection: pw.TextDirection.ltr),
                          pw.SizedBox(height: 5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: pw.Text(shopPhoneEn.replaceAll(' / ', '\n').replaceAll('/', '\n').replaceAll(' ', '\n'),
                                    style:
                                        pw.TextStyle(font: ttfBold, fontSize: 12),
                                    textAlign: pw.TextAlign.left,
                                    textDirection: pw.TextDirection.ltr),
                              ),
                              pw.Text(' Mobile : ', style: pw.TextStyle(font: ttfBold, fontSize: 12),
                                  textDirection: pw.TextDirection.ltr),
                            ],
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(shopAddressEn,
                              style: pw.TextStyle(font: ttfBold, fontSize: 11),
                              textAlign: pw.TextAlign.left,
                              textDirection: pw.TextDirection.ltr),
                          if (crNumber.isNotEmpty)
                            pw.Text('C.R. $crNumber',
                                style: pw.TextStyle(font: ttfBold, fontSize: 11),
                                textAlign: pw.TextAlign.left,
                                textDirection: pw.TextDirection.ltr),
                          if (taxNumber.isNotEmpty)
                            pw.Text('Tax No. $taxNumber',
                                style: pw.TextStyle(font: ttfBold, fontSize: 11),
                                textAlign: pw.TextAlign.left,
                                textDirection: pw.TextDirection.ltr),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 9),

                // Date & No
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Right Date
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text('الموافق',
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 12)),
                            pw.SizedBox(width: 15),
                            pw.Text(dateStr + ' م',
                                style:
                                    pw.TextStyle(font: ttfBold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    // Left No.
                    pw.Row(
                      children: [
                        pw.Text(invoiceNumber, style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                        pw.Text('No. ', style: pw.TextStyle(font: ttfBold, fontSize: 14), textDirection: pw.TextDirection.ltr),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 9),

                // Customer Box
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(15),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('المطلوب من المكرم ', style: pw.TextStyle(fontSize: 14)),
                      pw.Expanded(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.symmetric(horizontal: 5),
                          decoration: pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(
                                      color: PdfColors.black,
                                      width: 1))),
                          child: pw.Text(customerName,
                              style: pw.TextStyle(font:ttfBold, fontSize: 14),
                              textAlign: pw.TextAlign.center),
                        ),
                      ),
                      pw.Text('المحترم', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 7),

                // جدول الأصناف (في وضع RTL الطبيعي لضمان تشكيل الأحرف العربية بشكل سليم 100%)
                pw.Table(
                  border: pw.TableBorder(
                    top: const pw.BorderSide(color: PdfColors.black, width: 1.5),
                    left: const pw.BorderSide(color: PdfColors.black, width: 1.5),
                    right: const pw.BorderSide(color: PdfColors.black, width: 1.5),
                    verticalInside: const pw.BorderSide(color: PdfColors.black, width: 1.0),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(5.0), // أقصى اليمين: البيان / DESCRIPTION
                    1: const pw.FlexColumnWidth(1.1), // الكمية / QTY.
                    2: const pw.FlexColumnWidth(1.8), // سعر الوحدة / UNIT PRICE
                    3: const pw.FlexColumnWidth(2.2), // أقصى اليسار: المبلغ الإجمالي / TOTAL PRICE
                  },
                  children: [
                    // الترويسة بالعربية أعلى والإنجليزية أسفل كما في الصورة بالضبط
                    pw.TableRow(
                      repeat: true,
                      decoration: pw.BoxDecoration(
                        color: _lightBg,
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2)),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: pw.Column(
                            children: [
                              pw.Text('البيان', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.SizedBox(height: 2),
                              pw.Text('DESCRIPTION', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: pw.Column(
                            children: [
                              pw.Text('الكمية', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.SizedBox(height: 2),
                              pw.Text('QTY.', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: pw.Column(
                            children: [
                              pw.Text('سعر الوحدة', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.SizedBox(height: 2),
                              pw.Text('UNIT PRICE', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: pw.Column(
                            children: [
                              pw.Text('المبلغ الإجمالي', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.SizedBox(height: 2),
                              pw.Text('TOTAL PRICE', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // صفوف الأصناف مع خطوط منقطة تفصل بين الصفوف
                    ...List.generate(math.max(items.length, 6), (index) {
                      final hasItem = index < items.length;
                      final i = hasItem ? items[index] : null;
                      final desc = hasItem ? (i!['product_name'] ?? i['name'] ?? 'صنف').toString() : '';
                      final qty = hasItem ? '${(i!['quantity'] ?? 0).toInt()}' : '';
                      final unitPrice = hasItem ? _formatNumber((i!['unit_price'] ?? i['unit_cost'] ?? 0).toDouble()) : '';
                      final totalPrice = hasItem ? _formatNumber(((i!['unit_price'] ?? i['unit_cost'] ?? 0).toDouble() * (i['quantity'] ?? 0).toInt())) : '';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.black, width: 0.6, style: pw.BorderStyle.dotted),
                          ),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            child: pw.Text(
                              desc.isEmpty ? '................................................................................................' : desc,
                              style: pw.TextStyle(font: ttfRegular, fontSize: 12, ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                            child: pw.Text(qty, style: pw.TextStyle(font: ttfRegular, fontSize: 10), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                            child: pw.Text(unitPrice, style: pw.TextStyle(font: ttfRegular, fontSize: 10), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                            child: pw.Text(totalPrice, style: pw.TextStyle(font: ttfBold, fontSize: 10), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                // جدول الملخص السفلي متصل بجدول الأصناف
                pw.Table(
                  border: pw.TableBorder(
                    left: const pw.BorderSide(color: PdfColors.black, width: 1.5),
                    right: const pw.BorderSide(color: PdfColors.black, width: 1.5),
                    bottom: const pw.BorderSide(color: PdfColors.black, width: 1.5),
                    verticalInside: const pw.BorderSide(color: PdfColors.black, width: 1.0),
                    horizontalInside: const pw.BorderSide(color: PdfColors.black, width: 1.0),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(7.9), // أقصى اليمين: عمود المسميات (المجموع والخصم والضريبة) تحت البيان
                    1: const pw.FlexColumnWidth(2.2), // أقصى اليسار: عمود المبالغ تحت المبلغ الإجمالي مباشرة
                  },
                  children: [
                    // الصف 1: المجموع / Total
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('المجموع', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.Text('Total', style: pw.TextStyle(font: ttfRegular, fontSize: 11)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                          child: pw.Text('${_formatNumber(subtotalVal)}', style: pw.TextStyle(font: ttfBold, fontSize: 11), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    // الصف 2: الخصم / Discount
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('الخصم', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.Text('Discount', style: pw.TextStyle(font: ttfRegular, fontSize: 11)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                          child: pw.Text(discountVal > 0 ? '${_formatNumber(discountVal)}' : '', style: pw.TextStyle(font: ttfBold, fontSize: 11), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    // الصف 3: ضريبة القيمة المضافة / Vat
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('ضريبة القيمة المضافة$taxRateStr', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                              pw.Text('Vat', style: pw.TextStyle(font: ttfRegular, fontSize: 11)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                          child: pw.Text(taxVal > 0 ? '${_formatNumber(taxVal)}' : '', style: pw.TextStyle(font: ttfBold, fontSize: 11), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    // الصف 4: المجموع الكلي / Total Tax
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: _lightBg),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('المجموع الكلي', style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                              pw.Text('Total Tax', style: pw.TextStyle(font: ttfRegular, fontSize: 12)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: pw.Text('${_formatNumber(totalVal)}', style: pw.TextStyle(font: ttfBold, fontSize: 12), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                  ],
                ),

                if (displayNotes.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: _lightBg,
                      border: pw.Border.all(color: _borderColor, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(' ملاحظات الفاتورة : $displayNotes', style: pw.TextStyle(font: ttfBold, fontSize: 13, color: _navy)),
                      ],
                    ),
                  ),
                ],

                pw.SizedBox(height: 10),

                // التوقيعات مطابقة للصورة (بدون إطار وبخط منقط للتوقيع)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(' : توقيع المستلم', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                          pw.Text('..................................................', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                          pw.Text('Receiver Sign. ', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(width: 6),

                      pw.Row(
                        children: [
                          pw.Text(' : توقيع البائع', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                          pw.Text('..................................................', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                          pw.Text('Salesman Sign. ', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

            pw.SizedBox(height: 20),

            if (printFinancialDetails) ...[
            pw.SizedBox(height: 20),
            pw.Text('سجل كشف حركة الحساب التراكمي تفصيلياً:', style: pw.TextStyle(font: ttfBold, fontSize: 13, color: _navy)),
            pw.SizedBox(height: 6),
            if (actualPayments.isEmpty)
              pw.Text('✅ تم السداد المباشر (لا توجد سندات دفع منفصلة).', style: pw.TextStyle(font: ttfRegular, fontSize: 11, color: PdfColors.green700))
            else
              pw.Table(
                  border: pw.TableBorder.all(color: _borderColor, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.6), // # ترقيم تسلسلي قبل التاريخ
                    1: const pw.FlexColumnWidth(1.2), // التاريخ
                    2: const pw.FlexColumnWidth(3.0), // البيان وتفاصيل القيد والمستندات
                    3: const pw.FlexColumnWidth(1.1), // مدين (عليه)
                    4: const pw.FlexColumnWidth(1.1), // دائن (له)
                    5: const pw.FlexColumnWidth(1.2), // الرصيد المتبقي
                  },
                  children: [
                    pw.TableRow(
                        repeat: true,
                        decoration: pw.BoxDecoration(color: _navy),
                        children: [
                          _cell('#', ttfBold, isHeader: true, textColor: _accentGold, align: pw.TextAlign.center),
                          _cell('التاريخ', ttfBold, isHeader: true, textColor: _accentGold, align: pw.TextAlign.center),
                          _cell('البيان وتفاصيل القيد والمستندات', ttfBold, isHeader: true, align: pw.TextAlign.center, textColor: PdfColors.white),
                          _cell('مدين (عليه)', ttfBold, isHeader: true, textColor: PdfColors.white, align: pw.TextAlign.center),
                          _cell('دائن (له)', ttfBold, isHeader: true, textColor: PdfColors.white, align: pw.TextAlign.center),
                          _cell('الرصيد المتبقي', ttfBold, isHeader: true, textColor: _accentGold, align: pw.TextAlign.center),
                        ]
                    ),
                    ...fullLedger.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final r = entry.value;
                      final double debit = r['debit'] as double;
                      final double credit = r['credit'] as double;
                      final double remBalance = r['balance'] as double;

                      return pw.TableRow(
                          decoration: pw.BoxDecoration(color: idx % 2 == 0 ? _lightBg : PdfColors.white),
                          children: [
                            _cell('$idx', ttfRegular, align: pw.TextAlign.center, textColor: _textDark),
                            _cell(r['date'] as String, ttfRegular, align: pw.TextAlign.center, textColor: _textDark),
                            _cell(r['notes'] as String, ttfRegular, align: pw.TextAlign.center, textColor: _textDark),
                            _cell(debit == 0 ? '-' : _formatNumber(debit), ttfRegular, align: pw.TextAlign.center, textColor: debit > 0 ? PdfColors.red700 : _textDark),
                            _cell(credit == 0 ? '-' : _formatNumber(credit), ttfRegular, align: pw.TextAlign.center, textColor: credit > 0 ? PdfColors.green700 : _textDark),
                            _cell(_formatNumber(remBalance), ttfBold, align: pw.TextAlign.center, textColor: remBalance > 0 ? PdfColors.red700 : PdfColors.green700),
                          ]
                      );
                    })
                  ]
              )
          ],
        ];
      },
    ),
  );

    await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Cash_Invoice_$invoiceNumber.pdf');
  }




  static Future<void> printSalesReturnInvoice({
    required Map<String, dynamic> returnData,
    required List<Map<String, dynamic>> items,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
  }) async {
    await _printReturnInvoiceInternal(
        returnData: returnData,
        items: items,
        isSalesReturn: true,
        shopName: shopName,
        shopPhone: shopPhone,
        shopAddress: shopAddress);
  }

  static Future<void> printPurchaseReturnInvoice({
    required Map<String, dynamic> returnData,
    required List<Map<String, dynamic>> items,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
  }) async {
    await _printReturnInvoiceInternal(
        returnData: returnData,
        items: items,
        isSalesReturn: false,
        shopName: shopName,
        shopPhone: shopPhone,
        shopAddress: shopAddress);
  }

  static Future<void> _printReturnInvoiceInternal({
    required Map<String, dynamic> returnData,
    required List<Map<String, dynamic>> items,
    required bool isSalesReturn,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
  }) async {
    if (shopName == null ||
        shopName.isEmpty ||
        shopPhone == null ||
        shopAddress == null) {
      final prefs = await SharedPreferences.getInstance();
      shopName = prefs.getString('shop_name') ?? 'المخازن الذكي';
      shopPhone = prefs.getString('shop_phone') ?? '';
      shopAddress = prefs.getString('shop_address') ?? '';
    }

    final ttfRegular = await _loadRegularFont();
    final ttfBold = await _loadBoldFont();
    final logoImage = await _getShopLogo(); // 💡 جلب الشعار
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4.copyWith(
        marginLeft: 24, marginRight: 24, marginTop: 36, marginBottom: 36);

    final returnNumber = returnData['return_number'] ?? 'R-xxxxx';
    final dateStr = _formatDate(returnData['return_date']);
    final personName = isSalesReturn ? (returnData['customer_name'] ?? 'عميل غير محدد') : (returnData['supplier_name'] ?? 'مورد غير محدد');
    final phone = isSalesReturn ? (returnData['customer_phone'] ?? '') : (returnData['supplier_phone'] ?? '');
    final totalAmount = (returnData['total_amount'] as num?)?.toDouble() ?? 0.0;
    final refundAmount =
        (returnData['refund_amount'] as num?)?.toDouble() ?? totalAmount;
    final refundType = returnData['refund_type'] ?? 'كاش';
    final notes = returnData['notes']?.toString() ?? '';

    final String invoiceTitle = isSalesReturn ? 'فاتورة مرتجع مبيعات' : 'فاتورة مرتجع مشتريات';
    final String partyLabel = isSalesReturn ? 'العميل' : 'المورد';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 💡 طباعة الشعار
                  if (logoImage != null)
                    pw.Container(
                      width: 55,
                      height: 55,
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: _accentGold, width: 1.5),
                        image: pw.DecorationImage(
                            image: logoImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  pw.Text(shopName!,
                      style: pw.TextStyle(
                          font: ttfBold, fontSize: 24, color: _navy)),
                  pw.SizedBox(height: 4),
                  if (shopAddress!.isNotEmpty)
                    pw.Text('العنوان: $shopAddress',
                        style: pw.TextStyle(
                            font: ttfRegular, fontSize: 11, color: _textMuted)),
                  if (shopPhone!.isNotEmpty)
                    pw.Text('هاتف: $shopPhone',
                        style: pw.TextStyle(
                            font: ttfRegular, fontSize: 11, color: _textMuted)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(invoiceTitle,
                      style: pw.TextStyle(
                          font: ttfBold, fontSize: 22, color: _navy)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                        color: _accentGold,
                        borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text('رقم السند: $returnNumber',
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 11,
                            color: PdfColors.white)),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('التاريخ: $dateStr',
                      style: pw.TextStyle(
                          font: ttfRegular, fontSize: 13, color: _textDark)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 2, color: _accentGold),
          pw.SizedBox(height: 2),
          pw.Container(height: 1, color: _borderColor),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: _lightBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _borderColor)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$partyLabel الكشف التابع له:',
                    style: pw.TextStyle(
                        font: ttfBold, fontSize: 12, color: _textMuted)),
                pw.SizedBox(height: 4),
                pw.Text(personName,
                    style: pw.TextStyle(
                        font: ttfBold, fontSize: 14, color: _textDark)),
                if (phone.isNotEmpty)
                  pw.Text('الجوال: $phone',
                      style: pw.TextStyle(
                          font: ttfRegular, fontSize: 11, color: _textMuted)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _navy),
                children: [
                  _cell('#', ttfBold,
                      isHeader: true,
                      textColor: _accentGold,
                      align: pw.TextAlign.center),
                  _cell('الصنف المسترجع', ttfBold,
                      isHeader: true,
                      align: pw.TextAlign.center,
                      textColor: PdfColors.white),
                  _cell('الكمية المرتجعة', ttfBold,
                      isHeader: true,
                      textColor: PdfColors.white,
                      align: pw.TextAlign.center),
                  _cell('سعر الوحدة', ttfBold,
                      isHeader: true,
                      textColor: PdfColors.white,
                      align: pw.TextAlign.center),
                  _cell('الإجمالي', ttfBold,
                      isHeader: true,
                      textColor: _accentGold,
                      align: pw.TextAlign.center),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                final priceKey = isSalesReturn ? 'unit_price' : 'unit_cost';
                final price = (item[priceKey] as num?)?.toDouble() ?? 0.0;
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                final total = price * qty;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: idx % 2 == 0 ? _lightBg : PdfColors.white,
                      border: pw.Border(
                          bottom:
                              pw.BorderSide(color: _borderColor, width: 0.5))),
                  children: [
                    _cell('$idx', ttfRegular,
                        textColor: _textDark, align: pw.TextAlign.center),
                    _cell(item['product_name'] ?? '', ttfRegular,
                        align: pw.TextAlign.center, textColor: _textDark),
                    _cell('$qty', ttfRegular,
                        textColor: _textDark, align: pw.TextAlign.center),
                    _cell(_formatNumber(price), ttfRegular,
                        textColor: _textDark, align: pw.TextAlign.center),
                    _cell(_formatNumber(total), ttfBold,
                        textColor: _navyMedium, align: pw.TextAlign.center),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Wrap(children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: _borderColor),
                  color: _lightBg),
              child: pw.Column(children: [
                _row('إجمالي قيمة المرتجع السابقة', _formatNumber(totalAmount),
                    ttfRegular,
                    valueColor: _navy),
                pw.SizedBox(height: 4),
                _row('المبلغ المسترد للمالك الفعلي',
                    _formatNumber(refundAmount), ttfRegular,
                    valueColor: PdfColors.green700),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('طريقة عملية الاسترداد المالي',
                        style: pw.TextStyle(
                            font: ttfRegular, fontSize: 12, color: _textDark)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: refundType == 'كاش'
                            ? PdfColors.green50
                            : PdfColors.orange50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(
                            color: refundType == 'كاش'
                                ? PdfColors.green700
                                : PdfColors.orange700,
                            width: 0.5),
                      ),
                      child: pw.Text(
                        refundType == 'كاش'
                            ? 'استرداد كاش فوري'
                            : 'تسوية آجل للحساب المالي',
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 11,
                            color: refundType == 'كاش'
                                ? PdfColors.green700
                                : PdfColors.orange700),
                      ),
                    ),
                  ],
                ),
                if (refundType == 'آجل') ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Text('تنبيه: ',
                          style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 10,
                              color: PdfColors.orange700)),
                      pw.SizedBox(width: 4),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                              'سيتم خصم هذا الرصيد المذكور تلقائياً من حساب الديون المترتبة.',
                              style: pw.TextStyle(
                                  font: ttfRegular,
                                  fontSize: 10,
                                  color: PdfColors.orange700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ]),
            ),
          ]),
          pw.SizedBox(height: 12),
          if (notes.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                  color: PdfColors.yellow50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.yellow700)),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ملاحظات المرتجع:',
                        style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Text(notes,
                        style: pw.TextStyle(font: ttfRegular, fontSize: 11)),
                  ]),
            ),
        ],
        footer: (context) => _buildFooter(ttfRegular),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'مرتجع_$returnNumber.pdf');
  }

  // ============================================================
  //  4. طباعة كشف الحساب
  // ============================================================

  static Future<void> printAccountStatement({
    required String personName,
    required String personType,
    required List<Map<String, dynamic>> ledger,
    required double totalDebit,
    required double totalCredit,
    required double finalBalance,
    String? shopName,
    bool isShare = false,
  }) async {
    final ttfRegular = await _loadRegularFont();
    final ttfBold = await _loadBoldFont();
    final logoImage = await _getShopLogo(); // جلب الشعار المخصص

    final pdf = pw.Document();

    String balanceStatusText;
    PdfColor balanceColor;

    if (personType == 'customer') {
      if (finalBalance > 0.01) {
        balanceStatusText =  ' (مدين عليه)';
        balanceColor = PdfColors.red700;
      } else if (finalBalance < -0.01) {
        balanceStatusText = ' (دائن له)';
        balanceColor = PdfColors.green700;
      } else {
        balanceStatusText = 'مُصَفّر تام الحساب';
        balanceColor = _textMuted;
      }
    } else {
      if (finalBalance > 0.01) {
        balanceStatusText = ' (دائن له)';
        balanceColor = PdfColors.red700;
      } else if (finalBalance < -0.01) {
        balanceStatusText = ' (مدين عليه)';
        balanceColor = PdfColors.green700;
      } else {
        balanceStatusText = 'مُصَفّر تام الحساب';
        balanceColor = _textMuted;
      }
    }

    final sharpRadius = pw.BorderRadius.circular(4);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 24,
          marginRight: 24,
          marginTop: 40,
          marginBottom: 40,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (context) => [
          // 🚀 الترويسة الجديدة: الشعار فقط في المنتصف
          if (logoImage != null)
            pw.Center(
              child: pw.Container(
                width: 70, // زيادة الحجم قليلاً ليكون بارزاً بما أنه وحيد
                height: 70,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _accentGold, width: 2),
                  image: pw.DecorationImage(
                      image: logoImage, fit: pw.BoxFit.cover),
                ),
              ),
            ),

          // إضافة مسافة إذا لم يكن هناك شعار لكي لا يلتصق الجدول بالأعلى
          if (logoImage == null) pw.SizedBox(height: 20),

          pw.SizedBox(height: 15),
          pw.Container(
              height: 2,
              decoration: pw.BoxDecoration(
                  color: _accentGold,
                  borderRadius: pw.BorderRadius.circular(1))),
          pw.SizedBox(height: 2),
          pw.Container(height: 1, color: _borderColor),
          pw.SizedBox(height: 25),

          // --- الملخص المالي للحساب ---
          pw.Table(columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FixedColumnWidth(12),
            2: const pw.FlexColumnWidth(1),
          }, children: [
            pw.TableRow(children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: _lightBg,
                      borderRadius: sharpRadius,
                      border: pw.Border.all(color: _borderColor)),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('الحساب المالي الحالي:',
                            style: pw.TextStyle(
                                font: ttfRegular,
                                fontSize: 12,
                                color: _textMuted)),
                        pw.SizedBox(height: 4),
                        pw.Text(personName,
                            style: pw.TextStyle(
                                font: ttfBold, fontSize: 18, color: _navy)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                            personType == 'customer'
                                ? 'كشف حساب عميل آجل'
                                : 'كشف حساب مورد دائن',
                            style: pw.TextStyle(
                                font: ttfRegular,
                                fontSize: 11,
                                color: _navyMedium)),
                      ])),
              pw.SizedBox(width: 12),
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: _lightBg,
                      borderRadius: sharpRadius,
                      border: pw.Border.all(color: _borderColor)),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('الرصيد الصافي المتبقي:',
                            style: pw.TextStyle(
                                font: ttfRegular,
                                fontSize: 12,
                                color: _textMuted)),
                        pw.SizedBox(height: 4),
                        pw.Text('${_formatNumber(finalBalance.abs())} ريال',
                            style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 20,
                                color: balanceColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(balanceStatusText,
                            style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 12,
                                color: balanceColor)),
                      ])),
            ])
          ]),
          pw.SizedBox(height: 12),

          // --- مربعات إجمالي المدين والدائن ---
          pw.Table(columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FixedColumnWidth(12),
            2: const pw.FlexColumnWidth(1),
          }, children: [
            pw.TableRow(children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderColor),
                      borderRadius: sharpRadius,
                      color: PdfColors.white),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('إجمالي قيود المدين (السحبيات)',
                            style: pw.TextStyle(
                                font: ttfRegular,
                                fontSize: 11,
                                color: _textMuted)),
                        pw.SizedBox(height: 4),
                        pw.Text('${_formatNumber(totalDebit)} ريال',
                            style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 15,
                                color: PdfColors.red700)),
                      ])),
              pw.SizedBox(width: 12),
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderColor),
                      borderRadius: sharpRadius,
                      color: PdfColors.white),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('إجمالي قيود الدائن (المدفوعات)',
                            style: pw.TextStyle(
                                font: ttfRegular,
                                fontSize: 11,
                                color: _textMuted)),
                        pw.SizedBox(height: 4),
                        pw.Text('${_formatNumber(totalCredit)} ريال',
                            style: pw.TextStyle(
                                font: ttfBold,
                                fontSize: 15,
                                color: PdfColors.green700)),
                      ])),
            ])
          ]),
          pw.SizedBox(height: 24),

          pw.Text('سجل كشف حركة الحساب التراكمي تفصيلياً:',
              style:
                  pw.TextStyle(font: ttfBold, fontSize: 14, color: _textDark)),
          pw.SizedBox(height: 8),

          // --- الجدول التفصيلي ---
          pw.Table(
            border: pw.TableBorder.all(color: _borderColor, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Date
              1: const pw.FlexColumnWidth(3.0), // Desc
              2: const pw.FlexColumnWidth(1.1), // Debit
              3: const pw.FlexColumnWidth(1.1), // Credit
              4: const pw.FlexColumnWidth(1.2), // Balance
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _navy),
                children: [
                  _cell('التاريخ', ttfBold,
                      isHeader: true,
                      textColor: _accentGold,
                      align: pw.TextAlign.center),
                  _cell('البيان وتفاصيل القيد والمستندات', ttfBold,
                      isHeader: true,
                      align: pw.TextAlign.center,
                      textColor: PdfColors.white),
                  _cell('مدين (عليه)', ttfBold,
                      isHeader: true,
                      textColor: PdfColors.white,
                      align: pw.TextAlign.center),
                  _cell('دائن (له)', ttfBold,
                      isHeader: true,
                      textColor: PdfColors.white,
                      align: pw.TextAlign.center),
                  _cell('الرصيد المتبقي', ttfBold,
                      isHeader: true,
                      textColor: _accentGold,
                      align: pw.TextAlign.center),
                ],
              ),
              ...ledger.map((entry) {
                final String date = _formatDate(entry['date']);
                final double debit =
                    (entry['debit_amount'] as num?)?.toDouble() ?? 0.0;
                final double credit =
                    (entry['credit_amount'] as num?)?.toDouble() ?? 0.0;
                final double balAfter =
                    (entry['running_balance'] as num?)?.toDouble() ?? 0.0;

                String title = entry['notes']?.toString() ?? '';
                final String refNum =
                    entry['reference_number']?.toString() ?? '';

                if (refNum.isNotEmpty && !title.contains(refNum)) {
                  if (refNum.startsWith('REC') ||
                      refNum.startsWith('PAY') ||
                      refNum.startsWith('STL')) {
                    title = 'سند رقم: $refNum | $title';
                  } else if (refNum.startsWith('SR') ||
                      refNum.startsWith('PR')) {
                    title = 'مرتجع رقم: $refNum | $title';
                  }
                }

                if (title.isEmpty) title = 'حركة قيد مالي';

                return pw.TableRow(
                  children: [
                    _cell(date, ttfRegular,
                        align: pw.TextAlign.center, textColor: _textDark),
                    _cell(title, ttfRegular,
                        align: pw.TextAlign.center, textColor: _textDark),
                    _cell(
                        debit == 0 ? '0.00' : _formatNumber(debit), ttfRegular,
                        align: pw.TextAlign.center,
                        textColor: debit > 0 ? PdfColors.red700 : _textMuted),
                    _cell(credit == 0 ? '0.00' : _formatNumber(credit),
                        ttfRegular,
                        align: pw.TextAlign.center,
                        textColor:
                            credit > 0 ? PdfColors.green700 : _textMuted),
                    _cell(_formatNumber(balAfter.abs()), ttfBold,
                        align: pw.TextAlign.center,
                        textColor: balAfter < 0
                            ? PdfColors.green700
                            : (balAfter > 0 ? PdfColors.red700 : _textDark)),
                  ],
                );
              }),
            ],
          ),
        ],
        footer: (context) => _buildFooter(ttfRegular),
      ),
    );

    if (isShare) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'account_statement.pdf');
    } else {
      await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'account_statement.pdf');
    }
  }

  // ============================================================
  //  5. طباعة سجل التوالف
  // ============================================================
  static Future<void> printDamagedInvoice(
    Map<String, dynamic> item, {
    String? storeName,
    String? storeAddress,
    String? storePhone,
  }) async {
    if (storeName == null || storeName.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      storeName = prefs.getString('shop_name') ?? 'المخازن الذكي';
      storePhone = prefs.getString('shop_phone') ?? '';
      storeAddress = prefs.getString('shop_address') ?? '';
    }

    final ttfRegular = await _loadRegularFont();
    final ttfBold = await _loadBoldFont();
    final logoImage = await _getShopLogo(); // 💡 جلب الشعار

    final pdf = pw.Document();

    final String moveDate = _formatDate(item['move_date']);
    final String expiryDate = _formatDate(item['expiry_date']);
    final String warehouseKeeper = item['moved_by_name'] ?? 'غير محدد';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 24,
          marginRight: 24,
          marginTop: 30,
          marginBottom: 30,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // 💡 طباعة الشعار
                  if (logoImage != null)
                    pw.Container(
                      width: 50,
                      height: 50,
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: _navyMedium, width: 1.5),
                        image: pw.DecorationImage(
                            image: logoImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  pw.Text(storeName!,
                      style: pw.TextStyle(font: ttfBold, fontSize: 18)),
                  pw.SizedBox(height: 4),
                  if (storeAddress!.isNotEmpty)
                    pw.Text('العنوان: $storeAddress',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 11)),
                  if (storePhone!.isNotEmpty)
                    pw.Text('الهاتف: $storePhone',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 11)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                      'المستودع الجردي: ${item['warehouse_name'] ?? 'غير محدد'}',
                      style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 12,
                          color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('مستند تسوية (توالف)',
                        style: pw.TextStyle(font: ttfBold, fontSize: 16)),
                    pw.SizedBox(height: 6),
                    pw.Text('رقم المستند: ${item['invoice_number'] ?? '---'}',
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 13,
                            color: PdfColors.red800)),
                    pw.SizedBox(height: 4),
                    pw.Text('التاريخ: $moveDate',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Divider(color: PdfColors.grey),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoText(
                        ttfRegular,
                        ttfBold,
                        'سبب الإتلاف / التسوية الجردية:',
                        '${item['reason'] ?? 'لا يوجد'}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoText(ttfRegular, ttfBold,
                        'تاريخ انتهاء الصلاحية المخزنية:', expiryDate),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),
          pw.Text('بيان تفصيلي بالأصناف المجرودة وعجزها:',
              style: pw.TextStyle(font: ttfBold, fontSize: 14)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 1),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell(ttfBold, 'م',
                      isHeader: true, align: pw.TextAlign.center),
                  _buildTableCell(ttfBold, 'اسم الصنف / البيان المخزني العلمي',
                      isHeader: true),
                  _buildTableCell(ttfBold, 'الكمية المتلفة',
                      isHeader: true, align: pw.TextAlign.center),
                  _buildTableCell(ttfBold, 'تكلفة الصنف وحدة',
                      isHeader: true, align: pw.TextAlign.center),
                  _buildTableCell(ttfBold, 'إجمالي التكلفة والعجز',
                      isHeader: true, align: pw.TextAlign.center),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell(ttfRegular, '1', align: pw.TextAlign.center),
                  _buildTableCell(ttfRegular, '${item['product_name']}'),
                  _buildTableCell(ttfRegular, '${item['quantity']}',
                      align: pw.TextAlign.center),
                  _buildTableCell(ttfRegular, '${item['unit_cost']}',
                      align: pw.TextAlign.center),
                  _buildTableCell(ttfBold, '${item['total_loss']}',
                      align: pw.TextAlign.center),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5)),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 120,
                      padding: const pw.EdgeInsets.all(10),
                      color: PdfColors.grey200,
                      child: pw.Text('إجمالي خسائر العجز:',
                          style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                    ),
                    pw.Container(
                      width: 130,
                      padding: const pw.EdgeInsets.all(10),
                      alignment: pw.Alignment.center,
                      child: pw.Text('${item['total_loss']} ريال',
                          style: pw.TextStyle(font: ttfBold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                children: [
                  pw.Text('أمين ومسؤول المستودع',
                      style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                  pw.SizedBox(height: 25),
                  pw.Text('التوقيع: ____________',
                      style: pw.TextStyle(
                          font: ttfRegular, color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  pw.Text('الاسم: $warehouseKeeper',
                      style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('المراجع المالي والتدقيق',
                      style: pw.TextStyle(font: ttfBold, fontSize: 12)),
                  pw.SizedBox(height: 25),
                  pw.Text('التوقيع: ____________',
                      style: pw.TextStyle(
                          font: ttfRegular, color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  pw.Text('الاسم: ____________',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('التوقيع / الختم الرسمي',
                      style: pw.TextStyle(
                          font: ttfRegular, color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  pw.Text('________________',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ============================================================
  //  6. تصدير سجل التوالف إلى Excel
  // ============================================================
  static Future<void> exportToExcel(List<Map<String, dynamic>> logData) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['سجل التوالف'];
    excel.setDefaultSheet('سجل التوالف');

    List<String> headers = [
      'رقم المستند',
      'تاريخ التسوية',
      'تاريخ الانتهاء',
      'اسم الصنف',
      'الباركود',
      'المستودع',
      'الكمية',
      'تكلفة الوحدة',
      'إجمالي العجز',
      'السبب',
      'المسؤول (أمين المستودع)'
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var item in logData) {
      List<dynamic> rowData = [
        item['invoice_number'] ?? '',
        _formatDate(item['move_date']),
        _formatDate(item['expiry_date']),
        item['product_name'] ?? '',
        item['barcode'] ?? '',
        item['warehouse_name'] ?? '',
        item['quantity'] ?? 0,
        item['unit_cost'] ?? 0.0,
        item['total_loss'] ?? 0.0,
        item['reason'] ?? '',
        item['moved_by_name'] ?? ''
      ];
      sheetObject
          .appendRow(rowData.map((e) => TextCellValue(e.toString())).toList());
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/damaged_products_log.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles([XFile(filePath)],
          text: 'سجل التوالف والجرد التلقائي - المستودع');
    }
  }

  // ============================================================
  //  Widgets مساعدة للـ PDF
  // ============================================================
  static pw.Widget _buildFooter(pw.Font font) {
    return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Container(height: 1, color: _accentGold),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('- شكراً لتعاملكم معنا -', style: pw.TextStyle(font: font, fontSize: 10, color: _textMuted)),
          ),
        ]));
  }

  static pw.Widget _row(String label, String value, pw.Font font,
      {PdfColor? valueColor}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(font: font, fontSize: 12, color: _textDark)),
        pw.Text(value,
            style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: valueColor ?? _textDark,
                fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font,
      {bool isHeader = false,
      pw.TextAlign align = pw.TextAlign.center,
      PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: pw.Container(
        alignment: align == pw.TextAlign.center
            ? pw.Alignment.center
            : (align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft),
        child: pw.Text(text, textAlign: align, style: pw.TextStyle(font: font, fontSize: isHeader ? 12 : 11, color: textColor ?? _textDark),
        ),
      ),
    );
  }

  static pw.Widget _buildInfoText(
      pw.Font ttf, pw.Font ttfBold, String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: ttfBold, fontSize: 11, color: PdfColors.grey800)),
        pw.SizedBox(width: 8),
        pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 11)),
      ],
    );
  }

  static pw.Widget _buildTableCell(pw.Font font, String text,
      {bool isHeader = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
            font: font,
            fontSize: isHeader ? 12 : 11,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  // ============================================================
  //  طباعة تقرير مراجعة الفواتير الشامل (PDF)
  // ============================================================
  static Future<void> printInvoicesReport({
    required List<Map<String, dynamic>> invoices,
    required String reportTitle,
    required bool isSales,
    required double totalAmount,
    required double paidAmount,
    required double unpaidAmount,
    String? personFilterName,
    String? dateRangeStr,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final shopName = (prefs.getString('shop_name')?.isNotEmpty == true) ? prefs.getString('shop_name')! : 'المخازن الذكية التجاري';
    final shopPhone = prefs.getString('shop_phone') ?? '';
    final shopAddress = prefs.getString('shop_address') ?? '';
    final shopActivityAr = (prefs.getString('shop_activity_ar')?.isNotEmpty == true) ? prefs.getString('shop_activity_ar')! : 'تجارة عامة - جملة وتجزئة - استيراد وتصدير';
    final crNumber = prefs.getString('cr_number') ?? '';
    final taxNumber = prefs.getString('tax_number') ?? '';

    final ttfRegular = await _loadRegularFont();
    final ttfBold = await _loadBoldFont();
    final logoImage = await _getShopLogo();

    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 20,
      marginRight: 20,
      marginTop: 20,
      marginBottom: 20,
    );

    String formatNum(num v) => NumberFormat('#,##0.00', 'en_US').format(v);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (context) => [
          // الترويسة
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _navyMedium, width: 1.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName, style: pw.TextStyle(font: ttfBold, fontSize: 16, color: _navyMedium)),
                      if (shopActivityAr.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(shopActivityAr, style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _textDark, lineSpacing: 2)),
                      ],
                      if (shopPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('هاتف/جوال: ${shopPhone.replaceAll("\n", " - ")}', style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                      ],
                      if (shopAddress.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('العنوان: ${shopAddress.replaceAll("\n", " - ")}', style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                      ],
                      if (crNumber.isNotEmpty) pw.Text('س.ت: $crNumber', style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                      if (taxNumber.isNotEmpty) pw.Text('الرقم الضريبي: $taxNumber', style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) pw.Image(logoImage, width: 60, height: 60),
                      pw.SizedBox(height: 8),
                      pw.Text(reportTitle, style: pw.TextStyle(font: ttfBold, fontSize: 14, color: _navyMedium)),
                      pw.SizedBox(height: 4),
                      pw.Text('تاريخ الطباعة: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}', style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // معلومات الفلترة والإحصائيات
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _lightBg,
              border: pw.Border.all(color: _borderColor),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('عدد الفواتير', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _textMuted)),
                  pw.Text('${invoices.length}', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navy)),
                ]),
                pw.Column(children: [
                  pw.Text('الإجمالي العام', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _textMuted)),
                  pw.Text('${formatNum(totalAmount)} ﷼', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: _navyMedium)),
                ]),
                pw.Column(children: [
                  pw.Text('إجمالي المدفوع', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _textMuted)),
                  pw.Text('${formatNum(paidAmount)} ﷼', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: PdfColors.green700)),
                ]),
                pw.Column(children: [
                  pw.Text('إجمالي المتبقي (آجل)', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: _textMuted)),
                  pw.Text('${formatNum(unpaidAmount)} ﷼', style: pw.TextStyle(font: ttfBold, fontSize: 12, color: PdfColors.red700)),
                ]),
              ],
            ),
          ),
          if (personFilterName != null && personFilterName.isNotEmpty || (dateRangeStr != null && dateRangeStr.isNotEmpty)) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (personFilterName != null && personFilterName.isNotEmpty)
                  pw.Text('الجهة: $personFilterName', style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyMedium)),
                if (dateRangeStr != null && dateRangeStr.isNotEmpty)
                  pw.Text('الفترة: $dateRangeStr', style: pw.TextStyle(font: ttfBold, fontSize: 11, color: _navyMedium)),
              ],
            ),
          ],
          pw.SizedBox(height: 14),

          // جدول الفواتير
          pw.Table.fromTextArray(
            headers: [
              'رقم الفاتورة',
              'التاريخ',
              isSales ? 'العميل' : 'المورد',
              'الإجمالي',
              'المدفوع',
              'المتبقي',
              'الحالة'
            ],
            data: invoices.map((inv) {
              final finalTotal = (inv['total_amount'] ?? 0).toDouble();
              final paid = (inv['paid_amount'] ?? 0).toDouble();
              final rem = finalTotal - paid;
              final pName = isSales ? (inv['customer_name'] ?? 'عميل عام') : (inv['supplier_name'] ?? 'مورد عام');
              final dateStr = inv['date']?.toString().substring(0, 10) ?? '';
              final status = inv['payment_status']?.toString() ?? 'كامل';
              return [
                inv['invoice_number']?.toString() ?? '',
                dateStr,
                pName,
                formatNum(finalTotal),
                formatNum(paid),
                formatNum(rem),
                status,
              ];
            }).toList(),
            border: pw.TableBorder.all(color: _borderColor, width: 0.8),
            headerStyle: pw.TextStyle(font: ttfBold, fontSize: 10, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: _navyMedium),
            cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 9, color: _textDark),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
