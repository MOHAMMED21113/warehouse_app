// lib/data/models/product_model.dart

import '../../domain/entities/product_entity.dart';


class ProductModel extends ProductEntity {
  const ProductModel({
    super.id,
    super.barcode,
    super.secondBarcode,
    required super.name,
    super.subcategoryId,
    super.unitId,
    super.currencyId,
    required super.unitPrice,
    required super.currentStock,
    required super.costPrice,
    required super.minStock,
    super.supplierId,
    super.expiryDate,
    super.createdAt,
    required super.isActive,
    super.supplierName,
    super.subcategoryName,
    super.categoryName,
    super.groupName,
    super.unitName,
    super.unitSymbol,
    super.currencyName,
    super.currencyCode,
    super.currencySymbol,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      barcode: map['barcode'] as String?,
      secondBarcode: map['second_barcode'] as String?,
      name: map['name'] as String,
      subcategoryId: map['subcategory_id'] as int?,
      unitId: map['unit_id'] as int?,
      currencyId: map['currency_id'] as int?,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0.0,
      supplierId: map['supplier_id'] as int?,
      expiryDate: map['expiry_date'] != null
          ? DateTime.tryParse(map['expiry_date'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      isActive: (map['is_active'] as int?) == 1,
      supplierName: map['supplier_name'] as String?,
      subcategoryName: map['subcategory_name'] as String?,
      categoryName: map['category_name'] as String?,
      groupName: map['group_name'] as String?,
      unitName: map['unit_name'] as String?,
      unitSymbol: map['unit_symbol'] as String?,
      currencyName: map['currency_name'] as String?,
      currencyCode: map['currency_code'] as String?,
      currencySymbol: map['currency_symbol'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barcode': barcode,
      'second_barcode': secondBarcode,
      'name': name,
      'subcategory_id': subcategoryId,
      'unit_id': unitId,
      'currency_id': currencyId,
      'unit_price': unitPrice,
      'current_stock': currentStock,
      'cost_price': costPrice,
      'min_stock': minStock,
      'supplier_id': supplierId,
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }
}