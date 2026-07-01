// lib/core/constants/app_permissions.dart

import 'package:flutter/material.dart';

class AppPermissions {
  static const String all = '*';
  static const String dashboard = 'dashboard';
  static const String salesInvoice = 'sales_invoice';
  static const String purchaseInvoice = 'purchase_invoice';
  static const String salesReturn = 'sales_return';
  static const String purchaseReturn = 'purchase_return';
  static const String invoicesList = 'invoices_list';
  static const String returnsList = 'returns_list';
  static const String addProduct = 'add_product';
  static const String productsList = 'products_list';
  static const String categories = 'categories';
  static const String subcategories = 'subcategories';
  static const String units = 'units';
  static const String warehouses = 'warehouses';
  static const String damagedProducts = 'damaged_products';
  static const String expiredProducts = 'expired_products';
  static const String barcodeScanner = 'barcode_scanner';
  static const String pos = 'pos';
  static const String treasury = 'treasury';
  static const String financialVouchers = 'financial_vouchers';
  static const String debtorsCreditors = 'debtors_creditors';
  static const String debtors = 'debtors';
  static const String creditors = 'creditors';
  static const String accountStatement = 'account_statement';
  static const String profitReports = 'profit_reports';
  static const String exportReports = 'export_reports';
  static const String tasks = 'tasks';
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';
  static const String users = 'users';
  static const String settings = 'settings';
  static const String backup = 'backup';
  static const String shopSettings = 'shop_settings';
  static const String aiChat = 'ai_chat';
  static const String dueReminders = 'due_reminders'; // ✅ تمت إضافته

  static List<String> getAllPermissions() {
    return [
      dashboard, salesInvoice, purchaseInvoice,
      salesReturn, purchaseReturn, invoicesList, returnsList,
      addProduct, productsList, categories, subcategories, units, warehouses,
      damagedProducts, expiredProducts, barcodeScanner,
      pos, treasury, financialVouchers, debtorsCreditors, debtors, creditors, accountStatement,
      profitReports, exportReports, tasks,
      customers, suppliers,
      users, settings, backup, shopSettings, aiChat, dueReminders,
    ];
  }

  static Map<String, String> getPermissionLabels() {
    return {
      dashboard: 'لوحة التحكم',
      salesInvoice: 'فاتورة مبيعات',
      purchaseInvoice: 'فاتورة مشتريات',
      salesReturn: 'مرتجع مبيعات',
      purchaseReturn: 'مرتجع مشتريات',
      invoicesList: 'سجل الفواتير',
      returnsList: 'سجل المرتجعات',
      addProduct: 'إضافة منتج',
      productsList: 'المنتجات',
      categories: 'الأقسام الرئيسية',
      subcategories: 'الأقسام الفرعية',
      units: 'الوحدات',
      warehouses: 'المستودعات',
      damagedProducts: 'التوالف',
      expiredProducts: 'المنتهية الصلاحية',
      barcodeScanner: 'الباركود',
      pos: 'نقطة البيع السريعة',
      treasury: 'الخزينة',
      financialVouchers: 'السندات المالية',
      debtorsCreditors: 'المدينون والدائنون',
      debtors: 'المدينون',
      creditors: 'الدائنون',
      accountStatement: 'كشف الحساب',
      profitReports: 'أرباح وخسائر',
      exportReports: 'تصدير التقارير',
      tasks: 'المهام',
      customers: 'العملاء',
      suppliers: 'الموردين',
      users: 'المستخدمين والصلاحيات',
      settings: 'الإعدادات العامة',
      backup: 'النسخ الاحتياطي',
      shopSettings: 'إعدادات المتجر',
      aiChat: 'المساعد الذكي',
      dueReminders: 'تذكير الديون',
    };
  }

  static Map<String, IconData> getPermissionIcons() {
    return {
      salesInvoice: Icons.point_of_sale_rounded,
      purchaseInvoice: Icons.shopping_cart_rounded,
      salesReturn: Icons.undo_rounded,
      purchaseReturn: Icons.replay_rounded,
      invoicesList: Icons.folder_copy_rounded,
      returnsList: Icons.assignment_return_rounded,
      productsList: Icons.inventory_2_rounded,
      categories: Icons.folder_rounded,
      subcategories: Icons.category_rounded,
      warehouses: Icons.warehouse_rounded,
      units: Icons.straighten_rounded,
      customers: Icons.people_rounded,
      suppliers: Icons.local_shipping_rounded,
      treasury: Icons.account_balance_rounded,
      financialVouchers: Icons.receipt_long_rounded,
      debtors: Icons.money_off_rounded,
      creditors: Icons.savings_rounded,
      dueReminders: Icons.alarm_rounded,
      dashboard: Icons.dashboard_rounded,
      profitReports: Icons.trending_up_rounded,
      expiredProducts: Icons.warning_amber_rounded,
      damagedProducts: Icons.delete_sweep_rounded,
      barcodeScanner: Icons.qr_code_scanner_rounded,
      backup: Icons.cloud_upload_rounded,
      tasks: Icons.task_rounded,
      users: Icons.group_rounded,
      settings: Icons.settings_rounded,
      shopSettings: Icons.store_rounded,
      aiChat: Icons.smart_toy_rounded,
    };
  }

  static Map<String, List<String>> getPermissionGroups() {
    return {
      'المبيعات والمشتريات': [salesInvoice, purchaseInvoice, salesReturn, purchaseReturn, invoicesList, returnsList],
      'المنتجات والمخزون': [addProduct, productsList, categories, subcategories, units, warehouses, damagedProducts, expiredProducts, barcodeScanner],
      'الحسابات والمالية': [pos, treasury, financialVouchers, debtorsCreditors, debtors, creditors, accountStatement],
      'التقارير والإدارة': [dashboard, profitReports, exportReports, tasks],
      'العملاء والموردين': [customers, suppliers],
      'الإعدادات والنظام': [users, settings, backup, shopSettings, aiChat, dueReminders],
    };
  }
}