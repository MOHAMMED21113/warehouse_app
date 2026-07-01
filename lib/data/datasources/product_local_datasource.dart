// lib/data/datasources/product_local_datasource.dart
import '../../domain/entities/product_entity.dart';
import '../../database/database_helper.dart';

class ProductLocalDataSource {
  final DatabaseHelper db;
  ProductLocalDataSource(this.db); // ✅ حقن عبر constructor

  Future<(List<ProductEntity>, int)> getProductsPaginated({
    required int page, required int limit, String? searchQuery, bool? isActive,
  }) async {
    final offset = (page - 1) * limit;
    final q = searchQuery?.isNotEmpty == true ? '%$searchQuery%' : null;

    String sql = '''
      SELECT p.*, 
             COALESCE(pws.quantity, 0) as current_stock,
             s.name as supplier_name, sub.name as subcategory_name,
             c.name as category_name, g.name as group_name,
             u.name as unit_name, u.symbol as unit_symbol,
             cur.name as currency_name, cur.code as currency_code, cur.symbol as currency_symbol
      FROM products p
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      LEFT JOIN subcategories sub ON p.subcategory_id = sub.id
      LEFT JOIN categories c ON sub.category_id = c.id
      LEFT JOIN groups g ON c.group_id = g.id
      LEFT JOIN units u ON p.unit_id = u.id
      LEFT JOIN currencies cur ON p.currency_id = cur.id
      LEFT JOIN product_warehouse_stock pws ON p.id = pws.product_id AND pws.warehouse_id = 1
      WHERE 1=1
    ''';

    List<Object?> args = [];
    if (q != null) {
      sql += ' AND (p.name LIKE ? OR p.barcode LIKE ? OR p.second_barcode LIKE ? OR g.name LIKE ? OR c.name LIKE ? OR sub.name LIKE ?)';
      args.addAll([q, q, q, q, q, q]);
    }
    if (isActive != null) { sql += ' AND p.is_active = ?'; args.add(isActive ? 1 : 0); }

    final totalCount = ((await db.rawQuery('SELECT COUNT(*) as total FROM ($sql)', args)).first['total'] as int?) ?? 0;
    sql += ' ORDER BY p.id DESC LIMIT $limit OFFSET $offset';
    final maps = await db.rawQuery(sql, args);

    final products = maps.map((m) => ProductEntity(
      id: m['id'], barcode: m['barcode'], secondBarcode: m['second_barcode'],
      name: m['name'], subcategoryId: m['subcategory_id'], unitId: m['unit_id'],
      currencyId: m['currency_id'], unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
      currentStock: (m['current_stock'] as num?)?.toDouble() ?? 0.0,
      costPrice: (m['cost_price'] as num?)?.toDouble() ?? 0.0,
      minStock: (m['min_stock'] as num?)?.toDouble() ?? 0.0,
      supplierId: m['supplier_id'],
      expiryDate: m['expiry_date'] != null ? DateTime.tryParse(m['expiry_date']) : null,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at']) : null,
      isActive: (m['is_active'] ?? 1) == 1,
      supplierName: m['supplier_name'], subcategoryName: m['subcategory_name'],
      categoryName: m['category_name'], groupName: m['group_name'],
      unitName: m['unit_name'], unitSymbol: m['unit_symbol'],
      currencyName: m['currency_name'], currencyCode: m['currency_code'],
      currencySymbol: m['currency_symbol'],
    )).toList();

    return (products, totalCount);
  }

  Future<ProductEntity?> searchProductByAnyBarcode(String b) async {
    final m = await db.searchProductByAnyBarcode(b);
    return m != null ? _mapToEntity(m) : null;
  }

  Future<ProductEntity?> getProductById(int id) async {
    final m = await db.getProductById(id);
    return m != null ? _mapToEntity(m) : null;
  }

  Future<int> insertProduct(ProductEntity p) async => await db.insertProduct(p.toMap());
  Future<void> updateProduct(ProductEntity p) async => await db.updateProduct(p.id!, p.toMap());
  Future<Map<String, dynamic>> deleteProductSafe(int id) async => await db.deleteProductSafe(id);

  ProductEntity _mapToEntity(Map<String, dynamic> m) {
    return ProductEntity(
      id: m['id'], barcode: m['barcode'], secondBarcode: m['second_barcode'],
      name: m['name'], subcategoryId: m['subcategory_id'], unitId: m['unit_id'],
      currencyId: m['currency_id'], unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
      currentStock: (m['current_stock'] as num?)?.toDouble() ?? 0.0,
      costPrice: (m['cost_price'] as num?)?.toDouble() ?? 0.0,
      minStock: (m['min_stock'] as num?)?.toDouble() ?? 0.0,
      supplierId: m['supplier_id'],
      expiryDate: m['expiry_date'] != null ? DateTime.tryParse(m['expiry_date']) : null,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at']) : null,
      isActive: (m['is_active'] ?? 1) == 1,
      supplierName: m['supplier_name'], subcategoryName: m['subcategory_name'],
      categoryName: m['category_name'], groupName: m['group_name'],
      unitName: m['unit_name'], unitSymbol: m['unit_symbol'],
      currencyName: m['currency_name'], currencyCode: m['currency_code'],
      currencySymbol: m['currency_symbol'],
    );
  }
}