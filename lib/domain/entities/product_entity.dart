// lib/domain/entities/product_entity.dart
class ProductEntity {
  final int? id;
  final String? barcode;
  final String? secondBarcode;
  final String name;
  final int? subcategoryId;
  final int? unitId;
  final int? currencyId;
  final double unitPrice;
  final double currentStock;
  final double costPrice;
  final double minStock;
  final int? supplierId;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final bool isActive;

  // حقول البونص الجديدة
  final bool bonusEnabled;
  final int? bonusRequiredQty;
  final int? bonusFreeProductId;
  final int? bonusFreeQty;

  // حقول JOIN (لا تخزن في جدول المنتجات)
  final String? supplierName;
  final String? subcategoryName;
  final String? categoryName;
  final String? groupName;
  final String? unitName;
  final String? unitSymbol;
  final String? currencyName;
  final String? currencyCode;
  final String? currencySymbol;

  const ProductEntity({
    this.id,
    this.barcode,
    this.secondBarcode,
    required this.name,
    this.subcategoryId,
    this.unitId,
    this.currencyId,
    required this.unitPrice,
    required this.currentStock,
    required this.costPrice,
    required this.minStock,
    this.supplierId,
    this.expiryDate,
    this.createdAt,
    required this.isActive,
    this.supplierName,
    this.subcategoryName,
    this.categoryName,
    this.groupName,
    this.unitName,
    this.unitSymbol,
    this.currencyName,
    this.currencyCode,
    this.currencySymbol,
    this.bonusEnabled = false,
    this.bonusRequiredQty,
    this.bonusFreeProductId,
    this.bonusFreeQty,
  });

  ProductEntity copyWith({
    int? id,
    String? barcode,
    String? secondBarcode,
    String? name,
    int? subcategoryId,
    int? unitId,
    int? currencyId,
    double? unitPrice,
    double? currentStock,
    double? costPrice,
    double? minStock,
    int? supplierId,
    DateTime? expiryDate,
    DateTime? createdAt,
    bool? isActive,
    String? supplierName,
    String? subcategoryName,
    String? categoryName,
    String? groupName,
    String? unitName,
    String? unitSymbol,
    String? currencyName,
    String? currencyCode,
    String? currencySymbol,
    bool? bonusEnabled,
    int? bonusRequiredQty,
    int? bonusFreeProductId,
    int? bonusFreeQty,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      secondBarcode: secondBarcode ?? this.secondBarcode,
      name: name ?? this.name,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      unitId: unitId ?? this.unitId,
      currencyId: currencyId ?? this.currencyId,
      unitPrice: unitPrice ?? this.unitPrice,
      currentStock: currentStock ?? this.currentStock,
      costPrice: costPrice ?? this.costPrice,
      minStock: minStock ?? this.minStock,
      supplierId: supplierId ?? this.supplierId,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      supplierName: supplierName ?? this.supplierName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      categoryName: categoryName ?? this.categoryName,
      groupName: groupName ?? this.groupName,
      unitName: unitName ?? this.unitName,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      currencyName: currencyName ?? this.currencyName,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      bonusEnabled: bonusEnabled ?? this.bonusEnabled,
      bonusRequiredQty: bonusRequiredQty ?? this.bonusRequiredQty,
      bonusFreeProductId: bonusFreeProductId ?? this.bonusFreeProductId,
      bonusFreeQty: bonusFreeQty ?? this.bonusFreeQty,
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
      'bonus_enabled': bonusEnabled ? 1 : 0,
      'bonus_required_qty': bonusRequiredQty,
      'bonus_free_product_id': bonusFreeProductId,
      'bonus_free_qty': bonusFreeQty,
    };
  }
}