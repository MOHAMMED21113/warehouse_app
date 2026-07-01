// lib/database/database_helper.dart
import 'package:flutter/foundation.dart'; // 🎯 استخدام foundation بدلاً من material للحفاظ على Clean Architecture
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:synchronized/synchronized.dart';
import '../core/utils/hash_util.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool isRestoring = false;

  static final Lock _restoreLock = Lock();

  double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDB('warehouse.db');
    return _database!;
  }

  // 🎯 1. التهيئة للإصدار رقم 1 (نظيف وبدون ترقيعات)
  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    debugPrint('مسار قاعدة البيانات: $path');

    return await openDatabase(
      path,
      version: 7, // 🚀 إصدار 7: إضافة نظام السلف، الأرقام التسلسلية، سجل التدقيق، والمشتريات المتقدمة
      onConfigure: (db) async {
        if (!isRestoring) {
          await db.execute('PRAGMA foreign_keys = ON'); // تفعيل القيود الصارمة
        } else {
          await db.execute('PRAGMA foreign_keys = OFF');
        }
      },
      onCreate: _createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE users ADD COLUMN full_name TEXT');
            await db.execute('ALTER TABLE users ADD COLUMN permissions TEXT');
          } catch (e) {
            debugPrint('⚠️ Error during migration to v2: $e');
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
                'ALTER TABLE users ADD COLUMN has_biometric INTEGER DEFAULT 0');
            await db.execute(
                'ALTER TABLE users ADD COLUMN secure_permissions TEXT');
          } catch (e) {
            debugPrint('⚠️ Error during migration to v3: $e');
          }
        }
        if (oldVersion < 4) {
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_date ON sales_invoices(date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer_id ON sales_invoices(customer_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
          } catch (e) {
            debugPrint('⚠️ Error during migration to v4: $e');
          }
        }
        if (oldVersion < 5) {
          try {
            // 🚀 إنشاء كافة الفهارس المفقودة لتسريع استعلامات الفلترة الشاملة والبحث الفوري
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_date ON sales_invoices(date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer_id ON sales_invoices(customer_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date ON purchase_invoices(date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier_id ON purchase_invoices(supplier_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)');
          } catch (e) {
            debugPrint('⚠️ Error during migration to v5: $e');
          }
        }
        if (oldVersion < 6) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS dashboard_summary (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                total_sales REAL DEFAULT 0,
                total_purchases REAL DEFAULT 0,
                total_debt REAL DEFAULT 0,
                total_credit REAL DEFAULT 0,
                total_products INTEGER DEFAULT 0,
                expired_products INTEGER DEFAULT 0,
                out_of_stock_products INTEGER DEFAULT 0,
                total_suppliers INTEGER DEFAULT 0,
                total_customers INTEGER DEFAULT 0,
                total_inventory_value REAL DEFAULT 0,
                low_stock_count INTEGER DEFAULT 0,
                today_sales REAL DEFAULT 0,
                month_sales REAL DEFAULT 0,
                last_updated TEXT DEFAULT CURRENT_TIMESTAMP
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_products_expiry ON products(expiry_date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_products_stock ON products(current_stock)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_date ON sales_invoices(date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer ON sales_invoices(customer_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_items_invoice ON sales_items(invoice_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_items_product ON sales_items(product_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date ON purchase_invoices(date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier ON purchase_invoices(supplier_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice ON purchase_items(invoice_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_items_product ON purchase_items(product_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
          } catch (e) {
            debugPrint('⚠️ Error during migration to v6: $e');
          }
        }
        if (oldVersion < 7) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS loans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                loan_type TEXT NOT NULL,
                party_id INTEGER NOT NULL,
                party_name TEXT NOT NULL,
                amount REAL NOT NULL,
                paid_amount REAL DEFAULT 0,
                remaining_balance REAL NOT NULL,
                loan_date TEXT NOT NULL,
                due_date TEXT,
                interest_rate REAL DEFAULT 0,
                status TEXT DEFAULT 'active',
                notes TEXT,
                reference_number TEXT UNIQUE,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_party ON loans(party_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_due_date ON loans(due_date)');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS product_serial_numbers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER NOT NULL,
                serial_number TEXT NOT NULL UNIQUE,
                is_sold INTEGER DEFAULT 0,
                invoice_id INTEGER,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_serials_product ON product_serial_numbers(product_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_serials_number ON product_serial_numbers(serial_number)');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                action TEXT NOT NULL,
                table_name TEXT NOT NULL,
                record_id INTEGER,
                old_value TEXT,
                new_value TEXT,
                timestamp TEXT DEFAULT CURRENT_TIMESTAMP
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_log(table_name)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp)');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS product_batches (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER NOT NULL,
                batch_number TEXT NOT NULL,
                purchase_price REAL NOT NULL,
                quantity REAL NOT NULL,
                remaining_quantity REAL NOT NULL,
                expiry_date TEXT,
                purchase_date TEXT NOT NULL,
                supplier_id INTEGER
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_prod_batches_prod ON product_batches(product_id)');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS inventory_adjustments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER NOT NULL,
                system_quantity REAL NOT NULL,
                actual_quantity REAL NOT NULL,
                difference REAL NOT NULL,
                reason TEXT NOT NULL,
                adjustment_date TEXT DEFAULT CURRENT_TIMESTAMP,
                user_id INTEGER,
                notes TEXT
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_inv_adj_prod ON inventory_adjustments(product_id)');

            try {
              await db.execute('ALTER TABLE purchase_batches ADD COLUMN batch_number TEXT');
              await db.execute('ALTER TABLE purchase_batches ADD COLUMN expiry_date TEXT');
            } catch (_) {}
          } catch (e) {
            debugPrint('⚠️ Error during migration to v7: $e');
          }
        }
      },
    );
  }

  // 🎯 2. بناء الهيكل الكامل بجميع الأعمدة والقيود في دفعة واحدة
  Future _createTables(Database db, int version) async {
    debugPrint('⏳ جاري بناء قاعدة البيانات النظيفة (نسخة $version)...');

    // ================== 1. جداول النظام الأساسية ==================
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        username TEXT NOT NULL UNIQUE, 
        password_hash TEXT NOT NULL, 
        role TEXT DEFAULT "admin",
        full_name TEXT,
        permissions TEXT,
        has_biometric INTEGER DEFAULT 0,
        secure_permissions TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE treasuries (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL UNIQUE, 
        balance REAL DEFAULT 0, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE financial_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL, 
        type TEXT NOT NULL CHECK (type IN ('expense', 'income')), 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL UNIQUE, 
        code TEXT NOT NULL UNIQUE, 
        symbol TEXT, 
        exchange_rate REAL DEFAULT 1.0, 
        is_default INTEGER DEFAULT 0, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE units (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL UNIQUE, 
        symbol TEXT, 
        is_default INTEGER DEFAULT 0, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL, 
        location TEXT, 
        manager TEXT, 
        phone TEXT, 
        is_default INTEGER DEFAULT 0, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ================== 2. جداول الأطراف (العملاء والموردين) ==================
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL, 
        phone TEXT, 
        address TEXT, 
        balance REAL DEFAULT 0, 
        status TEXT DEFAULT 'active', 
        last_transaction_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL, 
        phone TEXT, 
        address TEXT, 
        balance REAL DEFAULT 0, 
        status TEXT DEFAULT 'active', 
        last_transaction_date TEXT,
        total_purchases REAL DEFAULT 0,
        purchase_count INTEGER DEFAULT 0,
        current_level TEXT DEFAULT 'Bronze'
      )
    ''');

    await db.execute('''
      CREATE TABLE account_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        person_id INTEGER NOT NULL, 
        person_type TEXT NOT NULL, 
        ledger_type TEXT NOT NULL, 
        entry_type TEXT NOT NULL, 
        reference_number TEXT, 
        debit_amount REAL DEFAULT 0, 
        credit_amount REAL DEFAULT 0, 
        balance_before REAL DEFAULT 0, 
        balance_after REAL DEFAULT 0, 
        is_settled INTEGER DEFAULT 0, 
        settled_date TEXT, 
        notes TEXT, 
        date TEXT NOT NULL
      )
    ''');

    // ================== 3. جداول الأصناف والمنتجات ==================
    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL UNIQUE, 
        description TEXT, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL, 
        description TEXT, 
        group_id INTEGER NOT NULL, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP, 
        FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE, 
        UNIQUE(name, group_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT NOT NULL, 
        description TEXT, 
        category_id INTEGER NOT NULL, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP, 
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE, 
        UNIQUE(name, category_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        barcode TEXT UNIQUE, 
        second_barcode TEXT,
        name TEXT NOT NULL, 
        subcategory_id INTEGER NOT NULL, 
        unit_id INTEGER, 
        currency_id INTEGER, 
        warehouse_id INTEGER, 
        warehouse_stock INTEGER DEFAULT 0, 
        current_stock REAL DEFAULT 0, 
        unit_price REAL NOT NULL, 
        cost_price REAL DEFAULT 0, 
        min_stock INTEGER DEFAULT 0, 
        supplier_id INTEGER, 
        expiry_date TEXT, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP, 
        is_active INTEGER DEFAULT 1, 
        bonus_enabled INTEGER DEFAULT 0, 
        bonus_required_qty INTEGER, 
        bonus_free_product_id INTEGER REFERENCES products(id) ON DELETE SET NULL, 
        bonus_free_qty INTEGER DEFAULT 1, 
        FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE CASCADE, 
        FOREIGN KEY (unit_id) REFERENCES units (id) ON DELETE SET NULL, 
        FOREIGN KEY (currency_id) REFERENCES currencies (id) ON DELETE SET NULL, 
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE SET NULL, 
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE product_warehouse_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        quantity REAL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
        UNIQUE(product_id, warehouse_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE product_prices (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        product_id INTEGER NOT NULL, 
        unit_id INTEGER NOT NULL, 
        price REAL NOT NULL, 
        is_default INTEGER DEFAULT 0, 
        created_at TEXT DEFAULT CURRENT_TIMESTAMP, 
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE, 
        FOREIGN KEY (unit_id) REFERENCES units (id) ON DELETE CASCADE, 
        UNIQUE(product_id, unit_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE product_unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        product_id INTEGER NOT NULL, 
        from_unit_id INTEGER NOT NULL, 
        to_unit_id INTEGER NOT NULL, 
        quantity REAL NOT NULL, 
        price REAL, 
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE, 
        FOREIGN KEY (from_unit_id) REFERENCES units (id), 
        FOREIGN KEY (to_unit_id) REFERENCES units (id)
      )
    ''');

    // ================== 4. جداول الفواتير والعمليات المالية ==================
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        invoice_number TEXT NOT NULL UNIQUE, 
        supplier_id INTEGER NOT NULL, 
        supplier_name TEXT, 
        payment_type TEXT DEFAULT 'كاش', 
        payment_status TEXT DEFAULT 'كامل', 
        paid_amount REAL DEFAULT 0, 
        subtotal REAL DEFAULT 0, 
        discount_amount REAL DEFAULT 0, 
        tax_rate REAL DEFAULT 0, 
        tax_amount REAL DEFAULT 0, 
        total_amount REAL DEFAULT 0, 
        due_date TEXT, 
        notes TEXT, 
        date TEXT NOT NULL, 
        warehouse_id INTEGER DEFAULT 1,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        invoice_id INTEGER NOT NULL, 
        product_id INTEGER NOT NULL, 
        quantity REAL NOT NULL, 
        unit_cost REAL NOT NULL, 
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE, 
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        invoice_id INTEGER,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        invoice_number TEXT NOT NULL UNIQUE, 
        customer_id INTEGER, 
        customer_name TEXT, 
        customer_phone TEXT, 
        customer_type TEXT DEFAULT 'نقدي', 
        payment_status TEXT DEFAULT 'كامل', 
        paid_amount REAL DEFAULT 0, 
        subtotal REAL DEFAULT 0, 
        discount_amount REAL DEFAULT 0, 
        tax_rate REAL DEFAULT 0, 
        tax_amount REAL DEFAULT 0, 
        total_amount REAL DEFAULT 0, 
        due_date TEXT, 
        notes TEXT, 
        date TEXT NOT NULL, 
        warehouse_id INTEGER DEFAULT 1,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        invoice_id INTEGER NOT NULL, 
        product_id INTEGER NOT NULL, 
        quantity REAL NOT NULL, 
        unit_price REAL NOT NULL, 
        total REAL DEFAULT 0, 
        discount_percent REAL DEFAULT 0, 
        discount_amount REAL DEFAULT 0, 
        is_bonus INTEGER DEFAULT 0, 
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices (id) ON DELETE CASCADE, 
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');

    // ================== 5. جداول المرتجعات ==================
    await db.execute('''
      CREATE TABLE sales_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT NOT NULL UNIQUE,
        original_invoice_id INTEGER NOT NULL,
        customer_id INTEGER,
        return_date TEXT NOT NULL,
        total_amount REAL DEFAULT 0,
        refund_amount REAL DEFAULT 0,
        refund_type TEXT DEFAULT 'كاش',
        notes TEXT,
        FOREIGN KEY (original_invoice_id) REFERENCES sales_invoices (id) ON DELETE RESTRICT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        FOREIGN KEY (return_id) REFERENCES sales_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT NOT NULL UNIQUE,
        original_invoice_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        return_date TEXT NOT NULL,
        total_amount REAL DEFAULT 0,
        refund_amount REAL DEFAULT 0,
        refund_type TEXT DEFAULT 'كاش',
        notes TEXT,
        FOREIGN KEY (original_invoice_id) REFERENCES purchase_invoices (id) ON DELETE RESTRICT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        FOREIGN KEY (return_id) REFERENCES purchase_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');

    // ================== 6. حركات المستودعات والمالية والمهام ==================
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        product_id INTEGER NOT NULL, 
        type TEXT NOT NULL CHECK (type IN ('in', 'out', 'transfer', 'return_in', 'return_out')), 
        quantity REAL NOT NULL, 
        reference_id INTEGER NOT NULL, 
        date TEXT NOT NULL, 
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE warehouse_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        product_id INTEGER NOT NULL, 
        from_warehouse_id INTEGER, 
        to_warehouse_id INTEGER NOT NULL, 
        quantity REAL NOT NULL, 
        type TEXT NOT NULL CHECK (type IN ('in', 'out', 'transfer')), 
        reference_id INTEGER, 
        date TEXT NOT NULL, 
        notes TEXT, 
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE, 
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses (id), 
        FOREIGN KEY (to_warehouse_id) REFERENCES warehouses (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE treasury_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        treasury_id INTEGER NOT NULL, 
        transaction_type TEXT NOT NULL CHECK (transaction_type IN ('in', 'out')), 
        amount REAL NOT NULL, 
        reference_type TEXT NOT NULL, 
        reference_id INTEGER, 
        date TEXT NOT NULL, 
        notes TEXT, 
        FOREIGN KEY (treasury_id) REFERENCES treasuries (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE financial_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        voucher_number TEXT NOT NULL UNIQUE, 
        category_id INTEGER NOT NULL, 
        treasury_id INTEGER NOT NULL, 
        type TEXT NOT NULL CHECK (type IN ('payment', 'receipt')), 
        amount REAL NOT NULL, 
        date TEXT NOT NULL, 
        notes TEXT, 
        FOREIGN KEY (category_id) REFERENCES financial_categories (id) ON DELETE RESTRICT, 
        FOREIGN KEY (treasury_id) REFERENCES treasuries (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE damaged_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL DEFAULT 'بدون-رقم',
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        total_loss REAL NOT NULL,
        reason TEXT NOT NULL,
        status TEXT DEFAULT 'لم يتم الاستلام',
        move_date TEXT NOT NULL,
        moved_by INTEGER,
        notes TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        task_type INTEGER DEFAULT 2,
        priority INTEGER DEFAULT 1,
        status INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        due_date TEXT,
        completed_at TEXT,
        recurrence TEXT,
        parent_task_id INTEGER,
        related_type TEXT,
        related_id INTEGER,
        assigned_to INTEGER,
        created_by INTEGER,
        reminder_sent INTEGER DEFAULT 0,
        FOREIGN KEY (parent_task_id) REFERENCES tasks(id) ON DELETE SET NULL
      )
    ''');

    // ================== 7. جداول نظام الولاء (Loyalty System) ==================
    await db.execute('''
      CREATE TABLE loyalty_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL UNIQUE,
        total_points REAL DEFAULT 0,
        used_points REAL DEFAULT 0,
        available_points REAL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        min_total_purchases REAL DEFAULT 0,
        discount_percent REAL DEFAULT 0,
        color TEXT DEFAULT '#D4AF37',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE loyalty_rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        points_required REAL DEFAULT 0,
        reward_type TEXT NOT NULL CHECK (reward_type IN ('discount_percent', 'free_product', 'coupon', 'gift')),
        reward_value REAL DEFAULT 0,
        product_id INTEGER,
        buy_product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        free_product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        required_quantity INTEGER,
        free_quantity INTEGER,
        is_active INTEGER DEFAULT 1,
        expiry_days INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE loyalty_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        operation_type TEXT NOT NULL CHECK (operation_type IN ('earn_points', 'redeem_points', 'level_up', 'reward_granted', 'coupon_used')),
        value REAL DEFAULT 0,
        points_before REAL DEFAULT 0,
        points_after REAL DEFAULT 0,
        reference_id INTEGER,
        reference_type TEXT,
        notes TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        customer_id INTEGER NOT NULL,
        discount_amount REAL DEFAULT 0,
        is_used INTEGER DEFAULT 0,
        used_invoice_id INTEGER,
        expiry_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE loyalty_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        icon TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dashboard_summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_sales REAL DEFAULT 0,
        total_purchases REAL DEFAULT 0,
        total_debt REAL DEFAULT 0,
        total_credit REAL DEFAULT 0,
        total_products INTEGER DEFAULT 0,
        expired_products INTEGER DEFAULT 0,
        out_of_stock_products INTEGER DEFAULT 0,
        total_suppliers INTEGER DEFAULT 0,
        total_customers INTEGER DEFAULT 0,
        total_inventory_value REAL DEFAULT 0,
        low_stock_count INTEGER DEFAULT 0,
        today_sales REAL DEFAULT 0,
        month_sales REAL DEFAULT 0,
        last_updated TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_type TEXT NOT NULL,
        party_id INTEGER NOT NULL,
        party_name TEXT NOT NULL,
        amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        remaining_balance REAL NOT NULL,
        loan_date TEXT NOT NULL,
        due_date TEXT,
        interest_rate REAL DEFAULT 0,
        status TEXT DEFAULT 'active',
        notes TEXT,
        reference_number TEXT UNIQUE,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_serial_numbers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        serial_number TEXT NOT NULL UNIQUE,
        is_sold INTEGER DEFAULT 0,
        invoice_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER,
        old_value TEXT,
        new_value TEXT,
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        batch_number TEXT NOT NULL,
        purchase_price REAL NOT NULL,
        quantity REAL NOT NULL,
        remaining_quantity REAL NOT NULL,
        expiry_date TEXT,
        purchase_date TEXT NOT NULL,
        supplier_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        system_quantity REAL NOT NULL,
        actual_quantity REAL NOT NULL,
        difference REAL NOT NULL,
        reason TEXT NOT NULL,
        adjustment_date TEXT DEFAULT CURRENT_TIMESTAMP,
        user_id INTEGER,
        notes TEXT
      )
    ''');

    // ================== 8. إنشاء الفهارس (Indexes) لتسريع البحث ==================
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_subcategory ON products(subcategory_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_expiry ON products(expiry_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_stock ON products(current_stock)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_batches_product ON purchase_batches(product_id, purchase_date)');

    // 🚀 الفهرس المركب لتسريع جلب الرصيد التاريخي من دفتر الأستاذ (Index Seek)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ledger_reference_entry ON account_ledger(reference_number, entry_type)');

    // 🚀 الفهارس الأساسية الجديدة لتسريع استعلامات الفواتير والمهام والعملاء والموردين
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_date ON sales_invoices(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer ON sales_invoices(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_items_invoice ON sales_items(invoice_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_items_product ON sales_items(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_invoices_date ON purchase_invoices(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier ON purchase_invoices(supplier_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice ON purchase_items(invoice_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchase_items_product ON purchase_items(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_party ON loans(party_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_due_date ON loans(due_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_serials_product ON product_serial_numbers(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_serials_number ON product_serial_numbers(serial_number)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_log(table_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prod_batches_prod ON product_batches(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inv_adj_prod ON inventory_adjustments(product_id)');

    // ================== 9. إدخال البيانات الافتراضية (Seeding) ==================

    await db.insert('warehouses', {
      'name': 'المستودع الرئيسي',
      'location': 'الموقع الرئيسي',
      'is_default': 1
    });
    await db.insert(
        'treasuries', {'id': 1, 'name': 'الصندوق الرئيسي', 'balance': 0.0});

    await db.insert('financial_categories',
        {'id': 1, 'name': 'إيجار المحل', 'type': 'expense'});
    await db.insert('financial_categories',
        {'id': 2, 'name': 'رواتب الموظفين', 'type': 'expense'});
    await db.insert('financial_categories',
        {'id': 3, 'name': 'كهرباء وإنترنت', 'type': 'expense'});
    await db.insert('financial_categories',
        {'id': 4, 'name': 'تسوية حسابات', 'type': 'income'});
    await db.insert('financial_categories',
        {'id': 5, 'name': 'إيرادات أخرى', 'type': 'income'});

    await db.insert('suppliers',
        {'name': 'مورد تجريبي', 'phone': '0512345678', 'address': 'الرياض'});
    await db.insert('customers', {
      'name': 'عميل نقدي',
      'phone': '',
      'address': '',
      'current_level': 'Bronze'
    });
    await db.insert('units', {'name': 'حبة', 'symbol': 'pc', 'is_default': 1});

    await db.insert('currencies', {
      'name': 'ريال يمني',
      'code': 'YER',
      'symbol': '﷼',
      'exchange_rate': 1.0,
      'is_default': 1
    });
    await db.insert('currencies', {
      'name': 'ريال سعودي',
      'code': 'SAR',
      'symbol': 'ر.س',
      'exchange_rate': 0.015,
      'is_default': 0
    });
    await db.insert('currencies', {
      'name': 'دولار أمريكي',
      'code': 'USD',
      'symbol': '\$',
      'exchange_rate': 0.004,
      'is_default': 0
    });

    await db.insert('groups', {'name': 'عام', 'description': 'مجموعة عامة'});

    await db.insert('customer_levels', {
      'name': 'Bronze',
      'min_total_purchases': 0,
      'discount_percent': 0,
      'color': '#CD7F32'
    });
    await db.insert('customer_levels', {
      'name': 'Silver',
      'min_total_purchases': 500,
      'discount_percent': 2,
      'color': '#C0C0C0'
    });
    await db.insert('customer_levels', {
      'name': 'Gold',
      'min_total_purchases': 2000,
      'discount_percent': 5,
      'color': '#D4AF37'
    });
    await db.insert('customer_levels', {
      'name': 'Platinum',
      'min_total_purchases': 5000,
      'discount_percent': 10,
      'color': '#E5E4E2'
    });

    await db.insert(
        'loyalty_settings', {'key': 'points_per_currency', 'value': '1'});
    await db.insert('loyalty_settings',
        {'key': 'min_invoice_amount_for_points', 'value': '0'});
    await db.insert(
        'loyalty_settings', {'key': 'points_redemption_rate', 'value': '100'});
    await db.insert(
        'loyalty_settings', {'key': 'max_redemption_percent', 'value': '30'});
    await db.insert(
        'loyalty_settings', {'key': 'points_expiry_days', 'value': '0'});

    debugPrint('✅ تم الانتهاء من بناء قاعدة البيانات بالكامل بنجاح!');
  }

  // ==================== الحذف الآمن للمنتجات ====================
  Future<Map<String, dynamic>> deleteProductSafe(int productId) async {
    final db = await database;
    try {
      await db.delete('products', where: 'id = ?', whereArgs: [productId]);
      return {'success': true, 'message': 'تم حذف المنتج بنجاح.'};
    } catch (e) {
      if (e.toString().contains('CONSTRAINT')) {
        return {
          'success': false,
          'message':
              'لا يمكن حذف هذا المنتج لأنه مرتبط بفواتير مبيعات أو مشتريات سابقة. للحفاظ على السجلات المالية، يمكنك فقط تعديله أو تصفير كميته.',
        };
      }
      return {'success': false, 'message': 'حدث خطأ غير متوقع: $e'};
    }
  }

  // ==================== النسخ الاحتياطي والاستعادة ====================
  Future<Map<String, dynamic>> exportDatabaseToJson() async {
    final db = await database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    Map<String, dynamic> backup = {};
    for (var table in tables) {
      String tableName = table['name'] as String;
      // 🔒 استثناء جدول المستخدمين (users) لمنع تسريب كلمات المرور والصلاحيات وبيانات الدخول في ملفات النسخ الاحتياطي الخارجية
      if (tableName == 'users') continue;
      backup[tableName] = await db.query(tableName);
    }
    return backup;
  }

  Future<void> restoreDatabaseFromJson(Map<String, dynamic> jsonData) async {
    await _restoreLock.synchronized(() async {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'warehouse.db');

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      isRestoring = true;
      await deleteDatabase(path);

      final db = await database;

      final List<String> tableOrder = [
        'users',
        'groups',
        'units',
        'currencies',
        'warehouses',
        'suppliers',
        'customers',
        'treasuries',
        'financial_categories',
        'categories',
        'subcategories',
        'products',
        'product_warehouse_stock',
        'product_prices',
        'product_unit_conversions',
        'financial_vouchers',
        'treasury_transactions',
        'purchase_invoices',
        'purchase_items',
        'purchase_batches',
        'sales_invoices',
        'sales_items',
        'sales_returns',
        'sales_return_items',
        'purchase_returns',
        'purchase_return_items',
        'stock_movements',
        'warehouse_movements',
        'account_ledger',
        'tasks',
        'loyalty_points',
        'customer_levels',
        'loyalty_rewards',
        'loyalty_history',
        'coupons',
        'loyalty_settings',
      ];

      try {
        var batch = db.batch();
        for (String tableName in tableOrder.reversed) {
          batch.delete(tableName);
        }
        await batch.commit(noResult: true);

        batch = db.batch();
        for (String tableName in tableOrder) {
          if (jsonData.containsKey(tableName)) {
            List<dynamic> rows = jsonData[tableName];
            for (var row in rows) {
              batch.insert(
                tableName,
                Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
        await batch.commit(noResult: true);
        debugPrint('✅ تمت استعادة البيانات بنجاح وبأمان تام');
      } catch (e) {
        debugPrint('❌ فشل الاستعادة: $e');
        throw Exception('فشلت الاستعادة بسبب: $e');
      } finally {
        isRestoring = false;
        await db.execute('PRAGMA foreign_keys = ON');
      }
    });
  }

  // ==================== دوال المجموعات والفئات والأصناف والوحدات والعملات ====================
  Future<int> insertGroup(Map<String, dynamic> group) async =>
      await (await database).insert('groups', group);
  Future<List<Map<String, dynamic>>> getAllGroups() async =>
      await (await database).query('groups', orderBy: 'name ASC');
  Future<int> updateGroup(int id, Map<String, dynamic> data) async =>
      await (await database).update(
        'groups',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> deleteGroup(int id) async => await (await database).delete('groups', where: 'id = ?', whereArgs: [id]);
  Future<int> insertCategory(Map<String, dynamic> category) async =>
      await (await database).insert('categories', category);
  Future<List<Map<String, dynamic>>> getAllCategories() async =>
      await (await database).rawQuery(
        'SELECT c.*, g.name as group_name FROM categories c JOIN groups g ON c.group_id = g.id ORDER BY g.name ASC, c.name ASC',
      );
  Future<List<Map<String, dynamic>>> getCategoriesByGroup(int groupId) async =>
      await (await database).query(
        'categories',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'name ASC',
      );
  Future<int> updateCategory(int id, Map<String, dynamic> data) async =>
      await (await database).update(
        'categories',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> deleteCategory(int id) async => await (await database).delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> getSubcategoriesCountByCategory(int categoryId) async =>
      ((await (await database).rawQuery(
        'SELECT COUNT(*) as count FROM subcategories WHERE category_id = ?',
        [categoryId],
      ))
          .first['count'] as int);
  Future<int> insertSubcategory(Map<String, dynamic> subcategory) async =>
      await (await database).insert('subcategories', subcategory);
  Future<List<Map<String, dynamic>>> getSubcategoriesByCategory(
    int categoryId,
  ) async =>
      await (await database).query(
        'subcategories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'name ASC',
      );
  Future<List<Map<String, dynamic>>> getAllSubcategoriesWithDetails() async =>
      await (await database).rawQuery(
        'SELECT s.*, c.name as category_name, g.name as group_name FROM subcategories s JOIN categories c ON s.category_id = c.id JOIN groups g ON c.group_id = g.id ORDER BY g.name ASC, c.name ASC, s.name ASC',
      );
  Future<int> updateSubcategory(int id, Map<String, dynamic> data) async {
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove('category_id');
    return await (await database).update(
      'subcategories',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSubcategory(
    int id, {
    int? moveProductsToSubcategoryId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (moveProductsToSubcategoryId != null) {
        await txn.update(
          'products',
          {'subcategory_id': moveProductsToSubcategoryId},
          where: 'subcategory_id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.delete(
          'products',
          where: 'subcategory_id = ?',
          whereArgs: [id],
        );
      }
      await txn.delete('subcategories', where: 'id = ?', whereArgs: [id]);
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> getProductsBySubcategory(
    int subcategoryId,
  ) async =>
      await (await database).query(
        'products',
        where: 'subcategory_id = ?',
        whereArgs: [subcategoryId],
      );
  Future<int> insertUnit(Map<String, dynamic> unit) async =>
      await (await database).insert('units', unit);
  Future<List<Map<String, dynamic>>> getAllUnits() async =>
      await (await database).query('units', orderBy: 'name ASC');
  Future<Map<String, dynamic>?> getDefaultUnit() async {
    final result = await (await database).query(
      'units',
      where: 'is_default = 1',
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> setDefaultUnit(int unitId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('units', {'is_default': 0}, where: 'is_default = 1');
      await txn.update(
        'units',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [unitId],
      );
    });
  }

  Future<int> updateUnit(int id, Map<String, dynamic> data) async =>
      await (await database).update(
        'units',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> deleteUnit(int id) async {
    final db = await database;
    final count = ((await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE unit_id = ?',
      [id],
    ))
        .first['count'] as int);
    if (count > 0)
      throw Exception('لا يمكن الحذف: $count منتج يستخدم هذه الوحدة');
    return await db.delete('units', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getProductsCountByUnit(int unitId) async =>
      ((await (await database).rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE unit_id = ?',
        [unitId],
      ))
          .first['count'] as int);
  Future<int> insertCurrency(Map<String, dynamic> currency) async =>
      await (await database).insert('currencies', currency);
  Future<List<Map<String, dynamic>>> getAllCurrencies() async =>
      await (await database).query('currencies', orderBy: 'name ASC');
  Future<Map<String, dynamic>?> getDefaultCurrency() async {
    final result = await (await database).query(
      'currencies',
      where: 'is_default = 1',
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> setDefaultCurrency(int currencyId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
          'currencies',
          {
            'is_default': 0,
          },
          where: 'is_default = 1');
      await txn.update(
        'currencies',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [currencyId],
      );
    });
  }

  Future<int> updateCurrency(int id, Map<String, dynamic> data) async =>
      await (await database).update(
        'currencies',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> deleteCurrency(int id) async {
    final db = await database;
    final count = ((await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE currency_id = ?',
      [id],
    ))
        .first['count'] as int);
    if (count > 0)
      throw Exception('لا يمكن الحذف: $count منتج يستخدم هذه العملة');
    return await db.delete('currencies', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== دوال المنتجات ====================
  // 🚀 تم إصلاح مشكلة الهارد-كود، الآن يقرأ إجمالي المخزون من كل المستودعات بدلاً من المستودع 1 فقط
  Future<List<Map<String, dynamic>>> getAllProductsWithDetails() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT p.*, 
           COALESCE(pws.total_qty, 0) as current_stock,
           s.name as supplier_name, 
           sub.name as subcategory_name, 
           c.name as category_name, 
           g.name as group_name, 
           u.name as unit_name, u.symbol as unit_symbol, 
           cur.name as currency_name, cur.code as currency_code, cur.symbol as currency_symbol
    FROM products p
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    LEFT JOIN subcategories sub ON p.subcategory_id = sub.id
    LEFT JOIN categories c ON sub.category_id = c.id
    LEFT JOIN groups g ON c.group_id = g.id
    LEFT JOIN units u ON p.unit_id = u.id
    LEFT JOIN currencies cur ON p.currency_id = cur.id
    LEFT JOIN (SELECT product_id, SUM(quantity) as total_qty FROM product_warehouse_stock GROUP BY product_id) pws ON p.id = pws.product_id
    ORDER BY g.name ASC, c.name ASC, sub.name ASC, p.name ASC
  ''');
  }

  // 🚀 استعلام خفيف وسريع للمنتجات المنتهية والمقاربة للانتهاء لإشعارات الخلفية دون JOINs ثقيلة
  Future<List<Map<String, dynamic>>> getExpiringProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, COALESCE(pws.total_qty, p.current_stock, 0) as current_stock
      FROM products p
      LEFT JOIN (SELECT product_id, SUM(quantity) as total_qty FROM product_warehouse_stock GROUP BY product_id) pws ON p.id = pws.product_id
      WHERE p.expiry_date IS NOT NULL 
        AND p.expiry_date != '' 
        AND COALESCE(pws.total_qty, p.current_stock, 0) > 0 
        AND date(p.expiry_date) <= date('now', '+7 days')
      LIMIT 100
    ''');
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    int productId = 0;
    await db.transaction((txn) async {
      productId = await txn.insert('products', product);

      final newStock = (product['current_stock'] as num?)?.toDouble() ?? 0;
      final warehouseId = product['warehouse_id'] ?? 1;
      await txn.insert('product_warehouse_stock', {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': newStock,
      });
    });
    await updateDashboardSummary();
    return productId;
  }

  Future<int> updateProduct(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      final productData = Map<String, dynamic>.from(data);
      productData.remove('warehouse_stock');

      await txn
          .update('products', productData, where: 'id = ?', whereArgs: [id]);

      final newStock = (data['current_stock'] as num?)?.toDouble();
      final warehouseId = data['warehouse_id'] ?? 1;
      if (newStock != null) {
        final existing = await txn.query(
          'product_warehouse_stock',
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [id, warehouseId],
        );
        if (existing.isNotEmpty) {
          await txn.update('product_warehouse_stock', {'quantity': newStock},
              where: 'product_id = ? AND warehouse_id = ?',
              whereArgs: [id, warehouseId]);
        } else {
          await txn.insert('product_warehouse_stock', {
            'product_id': id,
            'warehouse_id': warehouseId,
            'quantity': newStock,
          });
        }
      }
    });
    await updateDashboardSummary();
    return id;
  }

  Future<int> deleteProduct(int id) async {
    final res = await (await database).delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    await updateDashboardSummary();
    return res;
  }

  // ==================== 🚀 نظام ملخصات لوحة التحكم (Dashboard Cache) ====================
  Future<void> updateDashboardSummary() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final monthPrefix = todayStr.substring(0, 7);

      final totalProductsRes = await db.rawQuery('SELECT COUNT(*) as c FROM products WHERE is_active = 1');
      final totalSuppliersRes = await db.rawQuery('SELECT COUNT(*) as c FROM suppliers');
      final totalCustomersRes = await db.rawQuery('SELECT COUNT(*) as c FROM customers');
      final totalInvValueRes = await db.rawQuery('SELECT COALESCE(SUM(current_stock * cost_price), 0) as v FROM products WHERE is_active = 1');
      final lowStockRes = await db.rawQuery('SELECT COUNT(*) as c FROM products WHERE current_stock <= min_stock AND min_stock > 0 AND is_active = 1');
      final outOfStockRes = await db.rawQuery('SELECT COUNT(*) as c FROM products WHERE current_stock <= 0 AND is_active = 1');
      final expiredRes = await db.rawQuery("SELECT COUNT(*) as c FROM products WHERE expiry_date IS NOT NULL AND expiry_date != '' AND expiry_date < date('now') AND is_active = 1");

      final totalSalesRes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as v FROM sales_invoices');
      final totalPurchasesRes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as v FROM purchase_invoices');
      final totalDebtRes = await db.rawQuery('SELECT COALESCE(SUM(balance), 0) as v FROM customers WHERE balance > 0');
      final totalCreditRes = await db.rawQuery('SELECT COALESCE(SUM(balance), 0) as v FROM suppliers WHERE balance > 0');

      final todaySalesRes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as v FROM sales_invoices WHERE substr(date, 1, 10) = ?', [todayStr]);
      final monthSalesRes = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as v FROM sales_invoices WHERE substr(date, 1, 7) = ?', [monthPrefix]);

      await db.insert(
        'dashboard_summary',
        {
          'id': 1,
          'total_sales': (totalSalesRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'total_purchases': (totalPurchasesRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'total_debt': (totalDebtRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'total_credit': (totalCreditRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'total_products': Sqflite.firstIntValue(totalProductsRes) ?? 0,
          'expired_products': Sqflite.firstIntValue(expiredRes) ?? 0,
          'out_of_stock_products': Sqflite.firstIntValue(outOfStockRes) ?? 0,
          'total_suppliers': Sqflite.firstIntValue(totalSuppliersRes) ?? 0,
          'total_customers': Sqflite.firstIntValue(totalCustomersRes) ?? 0,
          'total_inventory_value': (totalInvValueRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'low_stock_count': Sqflite.firstIntValue(lowStockRes) ?? 0,
          'today_sales': (todaySalesRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'month_sales': (monthSalesRes.first['v'] as num?)?.toDouble() ?? 0.0,
          'last_updated': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('⚠️ Error updating dashboard summary cache: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardSummaryCache() async {
    final db = await database;
    final result = await db.query('dashboard_summary', where: 'id = 1');
    if (result.isEmpty) {
      await updateDashboardSummary();
      final newResult = await db.query('dashboard_summary', where: 'id = 1');
      return newResult.isNotEmpty ? newResult.first : {};
    }
    return result.first;
  }

  // ==================== تقارير المخزون والأرباح ====================
  Future<double> getCashBalance() async {
    final db = await database;
    final result = await db.query('treasuries', where: 'id = 1');
    if (result.isNotEmpty) return (result.first['balance'] as num).toDouble();
    return 0.0;
  }

  Future<Map<String, dynamic>> getDailyProfit(DateTime date) async {
    final db = await database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    final salesRes = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_invoices WHERE date(date) = ?",
        [dateStr]);
    final double sales = (salesRes.first['total'] as num).toDouble();

    final salesReturnRes = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_returns WHERE return_date LIKE ?",
        ['$dateStr%']);
    final double salesReturns =
        (salesReturnRes.first['total'] as num).toDouble();

    final double netSales = sales - salesReturns;

    final cogsRes = await db.rawQuery(
        "SELECT COALESCE(SUM(si.quantity * p.cost_price), 0) as total_cogs FROM sales_items si JOIN sales_invoices s ON si.invoice_id = s.id JOIN products p ON si.product_id = p.id WHERE s.date LIKE ?",
        ['$dateStr%']);
    final double cogs = (cogsRes.first['total_cogs'] as num).toDouble();

    final cogsReturnRes = await db.rawQuery(
        "SELECT COALESCE(SUM(sri.quantity * sri.unit_cost), 0) as total_cogs_return FROM sales_return_items sri JOIN sales_returns sr ON sri.return_id = sr.id WHERE sr.return_date LIKE ?",
        ['$dateStr%']);
    final double cogsReturns =
        (cogsReturnRes.first['total_cogs_return'] as num).toDouble();

    final double netCogs = cogs - cogsReturns;

    final expRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total_expenses FROM financial_vouchers WHERE type = 'payment' AND date LIKE ?",
        ['$dateStr%']);
    final double expenses = (expRes.first['total_expenses'] as num).toDouble();

    final double grossProfit = netSales - netCogs;
    final double netProfit = grossProfit - expenses;

    return {
      'date': dateStr,
      'sales': sales,
      'sales_returns': salesReturns,
      'net_sales': netSales,
      'cogs': cogs,
      'cogs_returns': cogsReturns,
      'net_cogs': netCogs,
      'expenses': expenses,
      'gross_profit': grossProfit,
      'profit': netProfit,
    };
  }

  Future<Map<String, dynamic>> getMonthlyProfit(int year, int month) async {
    final db = await database;
    final dateStr = "$year-${month.toString().padLeft(2, '0')}";
    final salesRes = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_invoices WHERE strftime('%Y-%m', date) = ?",
        [dateStr]);
    final double sales = (salesRes.first['total'] as num).toDouble();
    final salesReturnRes = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_returns WHERE strftime('%Y-%m', return_date) = ?",
        [dateStr]);
    final double salesReturns =
        (salesReturnRes.first['total'] as num).toDouble();
    final double netSales = sales - salesReturns;
    final cogsRes = await db.rawQuery(
        "SELECT COALESCE(SUM(si.quantity * p.cost_price), 0) as total_cogs FROM sales_items si JOIN sales_invoices s ON si.invoice_id = s.id JOIN products p ON si.product_id = p.id WHERE strftime('%Y-%m', s.date) = ?",
        [dateStr]);
    final double cogs = (cogsRes.first['total_cogs'] as num).toDouble();
    final cogsReturnRes = await db.rawQuery(
        "SELECT COALESCE(SUM(sri.quantity * sri.unit_cost), 0) as total_cogs_return FROM sales_return_items sri JOIN sales_returns sr ON sri.return_id = sr.id WHERE strftime('%Y-%m', sr.return_date) = ?",
        [dateStr]);
    final double cogsReturns =
        (cogsReturnRes.first['total_cogs_return'] as num).toDouble();
    final double netCogs = cogs - cogsReturns;
    final expRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total_expenses FROM financial_vouchers WHERE type = 'payment' AND strftime('%Y-%m', date) = ?",
        [dateStr]);
    final double expenses = (expRes.first['total_expenses'] as num).toDouble();
    final double grossProfit = netSales - netCogs;
    final double netProfit = grossProfit - expenses;
    return {
      'year': year,
      'month': month,
      'sales': sales,
      'sales_returns': salesReturns,
      'net_sales': netSales,
      'cogs': cogs,
      'cogs_returns': cogsReturns,
      'net_cogs': netCogs,
      'expenses': expenses,
      'gross_profit': grossProfit,
      'profit': netProfit,
    };
  }

  Future<Map<String, dynamic>> getYearlyProfit(int year) async {
    final db = await database;
    final yearStr = year.toString();
    final salesRes = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_invoices WHERE strftime('%Y', date) = ?",
        [yearStr]);
    final double sales = (salesRes.first['total'] as num).toDouble();
    final salesReturnRes = await db.rawQuery(
        "SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_returns WHERE strftime('%Y', return_date) = ?",
        [yearStr]);
    final double salesReturns =
        (salesReturnRes.first['total'] as num).toDouble();
    final double netSales = sales - salesReturns;
    final cogsRes = await db.rawQuery(
        "SELECT COALESCE(SUM(si.quantity * p.cost_price), 0) as total_cogs FROM sales_items si JOIN sales_invoices s ON si.invoice_id = s.id JOIN products p ON si.product_id = p.id WHERE strftime('%Y', s.date) = ?",
        [yearStr]);
    final double cogs = (cogsRes.first['total_cogs'] as num).toDouble();
    final cogsReturnRes = await db.rawQuery(
        "SELECT COALESCE(SUM(sri.quantity * sri.unit_cost), 0) as total_cogs_return FROM sales_return_items sri JOIN sales_returns sr ON sri.return_id = sr.id WHERE strftime('%Y', sr.return_date) = ?",
        [yearStr]);
    final double cogsReturns =
        (cogsReturnRes.first['total_cogs_return'] as num).toDouble();
    final double netCogs = cogs - cogsReturns;
    final expRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total_expenses FROM financial_vouchers WHERE type = 'payment' AND strftime('%Y', date) = ?",
        [yearStr]);
    final double expenses = (expRes.first['total_expenses'] as num).toDouble();
    final double grossProfit = netSales - netCogs;
    final double netProfit = grossProfit - expenses;
    return {
      'year': year,
      'sales': sales,
      'sales_returns': salesReturns,
      'net_sales': netSales,
      'cogs': cogs,
      'cogs_returns': cogsReturns,
      'net_cogs': netCogs,
      'expenses': expenses,
      'gross_profit': grossProfit,
      'profit': netProfit,
    };
  }

  Future<List<Map<String, dynamic>>> getLast7DaysSales() async =>
      await (await database).rawQuery(
        "SELECT date(date) as sale_date, COALESCE(SUM(total_amount), 0) as daily_sales FROM sales_invoices WHERE date(date) >= date('now', '-7 days') GROUP BY date(date) ORDER BY date(date) ASC",
      );

  // 🚀 تم إصلاح مشكلة الهارد-كود (يقرأ الإجمالي من كل المستودعات)
  Future<List<Map<String, dynamic>>> getInventoryReport() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT p.id, p.name, 
           COALESCE(pws.total_qty, 0) as current_stock, 
           u.name as unit_name, u.symbol as unit_symbol, 
           p.unit_price, 
           (COALESCE(pws.total_qty, 0) * p.unit_price) as total_value, 
           p.expiry_date, p.created_at
    FROM products p
    LEFT JOIN units u ON p.unit_id = u.id
    LEFT JOIN (SELECT product_id, SUM(quantity) as total_qty FROM product_warehouse_stock GROUP BY product_id) pws ON p.id = pws.product_id
    ORDER BY p.name ASC
  ''');
  }

  // 🚀 تم إصلاح مشكلة الهارد-كود (يقرأ الإجمالي من كل المستودعات)
  Future<List<Map<String, dynamic>>> getLowStockReport() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT p.id, p.name, 
           COALESCE(pws.total_qty, 0) as current_stock, 
           p.min_stock, 
           u.name as unit_name, u.symbol as unit_symbol, 
           (p.min_stock - COALESCE(pws.total_qty, 0)) as needed_quantity
    FROM products p
    LEFT JOIN units u ON p.unit_id = u.id
    LEFT JOIN (SELECT product_id, SUM(quantity) as total_qty FROM product_warehouse_stock GROUP BY product_id) pws ON p.id = pws.product_id
    WHERE COALESCE(pws.total_qty, 0) <= p.min_stock
    ORDER BY needed_quantity DESC
  ''');
  }

  // 🚀 تم إصلاح مشكلة الهارد-كود (يقرأ الإجمالي من كل المستودعات)
  Future<Map<String, dynamic>> getInventorySummary() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COUNT(DISTINCT p.id) as total_products,
           SUM(COALESCE(pws.total_qty, 0) * p.unit_price) as total_value,
           COUNT(CASE WHEN COALESCE(pws.total_qty, 0) <= p.min_stock THEN 1 END) as low_stock_count
    FROM products p
    LEFT JOIN (SELECT product_id, SUM(quantity) as total_qty FROM product_warehouse_stock GROUP BY product_id) pws ON p.id = pws.product_id
  ''');
    return result.first;
  }

  // ==================== دوال الموردين والعملاء والمستخدمين ====================
  Future<List<Map<String, dynamic>>> getAllSuppliers() async =>
      await (await database).query('suppliers', orderBy: 'name ASC');
  Future<int> insertSupplier(Map<String, dynamic> supplier) async =>
      await (await database).insert('suppliers', supplier);
  Future<int> updateSupplier(int id, Map<String, dynamic> data) async =>
      await (await database).update(
        'suppliers',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> deleteSupplier(int id) async => await (await database).delete(
        'suppliers',
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<List<Map<String, dynamic>>> getAllCustomers() async =>
      await (await database).query('customers', orderBy: 'name ASC');
  Future<int> insertCustomer(Map<String, dynamic> customer) async =>
      await (await database).insert('customers', customer);
  Future<int> updateCustomer(int id, Map<String, dynamic> data) async =>
      await (await database).update(
        'customers',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> deleteCustomer(int id) async => await (await database).delete(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
  Future<int> insertUser(Map<String, dynamic> user) async {
    final mutableUser = Map<String, dynamic>.from(user);
    if (mutableUser.containsKey('password')) {
      mutableUser['password_hash'] = await HashUtil.hashPassword(mutableUser['password']);
      mutableUser.remove('password');
    } else if (mutableUser.containsKey('password_hash')) {
      final pwd = mutableUser['password_hash'] as String;
      if (!pwd.startsWith('\$2a\$') && !pwd.startsWith('\$2b\$')) {
        mutableUser['password_hash'] = await HashUtil.hashPassword(pwd);
      }
    }
    return await (await database).insert('users', mutableUser);
  }
  Future<List<Map<String, dynamic>>> getAllUsers() async =>
      await (await database).query('users', orderBy: 'username ASC');
  Future<Map<String, dynamic>?> getUserById(int id) async {
    final r = await (await database).query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return r.isNotEmpty ? r.first : null;
  }

  // ==================== دوال المستخدمين ====================
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT * FROM users WHERE LOWER(username) = LOWER(?)',
      [username],
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final r = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (r.isNotEmpty) {
      final user = Map<String, dynamic>.from(r.first);
      final storedHash = user['password_hash'] as String?;
      if (storedHash != null) {
        if (storedHash.startsWith('\$2a\$') ||
            storedHash.startsWith('\$2b\$')) {
          if (HashUtil.verifyPassword(password, storedHash)) {
            return user;
          }
        } else {
          // Plaintext fallback for older existing accounts
          if (storedHash == password) {
            final newHash = await HashUtil.hashPassword(password);
            await db.update('users', {'password_hash': newHash},
                where: 'id = ?', whereArgs: [user['id']]);
            user['password_hash'] = newHash;
            return user;
          }
        }
      }
    }
    return null;
  }

  Future<int> updateUser(int id, Map<String, dynamic> data) async {
    final mutableData = Map<String, dynamic>.from(data);
    if (mutableData.containsKey('password')) {
      mutableData['password_hash'] = await HashUtil.hashPassword(mutableData['password']);
      mutableData.remove('password');
    } else if (mutableData.containsKey('password_hash')) {
      final pwd = mutableData['password_hash'] as String;
      if (!pwd.startsWith('\$2a\$') && !pwd.startsWith('\$2b\$')) {
        mutableData['password_hash'] = await HashUtil.hashPassword(pwd);
      }
    }
    return await (await database).update(
      'users',
      mutableData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async =>
      await (await database).delete('users', where: 'id = ?', whereArgs: [id]);
  Future<bool> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    final db = await database;
    final user = await getUserById(userId);
    if (user != null) {
      final storedHash = user['password_hash'] as String?;
      bool isValid = false;
      if (storedHash != null) {
        if (storedHash.startsWith('\$2a\$') || storedHash.startsWith('\$2b\$')) {
          isValid = HashUtil.verifyPassword(oldPassword, storedHash);
        } else {
          isValid = storedHash == oldPassword;
        }
      }
      if (isValid) {
        final newHash = await HashUtil.hashPassword(newPassword);
        await db.update(
          'users',
          {'password_hash': newHash},
          where: 'id = ?',
          whereArgs: [userId],
        );
        return true;
      }
    }
    return false;
  }

  Future<void> changeUserRole(int userId, String newRole) async =>
      await (await database).update(
        'users',
        {'role': newRole},
        where: 'id = ?',
        whereArgs: [userId],
      );

  // ==================== توليد أرقام الفواتير والمرتجعات ====================
  Future<String> _generateInvoiceNumber(
      DatabaseExecutor executor, String prefix) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    String table;
    String column;
    if (prefix == 'PO') {
      table = 'purchase_invoices';
      column = 'invoice_number';
    } else if (prefix == 'SO') {
      table = 'sales_invoices';
      column = 'invoice_number';
    } else if (prefix == 'SR') {
      table = 'sales_returns';
      column = 'return_number';
    } else if (prefix == 'PR') {
      table = 'purchase_returns';
      column = 'return_number';
    } else if (prefix == 'PAY' || prefix == 'REC' || prefix == 'STL') {
      table = 'financial_vouchers';
      column = 'voucher_number';
    } else {
      // بادئ غير معروف، نستخدم الفواتير المالية كافتراضي
      table = 'financial_vouchers';
      column = 'voucher_number';
    }

    int sequence = 1;

    try {
      // المحاولة الأولى: استخراج الرقم التسلسلي من العمود النصي
      final result = await executor.rawQuery(
          "SELECT MAX(CAST(substr($column, length('$prefix-$dateStr-') + 1) AS INTEGER)) as max_seq "
          "FROM $table WHERE $column LIKE '$prefix-$dateStr-%'");
      if (result.isNotEmpty && result.first['max_seq'] != null) {
        sequence = (result.first['max_seq'] as int) + 1;
      }
    } catch (e) {
      // في حال فشل CAST أو أي خطأ، نلجأ إلى MAX(id) كحل احتياطي
      final fallbackResult = await executor.rawQuery(
          "SELECT MAX(id) as max_id FROM $table WHERE $column LIKE '$prefix-$dateStr-%'");
      if (fallbackResult.isNotEmpty && fallbackResult.first['max_id'] != null) {
        // نأخذ أكبر معرف ونضيف 1 (افتراض أن المعرفات متتالية، وهذا ليس دقيقاً 100% ولكن آمن)
        sequence = (fallbackResult.first['max_id'] as int) + 1;
      } else {
        // إذا لم يكن هناك سجلات، نبدأ من 1
        sequence = 1;
      }
    }

    return '$prefix-$dateStr-${sequence.toString().padLeft(3, '0')}';
  }

  // ==================== فاتورة الشراء ====================
  Future<Map<String, dynamic>> createPurchaseInvoice({
    required int supplierId,
    required String paymentType,
    required String paymentStatus,
    required double paidAmount,
    required String? dueDate,
    required String? notes,
    required List<Map<String, dynamic>> items,
    int warehouseId = 1,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {
      'success': false,
      'invoiceId': null,
      'invoiceNumber': null,
      'error': null,
    };
    try {
      await db.transaction((txn) async {
        final invoiceNumber = await _generateInvoiceNumber(txn, 'PO');
        final date = DateTime.now().toIso8601String();
        double totalAmount = 0;
        for (final item in items) {
          totalAmount += item['quantity'] * item['unitCost'];
        }
        totalAmount = _round(totalAmount);
        final roundedPaid = _round(paidAmount);
        String? supplierName;
        final supplierResult = await txn.rawQuery(
          'SELECT name FROM suppliers WHERE id = ?',
          [supplierId],
        );
        if (supplierResult.isNotEmpty)
          supplierName = supplierResult.first['name'] as String;
        final invoiceId = await txn.insert('purchase_invoices', {
          'invoice_number': invoiceNumber,
          'supplier_id': supplierId,
          'supplier_name': supplierName,
          'payment_type': paymentType,
          'payment_status': paymentStatus,
          'paid_amount': roundedPaid,
          'due_date': dueDate,
          'notes': notes,
          'date': date,
          'total_amount': totalAmount,
          'warehouse_id': warehouseId,
        });
        if (roundedPaid > 0) {
          await _addToTreasuryLogic(
            txn,
            treasuryId: 1,
            transactionType: 'out',
            amount: roundedPaid,
            referenceType: 'purchase_invoice',
            referenceId: invoiceId,
            notes: 'دفعة نقدية لمورد عن فاتورة شراء رقم $invoiceNumber',
          );
        }
        await _addToLedgerLogic(
          txn,
          personId: supplierId,
          personType: 'supplier',
          entryType: 'invoice',
          referenceNumber: invoiceNumber,
          debitAmount: 0,
          creditAmount: totalAmount,
          notes: 'فاتورة مشتريات رقم $invoiceNumber',
        );
        if (roundedPaid > 0) {
          await _addToLedgerLogic(
            txn,
            personId: supplierId,
            personType: 'supplier',
            entryType: 'payment',
            referenceNumber: invoiceNumber,
            debitAmount: roundedPaid,
            creditAmount: 0,
            notes: 'دفعة للمورد',
          );
        }
        for (final item in items) {
          final productId = item['productId'];
          final addedQuantity = (item['quantity'] as num).toDouble();
          final newUnitCost = _round((item['unitCost'] as num).toDouble());
          await txn.insert('purchase_items', {
            'invoice_id': invoiceId,
            'product_id': productId,
            'quantity': addedQuantity,
            'unit_cost': newUnitCost,
          });
          await _addStockToWarehouse(
              txn, productId, warehouseId, addedQuantity);
          final productData = await txn.rawQuery(
            'SELECT current_stock, cost_price, unit_price FROM products WHERE id = ?',
            [productId],
          );
          double oldStock = 0.0, oldCostPrice = 0.0, oldUnitPrice = 0.0;
          if (productData.isNotEmpty) {
            oldStock =
                (productData.first['current_stock'] as num?)?.toDouble() ?? 0;
            oldCostPrice =
                (productData.first['cost_price'] as num?)?.toDouble() ?? 0;
            oldUnitPrice =
                (productData.first['unit_price'] as num?)?.toDouble() ?? 0;
          }
          double newAverageCost = newUnitCost;
          if (oldStock > 0) {
            double totalOldValue = _round(oldStock * oldCostPrice);
            double totalNewValue = _round(addedQuantity * newUnitCost);
            newAverageCost = _round(
                (totalOldValue + totalNewValue) / (oldStock + addedQuantity));
          }

          // 💡 ملاحظة: تحديث سعر البيع هنا تلقائي للحفاظ على نسبة الربح (يمكن ربطه بإعدادات النظام مستقبلاً)
          double profitPercent = oldCostPrice > 0
              ? (oldUnitPrice - oldCostPrice) / oldCostPrice
              : 0.20;
          double newUnitPrice = _round(newAverageCost * (1 + profitPercent));

          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ?, cost_price = ?, unit_price = ? WHERE id = ?',
            [addedQuantity, newAverageCost, newUnitPrice, productId],
          );
          await txn.insert('purchase_batches', {
            'product_id': productId,
            'quantity': addedQuantity,
            'remaining_quantity': addedQuantity,
            'cost_price': newUnitCost,
            'purchase_date': date,
            'invoice_id': invoiceId,
          });
        }
        result = {
          'success': true,
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber
        };
      });
    } catch (e) {
      result['error'] = e.toString();
    }
    if (result['success'] == true) {
      await updateDashboardSummary();
    }
    return result;
  }

  // ==================== فاتورة البيع ====================
  // ==================== فاتورة البيع (النسخة المحصنة والمصلحة) ====================
  Future<Map<String, dynamic>> createSaleInvoice({
    required int? customerId,
    required String? customerName,
    required String? customerPhone,
    required String customerType,
    required String paymentStatus,
    required double paidAmount,
    required String? dueDate,
    required String? notes,
    required List<Map<String, dynamic>> items,
    double? grandTotal,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    String valuationMethod = 'WAC',
    int warehouseId = 1,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {
      'success': false,
      'invoiceId': null,
      'invoiceNumber': null,
      'error': null
    };

    try {
      await db.transaction((txn) async {
        // 1. التحقق من توفر الكميات قبل فعل أي شيء
        for (final item in items) {
          final productId = item['productId'];
          // حماية ضد القيم المفقودة (Null) وتحويلها بشكل آمن
          final requiredQty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final available =
              await _getStockInWarehouse(txn, productId, warehouseId);
          if (available < requiredQty) {
            throw Exception(
                'الكمية غير متوفرة للمنتج ذو المعرف $productId في المستودع $warehouseId');
          }
        }

        // 2. توليد رقم الفاتورة
        final invoiceNumber = await _generateInvoiceNumber(txn, 'SO');
        final date = DateTime.now().toIso8601String();

        // 3. تجهيز المجاميع بشكل آمن
        double finalTotal = grandTotal ?? 0.0;
        if (finalTotal == 0.0) {
          finalTotal = items.fold(0.0, (sum, item) {
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final price = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
            return sum + (qty * price);
          });
        }

        finalTotal = _round(finalTotal);
        final roundedPaid = _round(paidAmount);
        final roundedSubtotal = _round(subtotal ?? 0.0);
        final roundedDiscount = _round(discountAmount ?? 0.0);
        final roundedTax = _round(taxAmount ?? 0.0);

        // 4. إنشاء الفاتورة في جدول sales_invoices
        final invoiceId = await txn.insert('sales_invoices', {
          'invoice_number': invoiceNumber,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_type': customerType,
          'payment_status': paymentStatus,
          'paid_amount': roundedPaid,
          'total_amount': finalTotal,
          'subtotal': roundedSubtotal,
          'discount_amount': roundedDiscount,
          'tax_amount': roundedTax,
          'due_date': dueDate,
          'notes': notes,
          'date': date,
          'warehouse_id': warehouseId,
        });

        // 5. تسجيل الدفعة في الخزينة إذا كان هناك دفع نقدي
        if (roundedPaid > 0) {
          await _addToTreasuryLogic(
            txn,
            treasuryId: 1,
            transactionType: 'in',
            amount: roundedPaid,
            referenceType: 'sales_invoice',
            referenceId: invoiceId,
            notes: 'تحصيل نقدي من فاتورة مبيعات رقم $invoiceNumber',
          );
        }

        // 6. تسجيل العملية في دفتر الأستاذ للعميل
        if (customerId != null) {
          await _addToLedgerLogic(
            txn,
            personId: customerId,
            personType: 'customer',
            entryType: 'invoice',
            referenceNumber: invoiceNumber,
            debitAmount: finalTotal,
            creditAmount: 0,
            notes: 'فاتورة مبيعات رقم $invoiceNumber',
          );
          if (roundedPaid > 0) {
            await _addToLedgerLogic(
              txn,
              personId: customerId,
              personType: 'customer',
              entryType: 'payment',
              referenceNumber: invoiceNumber,
              debitAmount: 0,
              creditAmount: roundedPaid,
              notes: 'دفعة من العميل',
            );
          }
        }

        // 7. إضافة المنتجات إلى sales_items وخصمها من المخزون
        for (final item in items) {
          final productId = item['productId'];
          final double quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final double unitPrice =
              _round((item['unitPrice'] as num?)?.toDouble() ?? 0.0);

          // حماية ضد اختفاء حقل isBonus
          final bool isBonus = (item.containsKey('isBonus')
                  ? item['isBonus']
                  : item['is_bonus']) ==
              true;

          await txn.insert('sales_items', {
            'invoice_id': invoiceId,
            'product_id': productId,
            'quantity': quantity,
            'unit_price': unitPrice,
            'is_bonus': isBonus ? 1 : 0,
          });

          // خصم من مستودع محدد
          await _deductStockFromWarehouse(
              txn, productId, warehouseId, quantity);

          // خصم من المخزون الإجمالي للمنتج
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [quantity, productId],
          );

          // تسجيل حركة المخزون
          await txn.insert('stock_movements', {
            'product_id': productId,
            'type': 'out',
            'quantity': quantity,
            'reference_id': invoiceId,
            'date': date,
          });

          // 8. حساب التكلفة (مغلف بـ try/catch لمنع فشل الفاتورة بأكملها إذا فشلت هذه الجزئية المحاسبية)
          try {
            double cogsAmount = 0.0;
            if (valuationMethod == 'FIFO') {
              cogsAmount = await _consumeFIFO(txn, productId, quantity);
            } else {
              final productData = await txn.rawQuery(
                'SELECT cost_price FROM products WHERE id = ?',
                [productId],
              );
              if (productData.isNotEmpty) {
                final double currentAvgCost =
                    (productData.first['cost_price'] as num?)?.toDouble() ??
                        0.0;
                cogsAmount = _round(quantity * currentAvgCost);
              }
            }
          } catch (cogsError) {
            print(
                '⚠️ تحذير: فشل حساب التكلفة (COGS) للمنتج $productId: $cogsError');
          }

          // 9. التحقق من الحد الأدنى للمخزون
          final productInfo = await txn.rawQuery(
            'SELECT name, min_stock, current_stock FROM products WHERE id = ?',
            [productId],
          );
          if (productInfo.isNotEmpty) {
            final productName = productInfo.first['name'] as String;
            final minStock =
                (productInfo.first['min_stock'] as num?)?.toInt() ?? 0;
            final newStock =
                (productInfo.first['current_stock'] as num?)?.toInt() ?? 0;

            if (newStock <= minStock) {
              await _autoGenerateRestockTask(
                  txn, productId, newStock, minStock, productName);
            }
          }
        }

        // إعداد النتيجة النهائية للنجاح
        result = {
          'success': true,
          'invoiceId': invoiceId,
          'invoiceNumber': invoiceNumber
        };
      });
    } catch (e) {
      print('❌ خطأ تفصيلي أثناء حفظ الفاتورة: $e');
      result['error'] = e.toString().replaceAll('Exception: ', '');
    }
    if (result['success'] == true) {
      await updateDashboardSummary();
    }
    return result;
  }

  Future<void> _autoGenerateRestockTask(
    DatabaseExecutor txn,
    int productId,
    int newStock,
    int minStock,
    String productName,
  ) async {
    if (newStock <= minStock) {
      final existing = await txn.query(
        'tasks',
        where: 'related_type = ? AND related_id = ? AND status != 2',
        whereArgs: ['product', productId],
      );
      if (existing.isEmpty) {
        await txn.insert('tasks', {
          'title': '⚠️ تنبيه: المخزون منخفض',
          'description':
              'المنتج: $productName\nالكمية الحالية: $newStock\nالحد الأدنى: $minStock',
          'task_type': 1,
          'priority': 2,
          'status': 0,
          'created_at': DateTime.now().toIso8601String(),
          'related_type': 'product',
          'related_id': productId,
        });
      }
    }
  }

  Future<Map<String, dynamic>> processSettlementPayment({
    required int personId,
    required String personType,
    required double amount,
    required String personName,
    String referenceNumber = '',
    String notes = '',
  }) async {
    final db = await database;
    final result = {
      'success': false,
      'message': '',
    };
    try {
      await db.transaction((txn) async {
        final isPayment = personType == 'supplier';
        final treasuryTransactionType = isPayment ? 'out' : 'in';
        final referenceType =
            isPayment ? 'supplier_settlement' : 'customer_settlement';

        final voucherType = isPayment ? 'payment' : 'receipt';
        final voucherPrefix = isPayment ? 'PAY' : 'REC';

        final roundedAmount = _round(amount);

        if (isPayment) {
          final treasury = await txn.query(
            'treasuries',
            where: 'id = ?',
            whereArgs: [1],
          );
          if (treasury.isEmpty) throw Exception('الخزينة غير موجودة');
          final currentBalance = (treasury.first['balance'] as num).toDouble();
          if (currentBalance < roundedAmount) {
            throw Exception(
              'رصيد الخزينة لا يكفي لإتمام عملية الدفع. الرصيد الحالي: ${currentBalance.toStringAsFixed(2)} ريال',
            );
          }
        }

        final double debitAmount = isPayment ? roundedAmount : 0;
        final double creditAmount = isPayment ? 0 : roundedAmount;

        final finalNotes = notes.isNotEmpty
            ? notes
            : (isPayment
                ? 'دفعة للمورد/الدائن $personName'
                : 'تحصيل من العميل/المدين $personName');

        final voucherNumber = await _generateInvoiceNumber(txn, voucherPrefix);

        await txn.insert('financial_vouchers', {
          'voucher_number': voucherNumber,
          'category_id': 4,
          'treasury_id': 1,
          'type': voucherType,
          'amount': roundedAmount,
          'date': DateTime.now().toIso8601String(),
          'notes': finalNotes,
        });

        await _addToLedgerLogic(
          txn,
          personId: personId,
          personType: personType,
          entryType: 'settlement',
          referenceNumber: voucherNumber,
          debitAmount: debitAmount,
          creditAmount: creditAmount,
          notes: finalNotes,
        );

        await _addToTreasuryLogic(
          txn,
          treasuryId: 1,
          transactionType: treasuryTransactionType,
          amount: roundedAmount,
          referenceType: referenceType,
          referenceId: personId,
          notes:
              'سند ${isPayment ? 'صرف' : 'قبض'} رقم $voucherNumber: $finalNotes',
        );

        await _distributePaymentToInvoices(
            txn, personId, personType, roundedAmount);

        result['success'] = true;
        result['message'] = isPayment
            ? 'تم إنشاء سند صرف جديد بنجاح برقم $voucherNumber وتسديد الفواتير.'
            : 'تم إنشاء سند قبض جديد بنجاح برقم $voucherNumber وتسديد الفواتير.';
      });
    } catch (e) {
      result['message'] = e.toString().replaceFirst('Exception: ', '');
    }
    return result;
  }

  Future<Map<String, dynamic>> processSalesReturn({
    required int originalInvoiceId,
    required int? customerId,
    required List<Map<String, dynamic>> returnItems,
    required double totalRefund,
    required String refundType,
    required String notes,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {
      'success': false,
      'returnId': null,
      'returnNumber': null,
      'error': null
    };
    try {
      await db.transaction((txn) async {
        final returnNumber = await _generateInvoiceNumber(txn, 'SR');
        final date = DateTime.now().toIso8601String();
        final roundedTotal = _round(totalRefund);
        final returnId = await txn.insert('sales_returns', {
          'return_number': returnNumber,
          'original_invoice_id': originalInvoiceId,
          'customer_id': customerId,
          'return_date': date,
          'total_amount': roundedTotal,
          'refund_amount': roundedTotal,
          'refund_type': refundType,
          'notes': notes,
        });
        for (final item in returnItems) {
          final productId = item['productId'];
          final int qty = item['quantity'];
          final double unitPrice = _round(item['unitPrice']);
          final double unitCost = _round(item['unitCost']);
          await txn.insert('sales_return_items', {
            'return_id': returnId,
            'product_id': productId,
            'quantity': qty,
            'unit_price': unitPrice,
            'unit_cost': unitCost,
          });
          await _addStockToWarehouse(txn, productId, 1, qty.toDouble());
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [qty, productId],
          );
          await txn.insert('stock_movements', {
            'product_id': productId,
            'type': 'return_in',
            'quantity': qty,
            'reference_id': returnId,
            'date': date,
          });
        }
        if (refundType == 'كاش' && roundedTotal > 0) {
          await _addToTreasuryLogic(
            txn,
            treasuryId: 1,
            transactionType: 'out',
            amount: roundedTotal,
            referenceType: 'sales_return',
            referenceId: returnId,
            notes: 'رد نقدي عن مرتجع مبيعات رقم $returnNumber',
          );
        } else if (refundType == 'آجل' &&
            customerId != null &&
            roundedTotal > 0) {
          await _addToLedgerLogic(
            txn,
            personId: customerId,
            personType: 'customer',
            entryType: 'return',
            referenceNumber: returnNumber,
            debitAmount: 0,
            creditAmount: roundedTotal,
            notes: 'مرتجع مبيعات عن فاتورة أصلية $originalInvoiceId',
          );
        }
        result = {
          'success': true,
          'returnId': returnId,
          'returnNumber': returnNumber
        };
      });
    } catch (e) {
      result['error'] = e.toString();
    }
    if (result['success'] == true) {
      await updateDashboardSummary();
    }
    return result;
  }

  Future<Map<String, dynamic>> processPurchaseReturn({
    required int originalInvoiceId,
    required int supplierId,
    required List<Map<String, dynamic>> returnItems,
    required double totalRefund,
    required String refundType,
    required String notes,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {
      'success': false,
      'returnId': null,
      'returnNumber': null,
      'error': null
    };
    try {
      await db.transaction((txn) async {
        final returnNumber = await _generateInvoiceNumber(txn, 'PR');
        final date = DateTime.now().toIso8601String();
        final roundedTotal = _round(totalRefund);
        final returnId = await txn.insert('purchase_returns', {
          'return_number': returnNumber,
          'original_invoice_id': originalInvoiceId,
          'supplier_id': supplierId,
          'return_date': date,
          'total_amount': roundedTotal,
          'refund_amount': roundedTotal,
          'refund_type': refundType,
          'notes': notes,
        });
        for (final item in returnItems) {
          final productId = item['productId'];
          final int qty = item['quantity'];
          final double unitCost = _round(item['unitCost']);
          await txn.insert('purchase_return_items', {
            'return_id': returnId,
            'product_id': productId,
            'quantity': qty,
            'unit_price': 0,
            'unit_cost': unitCost,
          });
          await _deductStockFromWarehouse(txn, productId, 1, qty.toDouble());
          await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [qty, productId],
          );
          await txn.insert('stock_movements', {
            'product_id': productId,
            'type': 'return_out',
            'quantity': qty,
            'reference_id': returnId,
            'date': date,
          });
        }
        if (refundType == 'كاش' && roundedTotal > 0) {
          await _addToTreasuryLogic(
            txn,
            treasuryId: 1,
            transactionType: 'in',
            amount: roundedTotal,
            referenceType: 'purchase_return',
            referenceId: returnId,
            notes: 'استرداد نقدي عن مرتجع مشتريات رقم $returnNumber',
          );
        } else if (refundType == 'آجل' && roundedTotal > 0) {
          await _addToLedgerLogic(
            txn,
            personId: supplierId,
            personType: 'supplier',
            entryType: 'return',
            referenceNumber: returnNumber,
            debitAmount: roundedTotal,
            creditAmount: 0,
            notes: 'مرتجع مشتريات عن فاتورة أصلية $originalInvoiceId',
          );
        }
        result = {
          'success': true,
          'returnId': returnId,
          'returnNumber': returnNumber
        };
      });
    } catch (e) {
      result['error'] = e.toString();
    }
    if (result['success'] == true) {
      await updateDashboardSummary();
    }
    return result;
  }

  // ============================================================
  // دوال فواتير المشتريات (مع حساب الرصيد السابق ديناميكياً)
  // ============================================================

  Future<List<Map<String, dynamic>>> getAllPurchaseInvoices() async =>
      await (await database).rawQuery('''
      SELECT pi.*, s.name as supplier_name, s.phone as supplier_phone, 
      COALESCE(al.balance_before, 0) AS previous_balance 
      FROM purchase_invoices pi 
      LEFT JOIN suppliers s ON pi.supplier_id = s.id 
      LEFT JOIN account_ledger al ON al.reference_number = pi.invoice_number AND al.entry_type = 'invoice'
      ORDER BY pi.date DESC
    ''');

  Future<Map<String, dynamic>?> getPurchaseInvoiceById(int id) async {
    final r = await (await database).rawQuery('''
    SELECT pi.*, s.name as supplier_name, s.phone as supplier_phone, s.address as supplier_address, 
    COALESCE(al.balance_before, 0) AS previous_balance 
    FROM purchase_invoices pi 
    LEFT JOIN suppliers s ON pi.supplier_id = s.id 
    LEFT JOIN account_ledger al ON al.reference_number = pi.invoice_number AND al.entry_type = 'invoice'
    WHERE pi.id = ?
  ''', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<List<Map<String, dynamic>>> getPurchaseInvoiceItems(
          int invoiceId) async =>
      await (await database).rawQuery(
        'SELECT pi.*, p.name as product_name, p.barcode, u.name as unit_name, u.symbol as unit_symbol FROM purchase_items pi JOIN products p ON pi.product_id = p.id LEFT JOIN units u ON p.unit_id = u.id WHERE pi.invoice_id = ?',
        [invoiceId],
      );

  Future<List<Map<String, dynamic>>> getAllSaleInvoices() async =>
      await (await database).rawQuery('''
      SELECT si.*, c.name as customer_name, c.phone as customer_phone, 
      COALESCE(al.balance_before, 0) AS previous_balance 
      FROM sales_invoices si 
      LEFT JOIN customers c ON si.customer_id = c.id 
      LEFT JOIN account_ledger al ON al.reference_number = si.invoice_number AND al.entry_type = 'invoice'
      ORDER BY si.date DESC
    ''');

  Future<Map<String, dynamic>?> getSaleInvoiceById(int id) async {
    final r = await (await database).rawQuery('''
    SELECT si.*, c.name as customer_name, c.phone as customer_phone, c.address as customer_address, 
    COALESCE(al.balance_before, 0) AS previous_balance 
    FROM sales_invoices si 
    LEFT JOIN customers c ON si.customer_id = c.id 
    LEFT JOIN account_ledger al ON al.reference_number = si.invoice_number AND al.entry_type = 'invoice'
    WHERE si.id = ?
  ''', [id]);
    return r.isNotEmpty ? r.first : null;
  }
  Future<List<Map<String, dynamic>>> getSaleInvoiceItems(int invoiceId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT si.*, si.is_bonus, p.name as product_name, p.barcode, u.name as unit_name, u.symbol as unit_symbol
    FROM sales_items si
    JOIN products p ON si.product_id = p.id
    LEFT JOIN units u ON p.unit_id = u.id
    WHERE si.invoice_id = ?
  ''', [invoiceId]);
  }

  Future<int> insert(String table, Map<String, dynamic> data) async =>
      await (await database).insert(table, data);
  Future<List<Map<String, dynamic>>> queryAll(String table) async =>
      await (await database).query(table);
  Future<List<Map<String, dynamic>>> queryWhere(String table,
          {required String where, required List<dynamic> whereArgs}) async =>
      await (await database).query(table, where: where, whereArgs: whereArgs);
  Future<int> updateHelper(String table, Map<String, dynamic> data,
          {required int id}) async =>
      await (await database)
          .update(table, data, where: 'id = ?', whereArgs: [id]);
  Future<int> deleteHelper(String table, {required int id}) async =>
      await (await database).delete(table, where: 'id = ?', whereArgs: [id]);
  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<dynamic>? args]) async {
    final db = await database;
    return args != null && args.isNotEmpty
        ? await db.rawQuery(sql, args)
        : await db.rawQuery(sql);
  }

  Future<void> rawExecute(String sql) async =>
      await (await database).execute(sql);
  Future<void> close() async => (await database).close();

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final r = await (await database).rawQuery(
      'SELECT p.*, u.name as unit_name, u.symbol as unit_symbol, cur.symbol as currency_symbol FROM products p LEFT JOIN units u ON p.unit_id = u.id LEFT JOIN currencies cur ON p.currency_id = cur.id WHERE p.barcode = ?',
      [barcode],
    );
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> insertProductPrice(Map<String, dynamic> price) async =>
      await (await database).insert('product_prices', price);
  Future<List<Map<String, dynamic>>> getProductPrices(int productId) async =>
      await (await database).rawQuery(
        'SELECT pp.*, u.name as unit_name, u.symbol as unit_symbol FROM product_prices pp JOIN units u ON pp.unit_id = u.id WHERE pp.product_id = ? ORDER BY u.name ASC',
        [productId],
      );
  Future<int> updateProductPrice(int priceId, double newPrice) async =>
      await (await database).update('product_prices', {'price': newPrice},
          where: 'id = ?', whereArgs: [priceId]);
  Future<int> deleteProductPrice(int priceId) async => await (await database)
      .delete('product_prices', where: 'id = ?', whereArgs: [priceId]);

  Future<void> setDefaultProductPrice(int productId, int unitId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('product_prices', {'is_default': 0},
          where: 'product_id = ?', whereArgs: [productId]);
      await txn.update('product_prices', {'is_default': 1},
          where: 'product_id = ? AND unit_id = ?',
          whereArgs: [productId, unitId]);
    });
  }

  Future<int?> getProductPriceId(int productId, int unitId) async {
    final r = await (await database).query('product_prices',
        where: 'product_id = ? AND unit_id = ?',
        whereArgs: [productId, unitId]);
    return r.isNotEmpty ? r.first['id'] as int : null;
  }

  Future<int> insertProductUnitConversion(
          Map<String, dynamic> conversion) async =>
      await (await database).insert('product_unit_conversions', conversion);
  Future<List<Map<String, dynamic>>> getProductUnitConversions(
          int productId) async =>
      await (await database).rawQuery(
        'SELECT puc.*, u1.name as from_unit_name, u1.symbol as from_unit_symbol, u2.name as to_unit_name, u2.symbol as to_unit_symbol FROM product_unit_conversions puc JOIN units u1 ON puc.from_unit_id = u1.id JOIN units u2 ON puc.to_unit_id = u2.id WHERE puc.product_id = ? ORDER BY u1.name ASC',
        [productId],
      );
  Future<int> deleteProductUnitConversion(int id) async =>
      await (await database)
          .delete('product_unit_conversions', where: 'id = ?', whereArgs: [id]);

  Future<double> convertQuantity(
      int productId, int fromUnitId, int toUnitId, double quantity) async {
    final db = await database;
    if (fromUnitId == toUnitId) return quantity;
    var r = await db.query('product_unit_conversions',
        where: 'product_id = ? AND from_unit_id = ? AND to_unit_id = ?',
        whereArgs: [productId, fromUnitId, toUnitId]);
    if (r.isNotEmpty) return quantity * (r.first['quantity'] as double);
    r = await db.query('product_unit_conversions',
        where: 'product_id = ? AND from_unit_id = ? AND to_unit_id = ?',
        whereArgs: [productId, toUnitId, fromUnitId]);
    if (r.isNotEmpty) return quantity / (r.first['quantity'] as double);
    return quantity;
  }

  Future<int> insertWarehouse(Map<String, dynamic> warehouse) async =>
      await (await database).insert('warehouses', warehouse);
  Future<List<Map<String, dynamic>>> getAllWarehouses() async =>
      await (await database).query('warehouses', orderBy: 'name ASC');
  Future<Map<String, dynamic>?> getDefaultWarehouse() async {
    final r =
        await (await database).query('warehouses', where: 'is_default = 1');
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> updateWarehouse(int id, Map<String, dynamic> data) async =>
      await (await database)
          .update('warehouses', data, where: 'id = ?', whereArgs: [id]);
  Future<int> deleteWarehouse(int id) async => await (await database)
      .delete('warehouses', where: 'id = ?', whereArgs: [id]);

  Future<void> setDefaultWarehouse(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('warehouses', {'is_default': 0},
          where: 'is_default = 1');
      await txn.update('warehouses', {'is_default': 1},
          where: 'id = ?', whereArgs: [id]);
    });
  }

  // ==================== دوال Pagination ====================
  // 🚀 تم إصلاح مشكلة الهارد-كود (يقرأ الإجمالي من كل المستودعات بدلاً من مستودع رقم 1)
  Future<List<Map<String, dynamic>>> getProductsPaginated({
    required int page,
    int limit = 100,
    String? searchQuery,
  }) async {
    final offset = (page - 1) * limit;

    String sql = '''
    SELECT p.*, 
           COALESCE(pws.total_qty, 0) as current_stock,
           s.name as supplier_name, 
           sub.name as subcategory_name, 
           c.name as category_name, 
           g.name as group_name, 
           u.name as unit_name, u.symbol as unit_symbol, 
           cur.name as currency_name, cur.code as currency_code, cur.symbol as currency_symbol
    FROM products p
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    LEFT JOIN subcategories sub ON p.subcategory_id = sub.id
    LEFT JOIN categories c ON sub.category_id = c.id
    LEFT JOIN groups g ON c.group_id = g.id
    LEFT JOIN units u ON p.unit_id = u.id
    LEFT JOIN currencies cur ON p.currency_id = cur.id
    LEFT JOIN (SELECT product_id, SUM(quantity) as total_qty FROM product_warehouse_stock GROUP BY product_id) pws ON p.id = pws.product_id
  ''';

    List<dynamic> args = [];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql +=
          ' WHERE p.name LIKE ? OR p.barcode LIKE ? OR g.name LIKE ? OR c.name LIKE ? OR sub.name LIKE ?';
      final q = '%$searchQuery%';
      args = [q, q, q, q, q];
    }
    sql += ' ORDER BY p.id DESC LIMIT $limit OFFSET $offset';

    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<int> getProductsCount({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
        'SELECT COUNT(*) as count FROM products p LEFT JOIN subcategories sub ON p.subcategory_id = sub.id LEFT JOIN categories c ON sub.category_id = c.id LEFT JOIN groups g ON c.group_id = g.id WHERE p.name LIKE ? OR p.barcode LIKE ? OR g.name LIKE ? OR c.name LIKE ? OR sub.name LIKE ?',
        [q, q, q, q, q],
      ))
          .first['count'] as int);
    }
    return ((await (await database)
            .rawQuery('SELECT COUNT(*) as count FROM products'))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getSaleInvoicesPaginated({required int page, int limit = 50, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    String sql = '''
    SELECT si.*, c.name as customer_name, c.phone as customer_phone, 
    COALESCE(al.balance_before, 0) AS previous_balance 
    FROM sales_invoices si 
    LEFT JOIN customers c ON si.customer_id = c.id 
    LEFT JOIN account_ledger al ON al.reference_number = si.invoice_number AND al.entry_type = 'invoice'
    ''';
    List<dynamic> args = [];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql += ' WHERE si.invoice_number LIKE ? OR c.name LIKE ? OR c.phone LIKE ?';
      final q = '%$searchQuery%';
      args = [q, q, q];
    }
    sql += ' ORDER BY si.date DESC LIMIT $limit OFFSET $offset';
    return await (await database).rawQuery(sql, args);
  }  Future<int> getSaleInvoicesCount() async => ((await (await database)
          .rawQuery('SELECT COUNT(*) as count FROM sales_invoices'))
      .first['count'] as int);

  Future<List<Map<String, dynamic>>> getPurchaseInvoicesPaginated({required int page, int limit = 100, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    String sql = '''
    SELECT pi.*, s.name as supplier_name, s.phone as supplier_phone, 
    COALESCE(al.balance_before, 0) AS previous_balance 
    FROM purchase_invoices pi 
    LEFT JOIN suppliers s ON pi.supplier_id = s.id 
    LEFT JOIN account_ledger al ON al.reference_number = pi.invoice_number AND al.entry_type = 'invoice'
    ''';
    List<dynamic> args = [];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      sql += ' WHERE pi.invoice_number LIKE ? OR s.name LIKE ? OR s.phone LIKE ?';
      final q = '%$searchQuery%';
      args = [q, q, q];
    }
    sql += ' ORDER BY pi.date DESC LIMIT $limit OFFSET $offset';
    return await (await database).rawQuery(sql, args);
  }
  Future<int> getPurchaseInvoicesCount() async => ((await (await database)
          .rawQuery('SELECT COUNT(*) as count FROM purchase_invoices'))
      .first['count'] as int);

  Future<List<Map<String, dynamic>>> getCustomersPaginated(
      {required int page, int limit = 100, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT * FROM customers WHERE name LIKE ? OR phone LIKE ? OR address LIKE ? ORDER BY name ASC LIMIT $limit OFFSET $offset',
          [q, q, q]);
    }
    return await (await database).rawQuery(
        'SELECT * FROM customers ORDER BY name ASC LIMIT $limit OFFSET $offset');
  }

  Future<int> getCustomersCount({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM customers WHERE name LIKE ? OR phone LIKE ? OR address LIKE ?',
              [q, q, q]))
          .first['count'] as int);
    }
    return ((await (await database)
            .rawQuery('SELECT COUNT(*) as count FROM customers'))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getSuppliersPaginated(
      {required int page, int limit = 100, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT * FROM suppliers WHERE name LIKE ? OR phone LIKE ? OR address LIKE ? ORDER BY name ASC LIMIT $limit OFFSET $offset',
          [q, q, q]);
    }
    return await (await database).rawQuery(
        'SELECT * FROM suppliers ORDER BY name ASC LIMIT $limit OFFSET $offset');
  }

  Future<int> getSuppliersCount({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM suppliers WHERE name LIKE ? OR phone LIKE ? OR address LIKE ?',
              [q, q, q]))
          .first['count'] as int);
    }
    return ((await (await database)
            .rawQuery('SELECT COUNT(*) as count FROM suppliers'))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getUnitsPaginated(
      {required int page, int limit = 100, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT * FROM units WHERE name LIKE ? OR symbol LIKE ? ORDER BY name ASC LIMIT $limit OFFSET $offset',
          [q, q]);
    }
    return await (await database).rawQuery(
        'SELECT * FROM units ORDER BY name ASC LIMIT $limit OFFSET $offset');
  }

  Future<int> getUnitsCount({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM units WHERE name LIKE ? OR symbol LIKE ?',
              [q, q]))
          .first['count'] as int);
    }
    return ((await (await database)
            .rawQuery('SELECT COUNT(*) as count FROM units'))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getWarehousesPaginated(
      {required int page, int limit = 100, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT * FROM warehouses WHERE name LIKE ? OR location LIKE ? OR manager LIKE ? ORDER BY name ASC LIMIT $limit OFFSET $offset',
          [q, q, q]);
    }
    return await (await database).rawQuery(
        'SELECT * FROM warehouses ORDER BY name ASC LIMIT $limit OFFSET $offset');
  }

  Future<int> getWarehousesCount({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM warehouses WHERE name LIKE ? OR location LIKE ? OR manager LIKE ?',
              [q, q, q]))
          .first['count'] as int);
    }
    return ((await (await database)
            .rawQuery('SELECT COUNT(*) as count FROM warehouses'))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getGroupsPaginated(
      {required int page, int limit = 100, String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT * FROM groups WHERE name LIKE ? OR description LIKE ? ORDER BY name ASC LIMIT $limit OFFSET $offset',
          [q, q]);
    }
    return await (await database).rawQuery(
        'SELECT * FROM groups ORDER BY name ASC LIMIT $limit OFFSET $offset');
  }

  Future<int> getGroupsCount({String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM groups WHERE name LIKE ? OR description LIKE ?',
              [q, q]))
          .first['count'] as int);
    }
    return ((await (await database)
            .rawQuery('SELECT COUNT(*) as count FROM groups'))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getCategoriesPaginated(
      {required int groupId,
      required int page,
      int limit = 100,
      String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT c.*, g.name as group_name FROM categories c JOIN groups g ON c.group_id = g.id WHERE c.group_id = ? AND (c.name LIKE ? OR c.description LIKE ?) ORDER BY c.name ASC LIMIT $limit OFFSET $offset',
          [groupId, q, q]);
    }
    return await (await database).rawQuery(
        'SELECT c.*, g.name as group_name FROM categories c JOIN groups g ON c.group_id = g.id WHERE c.group_id = ? ORDER BY c.name ASC LIMIT $limit OFFSET $offset',
        [groupId]);
  }

  Future<int> getCategoriesCount(
      {required int groupId, String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM categories WHERE group_id = ? AND (name LIKE ? OR description LIKE ?)',
              [groupId, q, q]))
          .first['count'] as int);
    }
    return ((await (await database).rawQuery(
            'SELECT COUNT(*) as count FROM categories WHERE group_id = ?',
            [groupId]))
        .first['count'] as int);
  }

  Future<List<Map<String, dynamic>>> getSubcategoriesPaginated(
      {required int categoryId,
      required int page,
      int limit = 100,
      String? searchQuery}) async {
    final offset = (page - 1) * limit;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return await (await database).rawQuery(
          'SELECT s.*, c.name as category_name, g.name as group_name FROM subcategories s JOIN categories c ON s.category_id = c.id JOIN groups g ON c.group_id = g.id WHERE s.category_id = ? AND (s.name LIKE ? OR s.description LIKE ?) ORDER BY s.name ASC LIMIT $limit OFFSET $offset',
          [categoryId, q, q]);
    }
    return await (await database).rawQuery(
        'SELECT s.*, c.name as category_name, g.name as group_name FROM subcategories s JOIN categories c ON s.category_id = c.id JOIN groups g ON c.group_id = g.id WHERE s.category_id = ? ORDER BY s.name ASC LIMIT $limit OFFSET $offset',
        [categoryId]);
  }

  Future<int> getSubcategoriesCount(
      {required int categoryId, String? searchQuery}) async {
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      return ((await (await database).rawQuery(
              'SELECT COUNT(*) as count FROM subcategories WHERE category_id = ? AND (name LIKE ? OR description LIKE ?)',
              [categoryId, q, q]))
          .first['count'] as int);
    }
    return ((await (await database).rawQuery(
            'SELECT COUNT(*) as count FROM subcategories WHERE category_id = ?',
            [categoryId]))
        .first['count'] as int);
  }

  Future<void> deleteSaleInvoice(int invoiceId) async {
    await _deleteInvoiceWithChecks(invoiceId: invoiceId, isSale: true);
  }

  Future<void> deletePurchaseInvoice(int invoiceId) async {
    await _deleteInvoiceWithChecks(invoiceId: invoiceId, isSale: false);
  }

  Future<void> updateInvoiceBasicInfo({
    required int invoiceId,
    required bool isSale,
    required double paidAmount,
    required String paymentStatus,
    required String notes,
  }) async {
    final db = await database;
    final tableName = isSale ? 'sales_invoices' : 'purchase_invoices';
    await db.update(
      tableName,
      {
        'paid_amount': paidAmount,
        'payment_status': paymentStatus,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<String?> getLastSaleInvoiceNumber() async {
    final r = await (await database).rawQuery(
        'SELECT invoice_number FROM sales_invoices ORDER BY id DESC LIMIT 1');
    return r.isNotEmpty ? r.first['invoice_number'] as String : null;
  }

  Future<List<Map<String, dynamic>>> getSubcategoriesByCategoryWithCount(
          int categoryId) async =>
      await (await database).rawQuery(
        'SELECT s.*, c.name as category_name, g.name as group_name, COALESCE((SELECT COUNT(*) FROM products p WHERE p.subcategory_id = s.id), 0) as products_count FROM subcategories s JOIN categories c ON s.category_id = c.id JOIN groups g ON c.group_id = g.id WHERE s.category_id = ? ORDER BY s.name ASC',
        [categoryId],
      );

  Future<List<Map<String, dynamic>>> getAllSubcategoriesWithCount() async =>
      await (await database).rawQuery(
        'SELECT s.*, c.name as category_name, g.name as group_name, COALESCE((SELECT COUNT(*) FROM products p WHERE p.subcategory_id = s.id), 0) as products_count FROM subcategories s JOIN categories c ON s.category_id = c.id JOIN groups g ON c.group_id = g.id ORDER BY g.name ASC, c.name ASC, s.name ASC',
      );

  Future<List<Map<String, dynamic>>> getProductsBySubcategoryWithDetails(
          int subcategoryId) async =>
      await (await database).rawQuery(
        'SELECT p.*, u.name as unit_name, u.symbol as unit_symbol, cur.name as currency_name, cur.symbol as currency_symbol FROM products p LEFT JOIN units u ON p.unit_id = u.id LEFT JOIN currencies cur ON p.currency_id = cur.id WHERE p.subcategory_id = ? ORDER BY p.name ASC',
        [subcategoryId],
      );

  Future<void> _addToTreasuryLogic(
    DatabaseExecutor txn, {
    required int treasuryId,
    required String transactionType,
    required double amount,
    required String referenceType,
    required int? referenceId,
    required String notes,
  }) async {
    final treasury =
        await txn.query('treasuries', where: 'id = ?', whereArgs: [treasuryId]);
    if (treasury.isEmpty) throw Exception('الخزينة غير موجودة');
    double currentBalance = (treasury.first['balance'] as num).toDouble();
    double newBalance;
    if (transactionType == 'in') {
      newBalance = currentBalance + amount;
    } else {
      if (currentBalance < amount)
        throw Exception('الرصيد في الخزينة لا يكفي!');
      newBalance = currentBalance - amount;
    }
    newBalance = _round(newBalance);
    await txn.update('treasuries', {'balance': newBalance},
        where: 'id = ?', whereArgs: [treasuryId]);
    await txn.insert('treasury_transactions', {
      'treasury_id': treasuryId,
      'transaction_type': transactionType,
      'amount': _round(amount),
      'reference_type': referenceType,
      'reference_id': referenceId,
      'date': DateTime.now().toIso8601String(),
      'notes': notes,
    });
  }

  Future<void> addToLedger({
    required int personId,
    required String personType,
    required String entryType,
    required String? referenceNumber,
    required double debitAmount,
    required double creditAmount,
    required String? notes,
  }) async {
    await (await database).transaction((txn) async {
      await _addToLedgerLogic(
        txn,
        personId: personId,
        personType: personType,
        entryType: entryType,
        referenceNumber: referenceNumber,
        debitAmount: debitAmount,
        creditAmount: creditAmount,
        notes: notes,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getDebtors() async =>
      await (await database)
          .query('customers', where: 'balance > 0', orderBy: 'balance DESC');
  Future<List<Map<String, dynamic>>> getCreditors() async =>
      await (await database)
          .query('customers', where: 'balance < 0', orderBy: 'balance ASC');
  Future<List<Map<String, dynamic>>> getSupplierCreditors() async =>
      await (await database)
          .query('suppliers', where: 'balance > 0', orderBy: 'balance DESC');
  Future<List<Map<String, dynamic>>> getSupplierDebtors() async =>
      await (await database)
          .query('suppliers', where: 'balance < 0', orderBy: 'balance ASC');

  Future<List<Map<String, dynamic>>> getAccountLedger(
      int personId, String personType) async {
    final db = await database;
    return await db.query('account_ledger',
        where: 'person_id = ? AND person_type = ?',
        whereArgs: [personId, personType],
        orderBy: 'date ASC');
  }

  Future<void> settleAccount(int personId, String personType) async {
    final db = await database;
    await db.transaction((txn) async {
      final table = personType == 'customer' ? 'customers' : 'suppliers';
      final person =
          await txn.query(table, where: 'id = ?', whereArgs: [personId]);
      if (person.isEmpty) throw Exception('الحساب غير موجود');

      final double currentBalance =
          (person.first['balance'] as num?)?.toDouble() ?? 0.0;
      if (currentBalance.abs() < 0.01) return;

      final double settlementAmount = currentBalance.abs();
      final bool isCustomer = personType == 'customer';

      double debitAmount = 0;
      double creditAmount = 0;
      String treasuryTransactionType = '';
      String voucherType = '';
      String notes = '';

      if (isCustomer) {
        if (currentBalance > 0) {
          debitAmount = 0;
          creditAmount = settlementAmount;
          treasuryTransactionType = 'in';
          voucherType = 'receipt';
          notes = 'سداد كامل من العميل (تسوية حساب)';
          await _distributePaymentToInvoices(
              txn, personId, personType, settlementAmount);
        } else {
          debitAmount = settlementAmount;
          creditAmount = 0;
          treasuryTransactionType = 'out';
          voucherType = 'payment';
          notes = 'رد مبلغ للعميل (رصيد دائن)';
        }
      } else {
        if (currentBalance > 0) {
          debitAmount = 0;
          creditAmount = settlementAmount;
          treasuryTransactionType = 'out';
          voucherType = 'payment';
          notes = 'دفع كامل للمورد (تسوية حساب)';
          await _distributePaymentToInvoices(
              txn, personId, personType, settlementAmount);
        } else {
          debitAmount = settlementAmount;
          creditAmount = 0;
          treasuryTransactionType = 'in';
          voucherType = 'receipt';
          notes = 'تحصيل من المورد (تسوية حساب)';
        }
      }

      await _addToLedgerLogic(txn,
          personId: personId,
          personType: personType,
          entryType: 'settlement',
          referenceNumber: 'تسوية كاملة',
          debitAmount: debitAmount,
          creditAmount: creditAmount,
          notes: notes);

      final voucherNumber = await _generateInvoiceNumber(txn, 'STL');
      await txn.insert('financial_vouchers', {
        'voucher_number': voucherNumber,
        'category_id': 4,
        'treasury_id': 1,
        'type': voucherType,
        'amount': settlementAmount,
        'date': DateTime.now().toIso8601String(),
        'notes': notes,
      });

      await _addToTreasuryLogic(txn,
          treasuryId: 1,
          transactionType: treasuryTransactionType,
          amount: settlementAmount,
          referenceType: 'account_settlement',
          referenceId: personId,
          notes: notes);
    });
  }

  Future<void> _addToLedgerLogic(
    DatabaseExecutor txn, {
    required int personId,
    required String personType,
    required String entryType,
    required String? referenceNumber,
    required double debitAmount,
    required double creditAmount,
    required String? notes,
  }) async {
    final table = personType == 'customer' ? 'customers' : 'suppliers';
    final person =
        await txn.query(table, where: 'id = ?', whereArgs: [personId]);
    if (person.isEmpty) return;

    final double currentBalance =
        (person.first['balance'] as num?)?.toDouble() ?? 0.0;
    double newBalance;

    if (personType == 'customer') {
      newBalance = currentBalance + debitAmount - creditAmount;
    } else {
      newBalance = currentBalance + creditAmount - debitAmount;
    }
    newBalance = _round(newBalance);

    String status = newBalance > 0.01
        ? 'debtor'
        : (newBalance < -0.01 ? 'creditor' : 'settled');
    await txn.update(table, {'balance': newBalance, 'status': status},
        where: 'id = ?', whereArgs: [personId]);

    await txn.insert('account_ledger', {
      'person_id': personId,
      'person_type': personType,
      'entry_type': entryType,
      'reference_number': referenceNumber ?? '',
      'debit_amount': _round(debitAmount),
      'credit_amount': _round(creditAmount),
      'balance_before': _round(currentBalance),
      'balance_after': newBalance,
      'ledger_type': debitAmount > 0 ? 'debit' : 'credit',
      'is_settled': status == 'settled' ? 1 : 0,
      'notes': notes ?? '',
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> checkTreasuryBalance(double amount, {int? treasuryId}) async {
    final db = await database;
    List<Map<String, dynamic>> res;
    if (treasuryId != null) {
      res = await db.query('treasuries', where: 'id = ?', whereArgs: [treasuryId]);
    } else {
      res = await db.query('treasuries', orderBy: 'id ASC', limit: 1);
    }
    if (res.isEmpty) return false;
    final balance = (res.first['balance'] as num?)?.toDouble() ?? 0.0;
    return balance >= amount;
  }

  Future<List<Map<String, dynamic>>> getAllTreasuries() async =>
      await (await database).query('treasuries', orderBy: 'id ASC');

  Future<Map<String, dynamic>> processTreasuryTransaction({
    required int treasuryId,
    required String transactionType,
    required double amount,
    required String referenceType,
    required int? referenceId,
    required String notes,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {'success': false, 'error': null};
    try {
      await db.transaction((txn) async {
        final treasury = await txn
            .query('treasuries', where: 'id = ?', whereArgs: [treasuryId]);
        if (treasury.isEmpty) throw Exception('الخزينة غير موجودة');
        double currentBalance = (treasury.first['balance'] as num).toDouble();
        double newBalance;
        if (transactionType == 'in') {
          newBalance = currentBalance + amount;
        } else if (transactionType == 'out') {
          if (currentBalance < amount && referenceType == 'withdrawal')
            throw Exception('رصيد الخزينة لا يكفي لإتمام عملية السحب');
          newBalance = currentBalance - amount;
        } else {
          throw Exception('نوع الحركة غير صالح');
        }
        await txn.update('treasuries', {'balance': newBalance},
            where: 'id = ?', whereArgs: [treasuryId]);
        await txn.insert('treasury_transactions', {
          'treasury_id': treasuryId,
          'transaction_type': transactionType,
          'amount': amount,
          'reference_type': referenceType,
          'reference_id': referenceId,
          'date': DateTime.now().toIso8601String(),
          'notes': notes,
        });
        result['success'] = true;
      });
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getTreasuryStatement(
          int treasuryId) async =>
      await (await database).rawQuery(
          'SELECT * FROM treasury_transactions WHERE treasury_id = ? ORDER BY date DESC',
          [treasuryId]);

  Future<List<Map<String, dynamic>>> getFinancialCategories(
          String type) async =>
      await (await database).query('financial_categories',
          where: 'type = ?', whereArgs: [type], orderBy: 'name ASC');

  Future<int> insertFinancialCategory(String name, String type) async =>
      await (await database)
          .insert('financial_categories', {'name': name, 'type': type});

  Future<Map<String, dynamic>> createFinancialVoucher({
    required int categoryId,
    required int treasuryId,
    required String type,
    required double amount,
    String notes = '',
    String? referenceNumber,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {'success': false, 'error': null};
    try {
      await db.transaction((txn) async {
        final prefix = type == 'payment' ? 'PAY' : 'REC';
        final voucherNumber = referenceNumber ?? await _generateInvoiceNumber(txn, prefix);
        final date = DateTime.now().toIso8601String();
        final voucherId = await txn.insert('financial_vouchers', {
          'voucher_number': voucherNumber,
          'category_id': categoryId,
          'treasury_id': treasuryId,
          'type': type,
          'amount': amount,
          'date': date,
          'notes': notes,
        });
        final treasuryTransactionType = type == 'payment' ? 'out' : 'in';
        final refType =
            type == 'payment' ? 'expense_voucher' : 'income_voucher';
        await _addToTreasuryLogic(
          txn,
          treasuryId: treasuryId,
          transactionType: treasuryTransactionType,
          amount: amount,
          referenceType: refType,
          referenceId: voucherId,
          notes:
              'سند ${type == 'payment' ? 'صرف' : 'قبض'} رقم: $voucherNumber - $notes',
        );
        result = {'success': true, 'voucherId': voucherId, 'id': voucherId};
      });
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllFinancialVouchers() async =>
      await (await database).rawQuery(
          'SELECT v.*, c.name as category_name, t.name as treasury_name FROM financial_vouchers v JOIN financial_categories c ON v.category_id = c.id JOIN treasuries t ON v.treasury_id = t.id ORDER BY v.date DESC');

  Future<double> _consumeFIFO(
      DatabaseExecutor txn, int productId, double quantity) async {
    double totalCOGS = 0.0;
    double remainingToConsume = quantity;
    final batches = await txn.query(
      'purchase_batches',
      where: 'product_id = ? AND remaining_quantity > 0',
      whereArgs: [productId],
      orderBy: 'purchase_date ASC',
    );
    for (final batch in batches) {
      if (remainingToConsume <= 0) break;
      final double batchRemaining =
          (batch['remaining_quantity'] as num).toDouble();
      final double batchCost = (batch['cost_price'] as num).toDouble();
      final int batchId = batch['id'] as int;
      final double consumeFromBatch = remainingToConsume <= batchRemaining
          ? remainingToConsume
          : batchRemaining;
      totalCOGS += consumeFromBatch * batchCost;
      remainingToConsume -= consumeFromBatch;
      final double newRemaining = batchRemaining - consumeFromBatch;
      if (newRemaining <= 0) {
        await txn.update('purchase_batches', {'remaining_quantity': 0},
            where: 'id = ?', whereArgs: [batchId]);
      } else {
        await txn.update(
            'purchase_batches', {'remaining_quantity': newRemaining},
            where: 'id = ?', whereArgs: [batchId]);
      }
    }
    if (remainingToConsume > 0) {
      throw Exception(
          'خطأ في نظام FIFO: الدُفعات المتاحة لا تغطي الكمية المطلوبة. المتبقي: $remainingToConsume');
    }
    return _round(totalCOGS);
  }

  Future<List<Map<String, dynamic>>> getUpcomingDueInvoices(
      int daysBefore) async {
    final db = await database;
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: daysBefore));
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final futureStr = DateFormat('yyyy-MM-dd').format(futureDate);
    return await db.rawQuery('''
      SELECT si.*, c.name as customer_name, c.phone as customer_phone
      FROM sales_invoices si
      LEFT JOIN customers c ON si.customer_id = c.id
      WHERE si.due_date IS NOT NULL AND si.due_date != ''
        AND si.payment_status != 'كامل'
        AND si.paid_amount < si.total_amount
        AND date(si.due_date) >= date(?) AND date(si.due_date) <= date(?)
      ORDER BY date(si.due_date) ASC
    ''', [todayStr, futureStr]);
  }

  Future<Map<String, dynamic>> transferProductFixed({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required num quantity,
    String? notes,
  }) async {
    final db = await database;
    final double qty = quantity.toDouble();
    Map<String, dynamic> result = {'success': false, 'error': null};
    try {
      await db.transaction((txn) async {
        final fromRes = await txn.rawUpdate(
          'UPDATE product_warehouse_stock SET quantity = quantity - ? WHERE product_id = ? AND warehouse_id = ? AND quantity >= ?',
          [qty, productId, fromWarehouseId, qty],
        );
        if (fromRes == 0)
          throw Exception('الكمية غير متوفرة في المستودع المصدر');
        final toExists = await txn.query(
          'product_warehouse_stock',
          where: 'product_id = ? AND warehouse_id = ?',
          whereArgs: [productId, toWarehouseId],
        );
        if (toExists.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE product_warehouse_stock SET quantity = quantity + ? WHERE product_id = ? AND warehouse_id = ?',
            [qty, productId, toWarehouseId],
          );
        } else {
          await txn.insert('product_warehouse_stock', {
            'product_id': productId,
            'warehouse_id': toWarehouseId,
            'quantity': qty,
          });
        }
        await txn.insert('warehouse_movements', {
          'product_id': productId,
          'from_warehouse_id': fromWarehouseId,
          'to_warehouse_id': toWarehouseId,
          'quantity': qty,
          'type': 'transfer',
          'date': DateTime.now().toIso8601String(),
          'notes': notes,
        });
        result['success'] = true;
      });
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  Future<double> _getStockInWarehouse(
      DatabaseExecutor txn, int productId, int warehouseId) async {
    final result = await txn.query('product_warehouse_stock',
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId]);
    return result.isEmpty ? 0 : (result.first['quantity'] as num).toDouble();
  }

  Future<void> _addStockToWarehouse(DatabaseExecutor txn, int productId,
      int warehouseId, double quantity) async {
    final existing = await txn.query('product_warehouse_stock',
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId]);
    if (existing.isNotEmpty) {
      await txn.rawUpdate(
          'UPDATE product_warehouse_stock SET quantity = quantity + ? WHERE product_id = ? AND warehouse_id = ?',
          [quantity, productId, warehouseId]);
    } else {
      await txn.insert('product_warehouse_stock', {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity
      });
    }
  }

  Future<void> _deductStockFromWarehouse(DatabaseExecutor txn, int productId,
      int warehouseId, double quantity) async {
    final current = await _getStockInWarehouse(txn, productId, warehouseId);
    if (current < quantity)
      throw Exception(
          'الكمية غير متوفرة للمنتج $productId في المستودع $warehouseId');
    await txn.rawUpdate(
        'UPDATE product_warehouse_stock SET quantity = quantity - ? WHERE product_id = ? AND warehouse_id = ?',
        [quantity, productId, warehouseId]);
  }

  Future<double> getProductStockInWarehouse(
      int productId, int warehouseId) async {
    final db = await database;
    final result = await db.query('product_warehouse_stock',
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId]);
    if (result.isNotEmpty) return (result.first['quantity'] as num).toDouble();
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> getProductsWithStockForWarehouse(
      int warehouseId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT p.*, 
           pws.quantity as current_stock,
           s.name as supplier_name, 
           sub.name as subcategory_name, 
           c.name as category_name, 
           g.name as group_name, 
           u.name as unit_name, u.symbol as unit_symbol, 
           cur.name as currency_name, cur.code as currency_code, cur.symbol as currency_symbol
    FROM products p
    INNER JOIN product_warehouse_stock pws ON p.id = pws.product_id AND pws.warehouse_id = ?
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    LEFT JOIN subcategories sub ON p.subcategory_id = sub.id
    LEFT JOIN categories c ON sub.category_id = c.id
    LEFT JOIN groups g ON c.group_id = g.id
    LEFT JOIN units u ON p.unit_id = u.id
    LEFT JOIN currencies cur ON p.currency_id = cur.id
    ORDER BY g.name ASC, c.name ASC, sub.name ASC, p.name ASC
  ''', [warehouseId]);
  }

  Future<Map<String, dynamic>?> getSaleInvoiceByNumber(String invoiceNumber) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT si.*, c.name as customer_name, c.phone as customer_phone, c.address as customer_address, 
    COALESCE(al.balance_before, 0) AS previous_balance 
    FROM sales_invoices si 
    LEFT JOIN customers c ON si.customer_id = c.id 
    LEFT JOIN account_ledger al ON al.reference_number = si.invoice_number AND al.entry_type = 'invoice'
    WHERE si.invoice_number = ?
  ''', [invoiceNumber]);
    if (result.isEmpty) return null;
    final invoice = Map<String, dynamic>.from(result.first);
    final items = await db.rawQuery(
        'SELECT si.*, p.name as product_name, p.cost_price, p.current_stock FROM sales_items si JOIN products p ON si.product_id = p.id WHERE si.invoice_id = ?',
        [invoice['id']]);
    invoice['items'] = items;
    return invoice;
  }

  Future<Map<String, dynamic>?> getPurchaseInvoiceByNumber(String invoiceNumber) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT pi.*, s.name as supplier_name, s.phone as supplier_phone, s.address as supplier_address, 
    COALESCE(al.balance_before, 0) AS previous_balance 
    FROM purchase_invoices pi 
    LEFT JOIN suppliers s ON pi.supplier_id = s.id 
    LEFT JOIN account_ledger al ON al.reference_number = pi.invoice_number AND al.entry_type = 'invoice'
    WHERE pi.invoice_number = ?
  ''', [invoiceNumber]);
    if (result.isEmpty) return null;
    final invoice = Map<String, dynamic>.from(result.first);
    final items = await db.rawQuery(
        'SELECT pi.*, p.name as product_name, p.current_stock FROM purchase_items pi JOIN products p ON pi.product_id = p.id WHERE pi.invoice_id = ?',
        [invoice['id']]);
    invoice['items'] = items;
    return invoice;
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final result = await (await database)
        .query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSalesReturns() async {
    final db = await database;
    return await db.rawQuery(
        'SELECT sr.*, c.name as customer_name FROM sales_returns sr LEFT JOIN customers c ON sr.customer_id = c.id ORDER BY sr.return_date DESC');
  }

  Future<List<Map<String, dynamic>>> getAllPurchaseReturns() async {
    final db = await database;
    return await db.rawQuery(
        'SELECT pr.*, s.name as supplier_name FROM purchase_returns pr LEFT JOIN suppliers s ON pr.supplier_id = s.id ORDER BY pr.return_date DESC');
  }

  Future<List<Map<String, dynamic>>> getSalesReturnItems(int returnId) async {
    final db = await database;
    return await db.rawQuery(
        'SELECT sri.*, p.name as product_name, u.name as unit_name, u.symbol as unit_symbol FROM sales_return_items sri JOIN products p ON sri.product_id = p.id LEFT JOIN units u ON p.unit_id = u.id WHERE sri.return_id = ?',
        [returnId]);
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturnItems(
      int returnId) async {
    final db = await database;
    return await db.rawQuery(
        'SELECT pri.*, p.name as product_name, u.name as unit_name, u.symbol as unit_symbol FROM purchase_return_items pri JOIN products p ON pri.product_id = p.id LEFT JOIN units u ON p.unit_id = u.id WHERE pri.return_id = ?',
        [returnId]);
  }

  Future<Map<String, dynamic>> getFullSalesReturnData(int returnId) async {
    final db = await database;
    final returnData =
        await db.query('sales_returns', where: 'id = ?', whereArgs: [returnId]);
    if (returnData.isEmpty) throw Exception('المرتجع غير موجود');
    final invoice = Map<String, dynamic>.from(returnData.first);
    if (invoice['customer_id'] != null && invoice['customer_id'] > 0) {
      final customer = await db.query('customers',
          where: 'id = ?', whereArgs: [invoice['customer_id']]);
      if (customer.isNotEmpty) {
        invoice['customer_name'] =
            customer.first['name']?.toString() ?? 'عميل غير محدد';
        invoice['customer_phone'] = customer.first['phone']?.toString() ?? '';
      } else {
        invoice['customer_name'] = 'عميل غير محدد';
        invoice['customer_phone'] = '';
      }
    } else {
      invoice['customer_name'] = 'عميل غير محدد';
      invoice['customer_phone'] = '';
    }
    final items = await db.rawQuery(
        'SELECT sri.*, p.name as product_name, u.name as unit_name, u.symbol as unit_symbol FROM sales_return_items sri JOIN products p ON sri.product_id = p.id LEFT JOIN units u ON p.unit_id = u.id WHERE sri.return_id = ?',
        [returnId]);
    invoice['items'] = List<Map<String, dynamic>>.from(items);
    return invoice;
  }

  Future<Map<String, dynamic>> getFullPurchaseReturnData(int returnId) async {
    final db = await database;
    final returnData = await db
        .query('purchase_returns', where: 'id = ?', whereArgs: [returnId]);
    if (returnData.isEmpty) throw Exception('المرتجع غير موجود');
    final invoice = Map<String, dynamic>.from(returnData.first);
    if (invoice['supplier_id'] != null && invoice['supplier_id'] > 0) {
      final supplier = await db.query('suppliers',
          where: 'id = ?', whereArgs: [invoice['supplier_id']]);
      if (supplier.isNotEmpty) {
        invoice['supplier_name'] =
            supplier.first['name']?.toString() ?? 'غير محدد';
        invoice['supplier_phone'] = supplier.first['phone']?.toString() ?? '';
        invoice['supplier_address'] =
            supplier.first['address']?.toString() ?? '';
        invoice['supplier'] = supplier.first;
      } else {
        invoice['supplier_name'] = 'غير محدد';
        invoice['supplier_phone'] = '';
        invoice['supplier_address'] = '';
      }
    } else {
      invoice['supplier_name'] = 'غير محدد';
      invoice['supplier_phone'] = '';
      invoice['supplier_address'] = '';
    }
    final items = await db.rawQuery(
        'SELECT pri.*, p.name as product_name, u.name as unit_name, u.symbol as unit_symbol FROM purchase_return_items pri JOIN products p ON pri.product_id = p.id LEFT JOIN units u ON p.unit_id = u.id WHERE pri.return_id = ?',
        [returnId]);
    invoice['items'] = List<Map<String, dynamic>>.from(items);
    return invoice;
  }

  Future<List<Map<String, dynamic>>> getSalesReturnsPaginated(
      {required int page, int limit = 50}) async {
    final offset = (page - 1) * limit;
    final db = await database;
    return await db.rawQuery(
        'SELECT sr.*, c.name as customer_name FROM sales_returns sr LEFT JOIN customers c ON sr.customer_id = c.id ORDER BY sr.return_date DESC LIMIT $limit OFFSET $offset');
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturnsPaginated(
      {required int page, int limit = 50}) async {
    final offset = (page - 1) * limit;
    final db = await database;
    return await db.rawQuery(
        'SELECT pr.*, s.name as supplier_name FROM purchase_returns pr LEFT JOIN suppliers s ON pr.supplier_id = s.id ORDER BY pr.return_date DESC LIMIT $limit OFFSET $offset');
  }

  Future<int> insertTask(Map<String, dynamic> task) async =>
      await (await database).insert('tasks', task);
  Future<int> updateTask(int id, Map<String, dynamic> data) async =>
      await (await database)
          .update('tasks', data, where: 'id = ?', whereArgs: [id]);
  Future<int> deleteTask(int id) async =>
      await (await database).delete('tasks', where: 'id = ?', whereArgs: [id]);
  Future<List<Map<String, dynamic>>> getTasksByStatus(int status) async =>
      await (await database).query('tasks',
          where: 'status = ?', whereArgs: [status], orderBy: 'created_at DESC');

  Future<List<Map<String, dynamic>>> getOverdueTasks() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await (await database).rawQuery(
        'SELECT * FROM tasks WHERE due_date IS NOT NULL AND date(due_date) < date(?) AND status != 2 ORDER BY due_date ASC',
        [today]);
  }

  Future<List<Map<String, dynamic>>> getTasksByRelatedItem(
          String relatedType, int relatedId) async =>
      await (await database).query('tasks',
          where: 'related_type = ? AND related_id = ?',
          whereArgs: [relatedType, relatedId],
          orderBy: 'created_at DESC');

  Future<Map<String, dynamic>?> searchProductByAnyBarcode(
      String barcode) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT p.*, u.name as unit_name, u.symbol as unit_symbol, cur.symbol as currency_symbol FROM products p LEFT JOIN units u ON p.unit_id = u.id LEFT JOIN currencies cur ON p.currency_id = cur.id WHERE p.barcode = ? OR p.second_barcode = ?',
      [barcode, barcode],
    );
    return r.isNotEmpty ? r.first : null;
  }

  // ==================== دوال نظام الولاء ====================
  Future<Map<String, dynamic>?> getLoyaltyPoints(int customerId) async {
    final db = await database;
    final results = await db.query('loyalty_points',
        where: 'customer_id = ?', whereArgs: [customerId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> addLoyaltyPoints(int customerId, double points,
      {int? invoiceId}) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query('loyalty_points',
          where: 'customer_id = ?', whereArgs: [customerId]);
      double totalBefore = 0;
      double availableBefore = 0;
      if (existing.isNotEmpty) {
        totalBefore = (existing.first['total_points'] as num).toDouble();
        availableBefore =
            (existing.first['available_points'] as num).toDouble();
        await txn.update(
            'loyalty_points',
            {
              'total_points': totalBefore + points,
              'available_points': availableBefore + points,
            },
            where: 'customer_id = ?',
            whereArgs: [customerId]);
      } else {
        await txn.insert('loyalty_points', {
          'customer_id': customerId,
          'total_points': points,
          'used_points': 0,
          'available_points': points,
        });
      }
      await txn.insert('loyalty_history', {
        'customer_id': customerId,
        'operation_type': 'earn_points',
        'value': points,
        'points_before': availableBefore,
        'points_after': availableBefore + points,
        'reference_id': invoiceId,
        'reference_type': 'invoice',
        'notes': 'نقاط مكتسبة من فاتورة',
        'date': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> updateCustomerLoyaltyStats(
      int customerId, double invoiceAmount) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
          'UPDATE customers SET total_purchases = total_purchases + ?, purchase_count = purchase_count + 1 WHERE id = ?',
          [invoiceAmount, customerId]);
    });
  }

  Future<Map<String, dynamic>?> getCustomerLoyaltyInfo(int customerId) async {
    final db = await database;
    final results = await db.rawQuery(
        'SELECT c.id, c.name, c.total_purchases, c.purchase_count, c.current_level, lp.available_points FROM customers c LEFT JOIN loyalty_points lp ON c.id = lp.customer_id WHERE c.id = ?',
        [customerId]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getNextLevel(
      double currentTotalPurchases) async {
    final db = await database;
    final results = await db.rawQuery(
        'SELECT * FROM customer_levels WHERE min_total_purchases > ? ORDER BY min_total_purchases ASC LIMIT 1',
        [currentTotalPurchases]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllLevels() async =>
      await (await database)
          .query('customer_levels', orderBy: 'min_total_purchases ASC');
  Future<List<Map<String, dynamic>>> getAvailableRewards() async =>
      await (await database).query('loyalty_rewards', where: 'is_active = 1');

  Future<Map<String, dynamic>> getLoyaltySettings() async {
    final db = await database;
    final settings = await db.query('loyalty_settings');
    Map<String, dynamic> result = {};
    for (var s in settings) {
      result[s['key'] as String] = s['value'];
    }
    return result;
  }

  Future<void> updateCustomerLevel(int customerId, String newLevel) async {
    final db = await database;
    final oldLevelResult = await db.rawQuery(
        'SELECT current_level FROM customers WHERE id = ?', [customerId]);
    final oldLevel = oldLevelResult.isNotEmpty
        ? oldLevelResult.first['current_level'] as String
        : 'Bronze';
    if (oldLevel != newLevel) {
      await db.rawUpdate('UPDATE customers SET current_level = ? WHERE id = ?',
          [newLevel, customerId]);
      await db.insert('loyalty_history', {
        'customer_id': customerId,
        'operation_type': 'level_up',
        'value': 0,
        'points_before': 0,
        'points_after': 0,
        'reference_id': null,
        'reference_type': null,
        'notes': 'تمت الترقية من $oldLevel إلى $newLevel',
        'date': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> deductLoyaltyPoints(int customerId, double points,
      {String? notes}) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query('loyalty_points',
          where: 'customer_id = ?', whereArgs: [customerId]);
      if (existing.isEmpty) throw Exception('لا توجد نقاط');
      final totalBefore = (existing.first['total_points'] as num).toDouble();
      final availableBefore =
          (existing.first['available_points'] as num).toDouble();
      if (availableBefore < points) throw Exception('النقاط غير كافية');
      await txn.update(
          'loyalty_points',
          {
            'used_points':
                (existing.first['used_points'] as num).toDouble() + points,
            'available_points': availableBefore - points,
          },
          where: 'customer_id = ?',
          whereArgs: [customerId]);
      await txn.insert('loyalty_history', {
        'customer_id': customerId,
        'operation_type': 'redeem_points',
        'value': points,
        'points_before': availableBefore,
        'points_after': availableBefore - points,
        'reference_id': null,
        'reference_type': null,
        'notes': notes ?? 'استبدال نقاط',
        'date': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> recordRewardRedemption(int customerId, int rewardId,
      {int? invoiceId}) async {
    final db = await database;
    await db.insert('loyalty_history', {
      'customer_id': customerId,
      'operation_type': 'reward_granted',
      'value': 0,
      'points_before': 0,
      'points_after': 0,
      'reference_id': rewardId,
      'reference_type': 'reward',
      'notes': 'تم منح مكافأة',
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _distributePaymentToInvoices(DatabaseExecutor txn, int personId,
      String personType, double amountPaid) async {
    if (amountPaid <= 0) return;
    double remainingToDistribute = amountPaid;
    final String tableName =
        personType == 'customer' ? 'sales_invoices' : 'purchase_invoices';
    final String personColumn =
        personType == 'customer' ? 'customer_id' : 'supplier_id';
    final invoices = await txn.query(tableName,
        where: "$personColumn = ? AND payment_status != 'كامل'",
        whereArgs: [personId],
        orderBy: 'date ASC');

    for (var invoice in invoices) {
      if (remainingToDistribute <= 0) break;
      final int invoiceId = invoice['id'] as int;
      final double totalAmount = (invoice['total_amount'] as num).toDouble();
      final double currentPaid = (invoice['paid_amount'] as num).toDouble();
      final double remainingOnInvoice = totalAmount - currentPaid;
      if (remainingOnInvoice <= 0) continue;

      if (remainingToDistribute >= remainingOnInvoice) {
        await txn.update(
            tableName, {'paid_amount': totalAmount, 'payment_status': 'كامل'},
            where: 'id = ?', whereArgs: [invoiceId]);
        remainingToDistribute -= remainingOnInvoice;
      } else {
        await txn.update(
            tableName,
            {
              'paid_amount': currentPaid + remainingToDistribute,
              'payment_status': 'جزئي'
            },
            where: 'id = ?', whereArgs: [invoiceId]);
        remainingToDistribute = 0;
      }
    }
  }

  // 💡 تم إضافة 'invoice' و 'return' لتظهر القيود المدينة والدائنة بشكل متكامل
  Future<List<Map<String, dynamic>>> getRelatedPayments(
      int personId, String personType, String invoiceDate) async {
    final dbClient = await database;
    return await dbClient.query('account_ledger',
        where:
        "person_id = ? AND person_type = ? AND entry_type IN ('invoice', 'return', 'settlement', 'payment') AND date(date) >= date(?)",
        whereArgs: [personId, personType, invoiceDate],
        orderBy: 'date ASC');
  }

  Future<bool> confirmDamagedProductReceipt(int damagedRecordId) async {
    final db = await database;
    int count = await db.update('damaged_products', {'status': 'تم الاستلام'},
        where: 'id = ? AND status = ?',
        whereArgs: [damagedRecordId, 'لم يتم الاستلام']);
    return count > 0;
  }

  Future<Map<String, dynamic>> moveProductToDamaged({
    required int productId,
    required int warehouseId,
    required double quantity,
    required String reason,
    required int? userId,
    String notes = '',
  }) async {
    final db = await database;
    Map<String, dynamic> result = {'success': false, 'message': ''};

    try {
      await db.transaction((txn) async {
        final stockRes = await txn.query('product_warehouse_stock',
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [productId, warehouseId]);
        if (stockRes.isEmpty) throw Exception('المنتج غير موجود في المستودع.');
        final currentQty = (stockRes.first['quantity'] as num).toDouble();
        if (currentQty < quantity)
          throw Exception('الكمية المتاحة أقل من المراد نقلها.');

        final productRes = await txn
            .query('products', where: 'id = ?', whereArgs: [productId]);
        final double unitCost =
            productRes.isNotEmpty && productRes.first['cost_price'] != null
                ? (productRes.first['cost_price'] as num).toDouble()
                : 0.0;
        final double totalLoss = unitCost * quantity;

        await txn.rawUpdate(
            'UPDATE product_warehouse_stock SET quantity = quantity - ? WHERE product_id = ? AND warehouse_id = ?',
            [quantity, productId, warehouseId]);
        await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
            [quantity, productId]);

        final String invoiceNo = await _generateDamagedInvoiceNumber(txn);

        int damagedId = await txn.insert('damaged_products', {
          'invoice_number': invoiceNo,
          'product_id': productId,
          'warehouse_id': warehouseId,
          'quantity': quantity,
          'unit_cost': unitCost,
          'total_loss': totalLoss,
          'reason': reason,
          'status': 'لم يتم الاستلام',
          'move_date': DateTime.now().toIso8601String(),
          'moved_by': userId,
          'notes': notes,
        });

        await txn.insert('stock_movements', {
          'product_id': productId,
          'type': 'out',
          'quantity': quantity,
          'reference_id': damagedId,
          'date': DateTime.now().toIso8601String(),
        });

        result['success'] = true;
        result['message'] = 'تم الإصدار برقم ($invoiceNo)';
      });
    } catch (e) {
      result['success'] = false;
      result['message'] = e.toString().replaceAll('Exception: ', '');
    }
    return result;
  }

  Future<bool> returnDamagedToInventory(int damagedId) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final recordRes = await txn
            .query('damaged_products', where: 'id = ?', whereArgs: [damagedId]);
        if (recordRes.isEmpty) throw Exception('السجل غير موجود');

        final record = recordRes.first;
        final int productId = record['product_id'] as int;
        final int warehouseId = record['warehouse_id'] as int;
        final double quantity = (record['quantity'] as num).toDouble();

        final stockRes = await txn.query('product_warehouse_stock',
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [productId, warehouseId]);
        if (stockRes.isNotEmpty) {
          await txn.rawUpdate(
              'UPDATE product_warehouse_stock SET quantity = quantity + ? WHERE product_id = ? AND warehouse_id = ?',
              [quantity, productId, warehouseId]);
        } else {
          await txn.insert('product_warehouse_stock', {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'quantity': quantity
          });
        }

        await txn.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [quantity, productId]);

        await txn.insert('stock_movements', {
          'product_id': productId,
          'type': 'in',
          'quantity': quantity,
          'reference_id': damagedId,
          'date': DateTime.now().toIso8601String(),
        });

        await txn.delete('damaged_products',
            where: 'id = ?', whereArgs: [damagedId]);
      });
      return true;
    } catch (e) {
      debugPrint('خطأ في إرجاع المخزون: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDamagedProductsLog() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.*, 
             p.name as product_name, p.barcode,
             IFNULL(p.expiry_date, 'غير محدد') as expiry_date, 
             w.name as warehouse_name,
             COALESCE(u.full_name, u.username, 'غير محدد') as moved_by_name
      FROM damaged_products d
      JOIN products p ON d.product_id = p.id
      JOIN warehouses w ON d.warehouse_id = w.id
      LEFT JOIN users u ON d.moved_by = u.id
      ORDER BY d.move_date DESC
    ''');
  }
  Future<void> autoGenerateInvoiceDueTasks({int daysBefore = 3}) async {
    final db = await database;
    final now = DateTime.now();

    await _processInvoiceTasks(
      db: db,
      now: now,
      daysBefore: daysBefore,
      tableName: 'sales_invoices',
      personColumn: 'customer_name',
      personLabel: 'العميل',
      relatedType: 'sales_invoice',
      titlePrefix: '💰 تحصيل فاتورة مبيعات',
      amountLabel: 'المبلغ المتبقي للتحصيل',
    );

    await _processInvoiceTasks(
      db: db,
      now: now,
      daysBefore: daysBefore,
      tableName: 'purchase_invoices',
      personColumn: 'supplier_name',
      personLabel: 'المورد',
      relatedType: 'purchase_invoice',
      titlePrefix: '💸 سداد فاتورة مشتريات',
      amountLabel: 'المبلغ المستحق للدفع',
    );
  }

  // ==================== معالجة مهام الفواتير المستحقة (محسّن) ====================
  Future<void> _processInvoiceTasks({
    required Database db, // ✅ تم التغيير من DatabaseExecutor إلى Database
    required DateTime now,
    required int daysBefore,
    required String tableName,
    required String personColumn,
    required String personLabel,
    required String relatedType,
    required String titlePrefix,
    required String amountLabel,
  }) async {
    // 1. جلب جميع الفواتير التي لها تاريخ استحقاق ولم تُسدّد بالكامل
    final upcomingInvoices = await db.rawQuery('''
    SELECT * FROM $tableName 
    WHERE due_date IS NOT NULL AND due_date != ''
      AND payment_status != 'كامل'
      AND paid_amount < total_amount
  ''');

    // 2. قائمة لتجميع المهام الجديدة
    List<Map<String, dynamic>> tasksToInsert = [];

    for (var invoice in upcomingInvoices) {
      final String? dueDateStr = invoice['due_date'] as String?;
      if (dueDateStr == null || dueDateStr.trim().isEmpty) continue;

      try {
        final dueDate = DateTime.parse(dueDateStr);
        // نتحقق مما إذا كان تاريخ الاستحقاق خلال المدة المحددة (أيام)
        if (dueDate.difference(now).inDays <= daysBefore) {
          final int invoiceId = invoice['id'] as int;
          final String invNum = invoice['invoice_number'] as String;
          final String personName =
              (invoice[personColumn] as String?) ?? '$personLabel غير محدد';
          final double remaining = (invoice['total_amount'] as num).toDouble() -
              (invoice['paid_amount'] as num).toDouble();

          // نتحقق مما إذا كانت هناك مهمة سابقة غير مكتملة لهذه الفاتورة
          final existing = await db.query(
            'tasks',
            where: 'related_type = ? AND related_id = ? AND status != 2',
            whereArgs: [relatedType, invoiceId],
          );

          if (existing.isEmpty) {
            // نضيف المهمة إلى القائمة (بدون إدراج فوري)
            tasksToInsert.add({
              'title': '$titlePrefix: $invNum',
              'description':
                  '$personLabel: $personName\n$amountLabel: ${_round(remaining)} ريال\nتاريخ الاستحقاق: ${dueDateStr.substring(0, 10)}',
              'task_type': 1,
              'priority': 2,
              'status': 0,
              'created_at': DateTime.now().toIso8601String(),
              'due_date': dueDateStr,
              'related_type': relatedType,
              'related_id': invoiceId,
            });
          }
        }
      } catch (e) {
        // نتجاوز الأخطاء في تنسيق التاريخ ولا نوقف العملية
        debugPrint('خطأ في معالجة تاريخ الفاتورة: $e');
      }
    }

    // 3. إدراج جميع المهام دفعة واحدة في معاملة واحدة
    if (tasksToInsert.isNotEmpty) {
      await db.transaction((txn) async {
        var batch = txn.batch();
        for (var task in tasksToInsert) {
          batch.insert('tasks', task);
        }
        await batch.commit(noResult: true);
      });
      debugPrint(
          '✅ تم إنشاء ${tasksToInsert.length} مهمة تذكيرية للفواتير دفعة واحدة.');
    }
  }

  Future<Map<String, dynamic>> recordInvoicePaymentFromTask({
    required int taskId,
    required int invoiceId,
    required String invoiceType,
    required double amountPaid,
    String? newDueDate,
  }) async {
    final db = await database;
    Map<String, dynamic> result = {'success': false, 'message': ''};

    try {
      await db.transaction((txn) async {
        final String table = invoiceType == 'sales_invoice' ? 'sales_invoices' : 'purchase_invoices';
        final String prefix = invoiceType == 'sales_invoice' ? 'REC' : 'PAY';
        final String voucherType = invoiceType == 'sales_invoice' ? 'receipt' : 'payment';
        final String treasuryType = invoiceType == 'sales_invoice' ? 'in' : 'out';

        // 1. جلب الفاتورة (للتحقق من المبلغ الإجمالي)
        final invRes = await txn.query(table, where: 'id = ?', whereArgs: [invoiceId]);
        if (invRes.isEmpty) throw Exception('الفاتورة غير موجودة');
        final invoice = invRes.first;
        final double total = (invoice['total_amount'] as num).toDouble();
        final double oldPaid = (invoice['paid_amount'] as num).toDouble();
        final double newPaid = _round(oldPaid + amountPaid);
        final String invNum = invoice['invoice_number'] as String;

        if (newPaid > total) throw Exception('المبلغ المدفوع أكبر من المتبقي!');

        // 2. تحديث الفاتورة (Cache) - عملية خفيفة لا تمس بنية الفاتورة
        final String status = newPaid >= total ? 'كامل' : 'جزئي';
        await txn.update(
          table,
          {
            'paid_amount': newPaid,
            'payment_status': status,
            'due_date': (status == 'كامل' ? '' : (newDueDate ?? invoice['due_date'])),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // 3. إنشاء سند مالي مستقل
        final voucherNumber = await _generateInvoiceNumber(txn, prefix);
        final String personName = invoiceType == 'sales_invoice'
            ? (invoice['customer_name'] as String? ?? 'عميل غير محدد')
            : (invoice['supplier_name'] as String? ?? 'مورد غير محدد');
        final int? personId = invoiceType == 'sales_invoice'
            ? invoice['customer_id'] as int?
            : invoice['supplier_id'] as int?;

        final int voucherId = await txn.insert('financial_vouchers', {
          'voucher_number': voucherNumber,
          'category_id': 4, // استخدام التصنيف الافتراضي 'تسوية حسابات'
          'treasury_id': 1,
          'type': voucherType,
          'amount': _round(amountPaid),
          'date': DateTime.now().toIso8601String(),
          'notes': 'دفعة من مهمة الفاتورة $invNum - $personName',
        });

        // 4. تسجيل حركة الخزينة
        await _addToTreasuryLogic(
          txn,
          treasuryId: 1,
          transactionType: treasuryType,
          amount: _round(amountPaid),
          referenceType: invoiceType,
          referenceId: invoiceId,
          notes: 'سند ${voucherType == 'receipt' ? 'قبض' : 'صرف'} رقم $voucherNumber للفاتورة $invNum',
        );

        // 5. تسجيل القيد في دفتر الأستاذ (المرجع التاريخي الثابت)
        if (personId != null) {
          await _addToLedgerLogic(
            txn,
            personId: personId,
            personType: invoiceType == 'sales_invoice' ? 'customer' : 'supplier',
            entryType: 'payment',
            referenceNumber: voucherNumber, // ✅ رقم السند يظهر في كشف الحساب
            debitAmount: invoiceType == 'sales_invoice' ? 0 : _round(amountPaid),
            creditAmount: invoiceType == 'sales_invoice' ? _round(amountPaid) : 0,
            notes: 'سداد بقيمة ${_round(amountPaid)} ريال عن فاتورة رقم $invNum',
          );
        }

        // 6. تحديث المهمة (حالة الإكمال)
        if (status == 'كامل') {
          await txn.update(
            'tasks',
            {'status': 2, 'completed_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [taskId],
          );
        } else {
          // تحديث وصف المهمة بإضافة ملاحظة الدفع الجزئي
          final oldTask = await txn.query('tasks', where: 'id = ?', whereArgs: [taskId]);
          String oldDesc = oldTask.isNotEmpty ? (oldTask.first['description'] as String? ?? '') : '';
          String paymentNote = '💳 دفعة بقيمة $amountPaid، المتبقي: ${_round(total - newPaid)}';
          String newDescription = oldDesc.isEmpty ? paymentNote : '$oldDesc\n$paymentNote';
          await txn.update(
            'tasks',
            {'description': newDescription},
            where: 'id = ?',
            whereArgs: [taskId],
          );
        }

        // ✅ إرجاع رقم السند ومعرفه لاستخدامه في طباعة السند فوراً
        result = {
          'success': true,
          'message': 'تم تسجيل الدفعة والسند بنجاح',
          'voucherNumber': voucherNumber,
          'voucherId': voucherId,
        };
      });
    } catch (e) {
      result = {'success': false, 'message': e.toString()};
    }
    return result;
  }

  Future<Map<String, dynamic>> autoCreateClassificationTree(
      String groupName, String categoryName, String subName) async {
    final db = await database;
    Map<String, dynamic> result = {'success': false, 'message': ''};

    try {
      await db.transaction((txn) async {
        // استخدام LOWER للمقارنة
        var gRes = await txn.rawQuery(
            'SELECT id FROM groups WHERE LOWER(name) = LOWER(?)', [groupName]);
        int gId;
        if (gRes.isEmpty) {
          gId = await txn.insert('groups', {
            'name': groupName,
            'description': 'تم الإنشاء تلقائياً بواسطة الذكاء الاصطناعي'
          });
        } else {
          gId = gRes.first['id'] as int;
        }

        var cRes = await txn.rawQuery(
            'SELECT id FROM categories WHERE LOWER(name) = LOWER(?) AND group_id = ?',
            [categoryName, gId]);
        int cId;
        if (cRes.isEmpty) {
          cId = await txn.insert('categories', {
            'name': categoryName,
            'group_id': gId,
            'description': 'تم الإنشاء تلقائياً بواسطة الذكاء الاصطناعي'
          });
        } else {
          cId = cRes.first['id'] as int;
        }

        var sRes = await txn.rawQuery(
            'SELECT id FROM subcategories WHERE LOWER(name) = LOWER(?) AND category_id = ?',
            [subName, cId]);
        if (sRes.isEmpty) {
          await txn.insert('subcategories', {
            'name': subName,
            'category_id': cId,
            'description': 'تم الإنشاء تلقائياً بواسطة الذكاء الاصطناعي'
          });
        }

        result = {
          'success': true,
          'message': 'تم إضافة ($groupName > $categoryName > $subName) بنجاح!'
        };
      });
    } catch (e) {
      result = {'success': false, 'message': 'خطأ: $e'};
    }
    return result;
  }

  Future<String> _generateDamagedInvoiceNumber(DatabaseExecutor txn) async {
    final result =
        await txn.rawQuery('SELECT MAX(id) as max_id FROM damaged_products');
    int maxId = (result.first['max_id'] as int?) ?? 0;
    int nextId = maxId + 1;
    return 'DMG-${nextId.toString().padLeft(5, '0')}';
  }

  // ==================== دالة مساعدة موحدة لحذف الفواتير بأمان ====================
  // 🚀 تم إصلاح الكود المكرر في الشرط الثلاثي
  Future<void> _deleteInvoiceWithChecks({
    required int invoiceId,
    required bool isSale, // true للمبيعات, false للمشتريات
  }) async {
    final Database db = await database; // ✅ تحديد النوع صراحة
    try {
      await db.transaction((txn) async {
        // ----- 1. تحديد الجداول والأعمدة بناءً على نوع الفاتورة -----
        final String invoiceTable =
            isSale ? 'sales_invoices' : 'purchase_invoices';
        final String itemsTable = isSale ? 'sales_items' : 'purchase_items';
        final String returnsTable =
            isSale ? 'sales_returns' : 'purchase_returns';
        final String returnsForeignKey = 'original_invoice_id'; // 🚀 تم الإصلاح
        final String personIdColumn = isSale ? 'customer_id' : 'supplier_id';
        final String personType = isSale ? 'customer' : 'supplier';
        final String treasuryRefType =
            isSale ? 'sales_invoice_reversal' : 'purchase_invoice_reversal';

        // ----- 2. التحقق من وجود مرتجع مرتبط -----
        final returns = await txn.query(
          returnsTable,
          where: '$returnsForeignKey = ?',
          whereArgs: [invoiceId],
        );
        if (returns.isNotEmpty) {
          throw Exception(
            'لا يمكن حذف الفاتورة لأنها مرتبطة بمرتجع ${isSale ? 'مبيعات' : 'مشتريات'}. قم بحذف المرتجع أولاً.',
          );
        }

        // ----- 3. التحقق من وجود حركات مخزون لاحقة (جميع الأنواع) -----
        final invoiceRes = await txn.query(
          invoiceTable,
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        if (invoiceRes.isEmpty) throw Exception('الفاتورة غير موجودة');
        final invoice = invoiceRes.first;
        final invoiceDate = invoice['date'] as String;

        final items = await txn.query(
          itemsTable,
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        for (var item in items) {
          int productId = item['product_id'] as int;

          // 3أ. التحقق من حركات المخزون (stock_movements)
          final laterMovements = await txn.rawQuery(
            '''
          SELECT COUNT(*) as count 
          FROM stock_movements 
          WHERE product_id = ? 
            AND date > ? 
            AND reference_id != ?
          ''',
            [productId, invoiceDate, invoiceId],
          );
          int count = (laterMovements.first['count'] as int?) ?? 0;
          if (count > 0) {
            throw Exception(
              'لا يمكن حذف الفاتورة لأن المنتج (${item['product_id']}) له حركات مخزون لاحقة.',
            );
          }

          // 3ب. التحقق من حركات التحويل بين المستودعات (warehouse_movements)
          final laterWarehouseMovements = await txn.rawQuery(
            '''
          SELECT COUNT(*) as count 
          FROM warehouse_movements 
          WHERE product_id = ? 
            AND date > ? 
            AND reference_id != ?
          ''',
            [productId, invoiceDate, invoiceId],
          );
          int wmCount = (laterWarehouseMovements.first['count'] as int?) ?? 0;
          if (wmCount > 0) {
            throw Exception(
              'لا يمكن حذف الفاتورة لأن المنتج (${item['product_id']}) له حركات تحويل بين مستودعات لاحقة.',
            );
          }
        }

        // ----- 4. جلب بيانات الفاتورة الرئيسية -----
        final invoiceNumber = invoice['invoice_number'] as String;
        final int? personId = invoice[personIdColumn] as int?;
        final double totalAmount = (invoice['total_amount'] as num).toDouble();
        final double paidAmount = (invoice['paid_amount'] as num).toDouble();
        final int warehouseId = (invoice['warehouse_id'] as int?) ?? 1;

        // ----- 5. عكس القيود المالية (الخزينة) -----
        if (paidAmount > 0) {
          final String reverseTreasuryType = isSale ? 'out' : 'in';
          await _addToTreasuryLogic(
            txn,
            treasuryId: 1,
            transactionType: reverseTreasuryType,
            amount: paidAmount,
            referenceType: treasuryRefType,
            referenceId: invoiceId,
            notes:
                'عكس قيد مالي بسبب حذف فاتورة ${isSale ? 'مبيعات' : 'مشتريات'} رقم $invoiceNumber',
          );
        }

        // ----- 6. عكس القيود المحاسبية (الأستاذ) -----
        if (personId != null) {
          if (isSale) {
            // المبيعات: كانت مدين (Debit) للعميل، الآن نعكسها دائن (Credit)
            await _addToLedgerLogic(
              txn,
              personId: personId,
              personType: personType,
              entryType: 'reversal',
              referenceNumber: invoiceNumber,
              debitAmount: 0,
              creditAmount: totalAmount,
              notes: 'إلغاء قيد الفاتورة بسبب الحذف ($invoiceNumber)',
            );
            if (paidAmount > 0) {
              await _addToLedgerLogic(
                txn,
                personId: personId,
                personType: personType,
                entryType: 'reversal',
                referenceNumber: invoiceNumber,
                debitAmount: paidAmount,
                creditAmount: 0,
                notes: 'إلغاء قيد الدفعة بسبب الحذف ($invoiceNumber)',
              );
            }
          } else {
            // المشتريات: كانت دائن (Credit) للمورد، الآن نعكسها مدين (Debit)
            await _addToLedgerLogic(
              txn,
              personId: personId,
              personType: personType,
              entryType: 'reversal',
              referenceNumber: invoiceNumber,
              debitAmount: totalAmount,
              creditAmount: 0,
              notes: 'إلغاء قيد الفاتورة بسبب الحذف ($invoiceNumber)',
            );
            if (paidAmount > 0) {
              await _addToLedgerLogic(
                txn,
                personId: personId,
                personType: personType,
                entryType: 'reversal',
                referenceNumber: invoiceNumber,
                debitAmount: 0,
                creditAmount: paidAmount,
                notes: 'إلغاء قيد الدفعة بسبب الحذف ($invoiceNumber)',
              );
            }
          }
        }

        // ----- 7. عكس حركات المخزون (إعادة الكميات) -----
        final String stockMovementTypeToDelete = isSale ? 'out' : 'in';

        for (var item in items) {
          final int productId = item['product_id'] as int;
          final double quantity = (item['quantity'] as num).toDouble();

          if (isSale) {
            // فاتورة مبيعات: نعيد الكمية إلى المخزون (إضافة)
            await _addStockToWarehouse(txn, productId, warehouseId, quantity);
            await txn.rawUpdate(
              'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
              [quantity, productId],
            );
          } else {
            // فاتورة مشتريات: نخصم الكمية من المخزون (لأن الحذف يعني إلغاء الإضافة)
            await _deductStockFromWarehouse(
                txn, productId, warehouseId, quantity);
            await txn.rawUpdate(
              'UPDATE products SET current_stock = current_stock - ? WHERE id = ?',
              [quantity, productId],
            );
          }

          // حذف حركة المخزون المرتبطة بهذه الفاتورة
          await txn.delete(
            'stock_movements',
            where: 'product_id = ? AND reference_id = ? AND type = ?',
            whereArgs: [productId, invoiceId, stockMovementTypeToDelete],
          );

          // حذف حركات التحويل المرتبطة بهذه الفاتورة (إن وجدت)
          await txn.delete(
            'warehouse_movements',
            where: 'product_id = ? AND reference_id = ?',
            whereArgs: [productId, invoiceId],
          );
        }

        // ----- 8. حذف السجلات المرتبطة -----
        // حذف عناصر الفاتورة
        await txn.delete(
          itemsTable,
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        // إذا كانت مشتريات، نحذف أيضاً الدُفعات (Batches)
        if (!isSale) {
          await txn.delete(
            'purchase_batches',
            where: 'invoice_id = ?',
            whereArgs: [invoiceId],
          );
        }

        // حذف الفاتورة نفسها
        await txn.delete(
          invoiceTable,
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      });
      await updateDashboardSummary();
    } catch (e) {
      throw Exception('فشل حذف فاتورة ${isSale ? 'البيع' : 'الشراء'}: $e');
    }
  }

  // ==================== دوال المستخدمين الجديدة (Raw) ====================

  Future<List<Map<String, dynamic>>> getAllUsersRaw() async {
    final db = await database;
    return await db.query('users', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getUserByIdRaw(int id) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getUserByUsernameRaw(String username) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> insertUserRaw(Map<String, dynamic> data) async {
    final db = await database;
    final copy = Map<String, dynamic>.from(data);
    copy.remove('id'); // إزالة id لأنه تلقائي (AUTOINCREMENT)
    return await db.insert('users', copy);
  }

  Future<int> updateUserRaw(Map<String, dynamic> data) async {
    final db = await database;
    final id = data['id'];
    final copy = Map<String, dynamic>.from(data);
    copy.remove('id');
    return await db.update('users', copy, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> deleteUserRaw(int id) async {
    final db = await database;
    final user = await getUserByIdRaw(id);
    if (user != null && user['username'] == 'admin') {
      throw Exception('لا يمكن حذف حساب المدير الرئيسي');
    }
    final result = await db.delete('users', where: 'id = ?', whereArgs: [id]);
    return result > 0;
  }

  // ==================== دوال المستخدمين والصلاحيات ====================

  /// إنشاء حساب Admin افتراضي عند أول تشغيل للتطبيق
  Future<void> checkAndCreateDefaultAdmin() async {
    final db = await database;
    final users = await db.query('users');
    if (users.isEmpty) {
      debugPrint('👤 جاري إنشاء حساب المدير الافتراضي...');
      final defaultAdminHash = await HashUtil.hashPassword('admin123');
      await db.insert('users', {
        'username': 'admin',
        'password_hash': defaultAdminHash,
        'full_name': 'المدير العام',
        'role': 'admin',
        'permissions': '*',
      });
      debugPrint('✅ تم إنشاء حساب المدير الافتراضي (admin / admin123)');
    }
  }

  /// إدخال الصلاحيات الافتراضية في جدول permissions
  Future<void> seedDefaultPermissions() async {
    final db = await database;
    final count =
        await db.rawQuery('SELECT COUNT(*) as count FROM permissions');
    final total = count.isNotEmpty ? (count.first['count'] as int?) ?? 0 : 0;

    if (total == 0) {
      final permissions = [
        {'key': 'dashboard', 'label': 'لوحة التحكم', 'icon': 'dashboard'},
        {
          'key': 'sales_invoice',
          'label': 'فواتير البيع',
          'icon': 'point_of_sale'
        },
        {
          'key': 'purchase_invoice',
          'label': 'فواتير الشراء',
          'icon': 'shopping_cart'
        },
        {'key': 'products', 'label': 'المنتجات', 'icon': 'inventory'},
        {'key': 'customers', 'label': 'العملاء', 'icon': 'people'},
        {'key': 'suppliers', 'label': 'الموردين', 'icon': 'local_shipping'},
        {'key': 'warehouses', 'label': 'المستودعات', 'icon': 'warehouse'},
        {'key': 'units', 'label': 'وحدات القياس', 'icon': 'straighten'},
        {'key': 'groups', 'label': 'المجموعات', 'icon': 'folder'},
        {'key': 'subcategories', 'label': 'الأصناف', 'icon': 'category'},
        {
          'key': 'invoices_list',
          'label': 'سجل الفواتير',
          'icon': 'folder_copy'
        },
        {'key': 'sales_returns', 'label': 'مرتجعات المبيعات', 'icon': 'undo'},
        {
          'key': 'purchase_returns',
          'label': 'مرتجعات المشتريات',
          'icon': 'replay'
        },
        {
          'key': 'returns_list',
          'label': 'سجل المرتجعات',
          'icon': 'assignment_return'
        },
        {'key': 'treasury', 'label': 'الخزينة', 'icon': 'account_balance'},
        {
          'key': 'financial_vouchers',
          'label': 'السندات المالية',
          'icon': 'receipt_long'
        },
        {'key': 'debtors', 'label': 'المدينون', 'icon': 'money_off'},
        {'key': 'creditors', 'label': 'الدائنون', 'icon': 'savings'},
        {
          'key': 'profit_reports',
          'label': 'تقارير الأرباح',
          'icon': 'trending_up'
        },
        {
          'key': 'expired_products',
          'label': 'المنتجات منتهية الصلاحية',
          'icon': 'warning_amber'
        },
        {
          'key': 'damaged_products',
          'label': 'سجل التوالف',
          'icon': 'delete_sweep'
        },
        {'key': 'backup', 'label': 'النسخ الاحتياطي', 'icon': 'cloud_upload'},
        {'key': 'tasks', 'label': 'المهام', 'icon': 'task'},
        {'key': 'users', 'label': 'إدارة المستخدمين', 'icon': 'group'},
        {
          'key': 'security_settings',
          'label': 'إعدادات الأمان',
          'icon': 'security'
        },
        {'key': 'settings', 'label': 'الإعدادات العامة', 'icon': 'settings'},
        {'key': 'shop_settings', 'label': 'بيانات المحل', 'icon': 'store'},
        {'key': 'due_reminders', 'label': 'تذكير الديون', 'icon': 'alarm'},
        {
          'key': 'barcode_scanner',
          'label': 'مسح الباركود',
          'icon': 'qr_code_scanner'
        },
        {'key': 'ai_chat', 'label': 'المساعد الذكي', 'icon': 'auto_awesome'},
      ];

      for (var perm in permissions) {
        await db.insert('permissions', perm);
      }
      debugPrint('✅ تم إضافة ${permissions.length} صلاحية افتراضية.');
    }
  }

  // ============================================================
  //  دوال تحليل الأرباح والرسومات البيانية (Business Intelligence)
  // ============================================================

// ============================================================
  //  دوال تحليل الأرباح والرسومات البيانية (Business Intelligence)
  // ============================================================

  /// 1. جلب ملخص المؤشرات المالية (KPIs) لفترة محددة (محسنة للأداء العالي وتجنب الـ JOIN الثقيل)
  Future<Map<String, double>> getFinancialKPIs({required String startDate, required String endDate}) async {
    final db = await database;

    // 🚀 1. إجمالي المبيعات باستخدام فهرس التاريخ مباشرة
    final salesRes = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as total_sales
      FROM sales_invoices
      WHERE substr(date, 1, 10) BETWEEN ? AND ?
    ''', [startDate, endDate]);

    // 🚀 2. تكلفة البضاعة المباعة (COGS) باستخدام Subquery وفهرس invoice_id لتجنب الـ JOIN المتعدد على جداول ضخمة
    final cogsRes = await db.rawQuery('''
      SELECT COALESCE(SUM(items.quantity * p.cost_price), 0) as total_cogs
      FROM sales_items items
      JOIN products p ON items.product_id = p.id
      WHERE items.invoice_id IN (
        SELECT id FROM sales_invoices WHERE substr(date, 1, 10) BETWEEN ? AND ?
      )
    ''', [startDate, endDate]);

    // 3. إجمالي المصروفات التشغيلية (سندات الصرف)
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_expenses 
      FROM financial_vouchers 
      WHERE type = 'payment' AND substr(date, 1, 10) BETWEEN ? AND ?
    ''', [startDate, endDate]);

    // 4. إجمالي المرتجعات
    double totalReturns = 0.0;
    try {
      final returnsRes = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0) as total_returns
        FROM sales_returns 
        WHERE substr(return_date, 1, 10) BETWEEN ? AND ?
      ''', [startDate, endDate]);
      totalReturns = (returnsRes.first['total_returns'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('تنبيه: لم يتم العثور على جدول sales_returns، سيتم اعتبار المرتجعات صفر.');
    }

    final double totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final double totalCogs = (cogsRes.first['total_cogs'] as num?)?.toDouble() ?? 0.0;
    final double totalExpenses = (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    // صافي الربح = (المبيعات - المرتجعات) - تكلفة البضاعة - المصروفات
    final double netProfit = (totalSales - totalReturns) - totalCogs - totalExpenses;

    return {
      'total_sales': totalSales,
      'total_cogs': totalCogs,
      'total_expenses': totalExpenses,
      'total_returns': totalReturns,
      'net_profit': netProfit,
    };
  }
  /// 2. جلب مسار المبيعات والأرباح اليومية لرسم المنحنى الخطي (Line Chart)
  Future<List<Map<String, dynamic>>> getDailyProfitTrend({required String startDate, required String endDate}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        substr(si.date, 1, 10) as day_date,
        COALESCE(SUM(si.total_amount), 0) as daily_sales
      FROM sales_invoices si
      WHERE substr(si.date, 1, 10) BETWEEN ? AND ?
      GROUP BY substr(si.date, 1, 10)
      ORDER BY substr(si.date, 1, 10) ASC
    ''', [startDate, endDate]);
  }

  // ==========================================
  // 🚀 الجزء الأول: نظام السلف والقروض (Loan Management System)
  // ==========================================
  Future<int> insertLoan(Map<String, dynamic> loan) async {
    final db = await database;
    return await db.transaction((txn) async {
      final mutableLoan = Map<String, dynamic>.from(loan);
      mutableLoan['remaining_balance'] = mutableLoan['amount'];
      mutableLoan['paid_amount'] = 0.0;
      mutableLoan['created_at'] = DateTime.now().toIso8601String();
      mutableLoan['updated_at'] = DateTime.now().toIso8601String();
      final id = await txn.insert('loans', mutableLoan);

      final partyId = mutableLoan['party_id'] as int?;
      final loanType = mutableLoan['loan_type'] as String?;
      final amt = (mutableLoan['amount'] as num?)?.toDouble() ?? 0.0;

      if (partyId != null && loanType != null && amt > 0) {
        if (loanType == 'customer') {
          await _addToLedgerLogic(
            txn,
            personId: partyId,
            personType: 'customer',
            entryType: 'سلفة جديدة',
            referenceNumber: mutableLoan['reference_number'] as String? ?? 'LOAN-$id',
            debitAmount: amt,
            creditAmount: 0.0,
            notes: mutableLoan['notes'] as String? ?? 'منح سلفة جديدة للعميل',
          );
        } else if (loanType == 'supplier') {
          await _addToLedgerLogic(
            txn,
            personId: partyId,
            personType: 'supplier',
            entryType: 'سلفة جديدة',
            referenceNumber: mutableLoan['reference_number'] as String? ?? 'LOAN-$id',
            debitAmount: 0.0,
            creditAmount: amt,
            notes: mutableLoan['notes'] as String? ?? 'استلام سلفة جديدة من المورد',
          );
        }
      }
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getAllLoans({String? status, String? type}) async {
    final db = await database;
    List<String> conditions = [];
    List<dynamic> args = [];
    if (status != null && status.isNotEmpty) {
      conditions.add('status = ?');
      args.add(status);
    }
    if (type != null && type.isNotEmpty) {
      conditions.add('loan_type = ?');
      args.add(type);
    }
    final whereStr = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    return await db.query('loans', where: whereStr, whereArgs: args.isNotEmpty ? args : null, orderBy: 'loan_date DESC');
  }

  Future<Map<String, dynamic>?> getLoanById(int id) async {
    final db = await database;
    final res = await db.query('loans', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> updateLoan(int id, Map<String, dynamic> data) async {
    final db = await database;
    final mutable = Map<String, dynamic>.from(data);
    mutable['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('loans', mutable, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> deleteLoan(int id) async {
    final db = await database;
    final loan = await getLoanById(id);
    if (loan == null) return false;
    final paid = (loan['paid_amount'] as num?)?.toDouble() ?? 0.0;
    if (paid > 0) {
      throw Exception('لا يمكن حذف سلفة تم إجراء دفعات سداد عليها.');
    }
    final count = await db.delete('loans', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<void> recordLoanPayment(int loanId, double paymentAmount, String paymentMethod) async {
    final db = await database;
    await db.transaction((txn) async {
      final loanRes = await txn.query('loans', where: 'id = ?', whereArgs: [loanId]);
      if (loanRes.isEmpty) throw Exception('السلفة غير موجودة');
      final loan = loanRes.first;
      final currentPaid = (loan['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = (loan['amount'] as num?)?.toDouble() ?? 0.0;
      final newPaid = currentPaid + paymentAmount;
      final newRemaining = (totalAmount - newPaid).clamp(0.0, double.infinity);
      final newStatus = newRemaining <= 0 ? 'paid' : 'partial';

      await txn.update(
        'loans',
        {
          'paid_amount': newPaid,
          'remaining_balance': newRemaining,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );

      final partyId = loan['party_id'] as int;
      final loanType = loan['loan_type'] as String;
      final refNum = 'LOAN-PAY-$loanId-${DateTime.now().millisecondsSinceEpoch}';

      if (loanType == 'customer') {
        await _addToLedgerLogic(
          txn,
          personId: partyId,
          personType: 'customer',
          entryType: 'سداد سلفة',
          referenceNumber: refNum,
          debitAmount: 0.0,
          creditAmount: paymentAmount,
          notes: 'سداد دفعة من سلفة العميل #$loanId ($paymentMethod)',
        );
      } else if (loanType == 'supplier') {
        await _addToLedgerLogic(
          txn,
          personId: partyId,
          personType: 'supplier',
          entryType: 'سداد سلفة',
          referenceNumber: refNum,
          debitAmount: paymentAmount,
          creditAmount: 0.0,
          notes: 'سداد دفعة من سلفة المورد #$loanId ($paymentMethod)',
        );
      }
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> getLoansAgingReport() async {
    final db = await database;
    final loans = await db.query('loans', where: 'status != ?', whereArgs: ['paid']);
    final now = DateTime.now();
    List<Map<String, dynamic>> lessThan30 = [];
    List<Map<String, dynamic>> between30And60 = [];
    List<Map<String, dynamic>> moreThan60 = [];

    for (var l in loans) {
      final dueDateStr = l['due_date']?.toString() ?? l['loan_date']?.toString();
      if (dueDateStr != null && dueDateStr.isNotEmpty) {
        try {
          final due = DateTime.parse(dueDateStr);
          final days = now.difference(due).inDays;
          if (days <= 30) {
            lessThan30.add(l);
          } else if (days <= 60) {
            between30And60.add(l);
          } else {
            moreThan60.add(l);
          }
        } catch (_) {
          lessThan30.add(l);
        }
      } else {
        lessThan30.add(l);
      }
    }
    return {
      'lessThan30': lessThan30,
      'between30And60': between30And60,
      'moreThan60': moreThan60,
    };
  }

  // ==========================================
  // 🚀 الجزء الثاني: تقرير أعمار الذمم المدينة والتدفق النقدي
  // ==========================================
  Future<Map<String, double>> getAccountsReceivableAgingReport() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(date) AS INTEGER) <= 30 THEN total_amount - COALESCE(paid_amount, 0) ELSE 0 END), 0) as current_0_30,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(date) AS INTEGER) BETWEEN 31 AND 60 THEN total_amount - COALESCE(paid_amount, 0) ELSE 0 END), 0) as days_31_60,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(date) AS INTEGER) BETWEEN 61 AND 90 THEN total_amount - COALESCE(paid_amount, 0) ELSE 0 END), 0) as days_61_90,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(date) AS INTEGER) > 90 THEN total_amount - COALESCE(paid_amount, 0) ELSE 0 END), 0) as days_over_90
      FROM sales_invoices
      WHERE payment_status != 'مدفوع' AND payment_status != 'كامل'
    ''');
    final row = res.first;
    return {
      '0_30': (row['current_0_30'] as num?)?.toDouble() ?? 0.0,
      '31_60': (row['days_31_60'] as num?)?.toDouble() ?? 0.0,
      '61_90': (row['days_61_90'] as num?)?.toDouble() ?? 0.0,
      'over_90': (row['days_over_90'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<Map<String, dynamic>> getCashFlowStatement({required String startDate, required String endDate}) async {
    final db = await database;
    final cashSales = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as v FROM sales_invoices WHERE payment_status = 'مدفوع' AND substr(date, 1, 10) BETWEEN ? AND ?
    ''', [startDate, endDate]);
    final receipts = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as v FROM financial_vouchers WHERE type = 'receipt' AND substr(date, 1, 10) BETWEEN ? AND ?
    ''', [startDate, endDate]);
    final cashPurchases = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as v FROM purchase_invoices WHERE payment_status = 'مدفوع' AND substr(date, 1, 10) BETWEEN ? AND ?
    ''', [startDate, endDate]);
    final payments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as v FROM financial_vouchers WHERE type = 'payment' AND substr(date, 1, 10) BETWEEN ? AND ?
    ''', [startDate, endDate]);

    final totalInflows = ((cashSales.first['v'] as num?)?.toDouble() ?? 0.0) + ((receipts.first['v'] as num?)?.toDouble() ?? 0.0);
    final totalOutflows = ((cashPurchases.first['v'] as num?)?.toDouble() ?? 0.0) + ((payments.first['v'] as num?)?.toDouble() ?? 0.0);
    final netCashFlow = totalInflows - totalOutflows;

    return {
      'total_inflows': totalInflows,
      'total_outflows': totalOutflows,
      'net_cash_flow': netCashFlow,
    };
  }

  // ==========================================
  // 🚀 الجزء الرابع: سجل التدقيق (Audit Log)
  // ==========================================
  Future<int> logAuditAction({
    int? userId,
    required String action,
    required String tableName,
    int? recordId,
    String? oldValue,
    String? newValue,
  }) async {
    final db = await database;
    return await db.insert('audit_log', {
      'user_id': userId ?? 1,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_value': oldValue,
      'new_value': newValue,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getLoanStatistics() async {
    final db = await database;
    final resTotal = await db.rawQuery("SELECT COALESCE(SUM(amount), 0) as v FROM loans");
    final resPaid = await db.rawQuery("SELECT COALESCE(SUM(paid_amount), 0) as v FROM loans");
    final resRem = await db.rawQuery("SELECT COALESCE(SUM(remaining_balance), 0) as v FROM loans");
    final resActive = await db.rawQuery("SELECT COUNT(*) as c FROM loans WHERE status != 'paid'");
    return {
      'total_amount': (resTotal.first['v'] as num?)?.toDouble() ?? 0.0,
      'total_paid': (resPaid.first['v'] as num?)?.toDouble() ?? 0.0,
      'total_remaining': (resRem.first['v'] as num?)?.toDouble() ?? 0.0,
      'active_loans_count': (resActive.first['c'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getCustomerLoanHistory(int customerId) async {
    final db = await database;
    return await db.query(
      'loans',
      where: 'party_id = ? AND loan_type = ?',
      whereArgs: [customerId, 'customer'],
      orderBy: 'loan_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierLoanHistory(int supplierId) async {
    final db = await database;
    return await db.query(
      'loans',
      where: 'party_id = ? AND loan_type = ?',
      whereArgs: [supplierId, 'supplier'],
      orderBy: 'loan_date DESC',
    );
  }

  Future<Map<String, dynamic>> getAgingReportData({String? startDate, String? endDate}) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        c.id, c.name, c.phone,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(si.date) AS INTEGER) <= 30 THEN si.total_amount - COALESCE(si.paid_amount, 0) ELSE 0 END), 0) as days_0_30,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(si.date) AS INTEGER) BETWEEN 31 AND 60 THEN si.total_amount - COALESCE(si.paid_amount, 0) ELSE 0 END), 0) as days_31_60,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(si.date) AS INTEGER) BETWEEN 61 AND 90 THEN si.total_amount - COALESCE(si.paid_amount, 0) ELSE 0 END), 0) as days_61_90,
        COALESCE(SUM(CASE WHEN CAST(julianday('now') - julianday(si.date) AS INTEGER) > 90 THEN si.total_amount - COALESCE(si.paid_amount, 0) ELSE 0 END), 0) as days_over_90,
        COALESCE(SUM(si.total_amount - COALESCE(si.paid_amount, 0)), 0) as total_debt
      FROM customers c
      INNER JOIN sales_invoices si ON si.customer_id = c.id
      WHERE si.payment_status != 'مدفوع' AND si.payment_status != 'كامل'
      GROUP BY c.id, c.name, c.phone
      HAVING total_debt > 0
      ORDER BY total_debt DESC
    ''');
    return {'customers': res};
  }

  Future<Map<String, dynamic>> getBalanceSheet({required String asOfDate}) async {
    final db = await database;
    final cashRes = await db.rawQuery("SELECT COALESCE(SUM(paid_amount), 0) as v FROM sales_invoices WHERE substr(date, 1, 10) <= ?", [asOfDate]);
    final arRes = await db.rawQuery("SELECT COALESCE(SUM(balance), 0) as v FROM customers WHERE balance > 0");
    final invRes = await db.rawQuery("SELECT COALESCE(SUM(current_stock * cost_price), 0) as v FROM products");
    final apRes = await db.rawQuery("SELECT COALESCE(SUM(balance), 0) as v FROM suppliers WHERE balance > 0");
    final loanRes = await db.rawQuery("SELECT COALESCE(SUM(remaining_balance), 0) as v FROM loans WHERE loan_type = 'supplier' AND status != 'paid'");

    final cash = (cashRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final ar = (arRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final inv = (invRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final totalAssets = cash + ar + inv;

    final ap = (apRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final loans = (loanRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final totalLiabilities = ap + loans;
    final equity = totalAssets - totalLiabilities;

    return {
      'assets': {'cash': cash, 'accounts_receivable': ar, 'inventory': inv, 'total': totalAssets},
      'liabilities': {'accounts_payable': ap, 'loans': loans, 'total': totalLiabilities},
      'equity': {'retained_earnings': equity, 'total': equity},
    };
  }

  Future<List<Map<String, dynamic>>> getTopCustomers(int limit) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.id, c.name, COALESCE(SUM(si.total_amount), 0) as total_spent, COUNT(si.id) as invoices_count
      FROM customers c
      JOIN sales_invoices si ON si.customer_id = c.id
      GROUP BY c.id, c.name
      ORDER BY total_spent DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, dynamic>>> getProductSalesRanking(int limit) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.id, p.name, COALESCE(SUM(si.quantity), 0) as total_qty, COALESCE(SUM(si.total), 0) as total_revenue
      FROM products p
      JOIN sales_items si ON si.product_id = p.id
      GROUP BY p.id, p.name
      ORDER BY total_revenue DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<void> insertProductBatch(Map<String, dynamic> batch) async {
    final db = await database;
    await db.insert('product_batches', batch);
  }

  Future<List<Map<String, dynamic>>> getProductBatches(int productId) async {
    final db = await database;
    return await db.query('product_batches', where: 'product_id = ?', whereArgs: [productId], orderBy: 'expiry_date ASC');
  }

  Future<void> deductFromBatch(int batchId, int quantity) async {
    final db = await database;
    await db.rawUpdate('UPDATE product_batches SET remaining_quantity = remaining_quantity - ? WHERE id = ?', [quantity, batchId]);
  }

  Future<void> assignSerialNumber(int productId, String serialNumber) async {
    final db = await database;
    await db.insert('product_serial_numbers', {
      'product_id': productId,
      'serial_number': serialNumber,
      'is_sold': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> isSerialNumberExists(String serialNumber) async {
    final db = await database;
    final res = await db.query('product_serial_numbers', where: 'serial_number = ?', whereArgs: [serialNumber]);
    return res.isNotEmpty;
  }

  Future<void> markSerialAsSold(String serialNumber, int invoiceId, int customerId) async {
    final db = await database;
    await db.update(
      'product_serial_numbers',
      {'is_sold': 1, 'invoice_id': invoiceId},
      where: 'serial_number = ?',
      whereArgs: [serialNumber],
    );
  }

  Future<Map<String, dynamic>?> getProductBySerialNumber(String serialNumber) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT p.*, sn.serial_number, sn.is_sold, sn.invoice_id
      FROM product_serial_numbers sn
      JOIN products p ON p.id = sn.product_id
      WHERE sn.serial_number = ?
    ''', [serialNumber]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> createInventoryAdjustment(Map<String, dynamic> adjustment) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('inventory_adjustments', adjustment);
      final prodId = adjustment['product_id'] as int;
      final diff = (adjustment['difference'] as num).toDouble();
      await txn.rawUpdate('UPDATE products SET current_stock = current_stock + ? WHERE id = ?', [diff, prodId]);
    });
  }

  Future<List<Map<String, dynamic>>> getInventoryAdjustments({String? startDate, String? endDate}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT a.*, p.name as product_name
      FROM inventory_adjustments a
      JOIN products p ON p.id = a.product_id
      ORDER BY a.adjustment_date DESC
    ''');
  }

  Future<Map<String, dynamic>> getInventoryVarianceReport() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_adjustments,
        COALESCE(SUM(CASE WHEN difference > 0 THEN difference ELSE 0 END), 0) as total_surplus_qty,
        COALESCE(SUM(CASE WHEN difference < 0 THEN ABS(difference) ELSE 0 END), 0) as total_deficit_qty
      FROM inventory_adjustments
    ''');
    return res.first;
  }

  Future<Map<String, dynamic>> getSalesSummary() async {
    final kpis = await getFinancialKPIs(startDate: '2020-01-01', endDate: '2030-12-31');
    return {
      'total_sales': kpis['total_sales'] ?? 0.0,
      'total_profit': kpis['net_profit'] ?? 0.0,
      'total_cogs': kpis['total_cogs'] ?? 0.0,
      'total_expenses': kpis['total_expenses'] ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    return await getAllProductsWithDetails();
  }
}
