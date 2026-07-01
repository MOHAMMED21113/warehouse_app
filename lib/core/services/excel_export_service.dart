import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../../database/database_helper.dart';
import 'dart:typed_data';   // أضف هذا الاستيراد في أعلى الملف



class ExcelExportService {
  final DatabaseHelper db = DatabaseHelper.instance;

  // ==================== دوال مساعدة آمنة ====================
  TextCellValue _safeText(dynamic value) {
    if (value == null) return  TextCellValue('');
    return TextCellValue(value.toString());
  }

  String _safeDate(dynamic dateValue) {
    if (dateValue == null) return '';
    String dateStr = dateValue.toString();
    if (dateStr.contains('T')) return dateStr.split('T').first;
    if (dateStr.contains(' ')) return dateStr.split(' ').first;
    return dateStr;
  }

  // ✅ حفظ الملف مباشرة عبر نافذة "حفظ باسم" (بدون مشاركة)

  Future<bool> _saveFileWithPicker(List<int> bytes, String fileName) async {
    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف Excel',
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),  // تحويل List<int> إلى Uint8List
      );
      return savePath != null;
    } catch (e) {
      print('خطأ في حفظ الملف: $e');
      return false;
    }
  }

  // ==================== 1. مرتجعات المبيعات ====================
  Future<Map<String, dynamic>> exportSalesReturnsToExcel() async {
    Map<String, dynamic> result = {'success': false, 'path': null, 'error': null};
    try {
      final returns = await db.rawQuery('SELECT sr.*, c.name as customer_name FROM sales_returns sr LEFT JOIN customers c ON sr.customer_id = c.id');
      var excel = Excel.createExcel();
      var sheet = excel['مرتجعات مبيعات'];

      sheet.appendRow([
        _safeText('رقم المرتجع'), _safeText('التاريخ'), _safeText('العميل'),
        _safeText('الإجمالي'), _safeText('المبلغ المسترد'), _safeText('طريقة الاسترداد'), _safeText('ملاحظات')
      ]);

      for (var ret in returns) {
        sheet.appendRow([
          _safeText(ret['return_number']),
          _safeText(_safeDate(ret['return_date'])),
          _safeText(ret['customer_name'] ?? 'غير محدد'),
          _safeText(ret['total_amount']),
          _safeText(ret['refund_amount']),
          _safeText(ret['refund_type']),
          _safeText(ret['notes']),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل في إنشاء الملف');
      final saved = await _saveFileWithPicker(bytes, 'sales_returns_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!saved) throw Exception('لم يتم حفظ الملف');
      result['success'] = true;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  // ==================== 2. مرتجعات المشتريات ====================
  Future<Map<String, dynamic>> exportPurchaseReturnsToExcel() async {
    Map<String, dynamic> result = {'success': false, 'path': null, 'error': null};
    try {
      final returns = await db.rawQuery('SELECT pr.*, s.name as supplier_name FROM purchase_returns pr LEFT JOIN suppliers s ON pr.supplier_id = s.id');
      var excel = Excel.createExcel();
      var sheet = excel['مرتجعات مشتريات'];

      sheet.appendRow([
        _safeText('رقم المرتجع'), _safeText('التاريخ'), _safeText('المورد'),
        _safeText('الإجمالي'), _safeText('المبلغ المسترد'), _safeText('طريقة الاسترداد'), _safeText('ملاحظات')
      ]);

      for (var ret in returns) {
        sheet.appendRow([
          _safeText(ret['return_number']),
          _safeText(_safeDate(ret['return_date'])),
          _safeText(ret['supplier_name'] ?? 'غير محدد'),
          _safeText(ret['total_amount']),
          _safeText(ret['refund_amount']),
          _safeText(ret['refund_type']),
          _safeText(ret['notes']),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل في إنشاء الملف');
      final saved = await _saveFileWithPicker(bytes, 'purchase_returns_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!saved) throw Exception('لم يتم حفظ الملف');
      result['success'] = true;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  // ==================== 3. المنتجات ====================
  Future<Map<String, dynamic>> exportProductsToExcel() async {
    Map<String, dynamic> result = {'success': false, 'path': null, 'error': null};
    try {
      final products = await db.getAllProductsWithDetails();
      var excel = Excel.createExcel();
      var sheet = excel['المنتجات'];

      sheet.appendRow([
        _safeText('ID'), _safeText('الباركود'), _safeText('اسم المنتج'),
        _safeText('المجموعة'), _safeText('الفئة'), _safeText('الصنف'),
        _safeText('الوحدة'), _safeText('السعر'), _safeText('الكمية الحالية'),
        _safeText('الحد الأدنى'), _safeText('تاريخ الإضافة'), _safeText('تاريخ الصلاحية'), _safeText('المورد')
      ]);

      for (var product in products) {
        sheet.appendRow([
          _safeText(product['id']),
          _safeText(product['barcode']),
          _safeText(product['name']),
          _safeText(product['group_name']),
          _safeText(product['category_name']),
          _safeText(product['subcategory_name']),
          _safeText(product['unit_name']),
          _safeText(product['unit_price']),
          _safeText(product['current_stock']),
          _safeText(product['min_stock']),
          _safeText(_safeDate(product['created_at'])),
          _safeText(_safeDate(product['expiry_date'])),
          _safeText(product['supplier_name']),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل في إنشاء الملف');
      final saved = await _saveFileWithPicker(bytes, 'products_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!saved) throw Exception('لم يتم حفظ الملف');
      result['success'] = true;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  // ==================== 4. فواتير البيع ====================
  Future<Map<String, dynamic>> exportSalesInvoicesToExcel() async {
    Map<String, dynamic> result = {'success': false, 'path': null, 'error': null};
    try {
      final invoices = await db.getAllSaleInvoices();
      var excel = Excel.createExcel();
      var sheet = excel['فواتير البيع'];

      sheet.appendRow([
        _safeText('رقم الفاتورة'), _safeText('التاريخ'), _safeText('العميل'),
        _safeText('نوع العميل'), _safeText('حالة الدفع'), _safeText('المبلغ المدفوع'),
        _safeText('الإجمالي'), _safeText('الملاحظات')
      ]);

      for (var invoice in invoices) {
        sheet.appendRow([
          _safeText(invoice['invoice_number']),
          _safeText(_safeDate(invoice['date'])),
          _safeText(invoice['customer_name']),
          _safeText(invoice['customer_type']),
          _safeText(invoice['payment_status']),
          _safeText(invoice['paid_amount']),
          _safeText(invoice['total_amount']),
          _safeText(invoice['notes']),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل في إنشاء الملف');
      final saved = await _saveFileWithPicker(bytes, 'sales_invoices_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!saved) throw Exception('لم يتم حفظ الملف');
      result['success'] = true;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  // ==================== 5. فواتير الشراء ====================
  Future<Map<String, dynamic>> exportPurchaseInvoicesToExcel() async {
    Map<String, dynamic> result = {'success': false, 'path': null, 'error': null};
    try {
      final invoices = await db.getAllPurchaseInvoices();
      var excel = Excel.createExcel();
      var sheet = excel['فواتير الشراء'];

      sheet.appendRow([
        _safeText('رقم الفاتورة'), _safeText('التاريخ'), _safeText('المورد'),
        _safeText('نوع الدفع'), _safeText('حالة الدفع'), _safeText('المبلغ المدفوع'),
        _safeText('الإجمالي'), _safeText('الملاحظات')
      ]);

      for (var invoice in invoices) {
        sheet.appendRow([
          _safeText(invoice['invoice_number']),
          _safeText(_safeDate(invoice['date'])),
          _safeText(invoice['supplier_name']),
          _safeText(invoice['payment_type']),
          _safeText(invoice['payment_status']),
          _safeText(invoice['paid_amount']),
          _safeText(invoice['total_amount']),
          _safeText(invoice['notes']),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل في إنشاء الملف');
      final saved = await _saveFileWithPicker(bytes, 'purchase_invoices_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!saved) throw Exception('لم يتم حفظ الملف');
      result['success'] = true;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  // ==================== 6. المخزون المنخفض ====================
  Future<Map<String, dynamic>> exportLowStockToExcel() async {
    Map<String, dynamic> result = {'success': false, 'path': null, 'error': null};
    try {
      final lowStock = await db.getLowStockReport();
      var excel = Excel.createExcel();
      var sheet = excel['المخزون المنخفض'];

      sheet.appendRow([
        _safeText('اسم المنتج'), _safeText('الكمية الحالية'),
        _safeText('الحد الأدنى'), _safeText('الكمية المطلوبة'), _safeText('الوحدة')
      ]);

      for (var item in lowStock) {
        sheet.appendRow([
          _safeText(item['name']),
          _safeText(item['current_stock']),
          _safeText(item['min_stock']),
          _safeText(item['needed_quantity']),
          _safeText(item['unit_name']),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل في إنشاء الملف');
      final saved = await _saveFileWithPicker(bytes, 'low_stock_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (!saved) throw Exception('لم يتم حفظ الملف');
      result['success'] = true;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }
}