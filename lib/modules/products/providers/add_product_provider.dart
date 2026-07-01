// lib/modules/products/providers/add_product_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

class AddProductState {
  final bool isLoading;
  final bool isAddingNewGroup;
  final bool showUnitPrices;
  final bool isBonusEnabled;

  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> subcategories;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> currencies;
  final List<Map<String, dynamic>> warehouses;
  final List<Map<String, dynamic>> allProducts;

  final int? selectedGroupId;
  final int? selectedCategoryId;
  final int? selectedSubcategoryId;
  final int? selectedUnitId;
  final int? selectedSupplierId;
  final int? selectedCurrencyId;
  final int? selectedWarehouseId;
  final int? selectedBonusFreeProductId;
  final DateTime? selectedExpiryDate;

  AddProductState({
    this.isLoading = false,
    this.isAddingNewGroup = false,
    this.showUnitPrices = false,
    this.isBonusEnabled = false,
    this.groups = const [],
    this.categories = const [],
    this.subcategories = const [],
    this.units = const [],
    this.suppliers = const [],
    this.currencies = const [],
    this.warehouses = const [],
    this.allProducts = const [],
    this.selectedGroupId,
    this.selectedCategoryId,
    this.selectedSubcategoryId,
    this.selectedUnitId,
    this.selectedSupplierId,
    this.selectedCurrencyId,
    this.selectedWarehouseId,
    this.selectedBonusFreeProductId,
    this.selectedExpiryDate,
  });

  AddProductState copyWith({
    bool? isLoading,
    bool? isAddingNewGroup,
    bool? showUnitPrices,
    bool? isBonusEnabled,
    List<Map<String, dynamic>>? groups,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? subcategories,
    List<Map<String, dynamic>>? units,
    List<Map<String, dynamic>>? suppliers,
    List<Map<String, dynamic>>? currencies,
    List<Map<String, dynamic>>? warehouses,
    List<Map<String, dynamic>>? allProducts,
    int? selectedGroupId, bool clearGroupId = false,
    int? selectedCategoryId, bool clearCategoryId = false,
    int? selectedSubcategoryId, bool clearSubcategoryId = false,
    int? selectedUnitId, bool clearUnitId = false,
    int? selectedSupplierId, bool clearSupplierId = false,
    int? selectedCurrencyId, bool clearCurrencyId = false,
    int? selectedWarehouseId, bool clearWarehouseId = false,
    int? selectedBonusFreeProductId, bool clearBonusFreeId = false,
    DateTime? selectedExpiryDate, bool clearExpiryDate = false,
  }) {
    return AddProductState(
      isLoading: isLoading ?? this.isLoading,
      isAddingNewGroup: isAddingNewGroup ?? this.isAddingNewGroup,
      showUnitPrices: showUnitPrices ?? this.showUnitPrices,
      isBonusEnabled: isBonusEnabled ?? this.isBonusEnabled,
      groups: groups ?? this.groups,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      units: units ?? this.units,
      suppliers: suppliers ?? this.suppliers,
      currencies: currencies ?? this.currencies,
      warehouses: warehouses ?? this.warehouses,
      allProducts: allProducts ?? this.allProducts,
      selectedGroupId: clearGroupId ? null : (selectedGroupId ?? this.selectedGroupId),
      selectedCategoryId: clearCategoryId ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedSubcategoryId: clearSubcategoryId ? null : (selectedSubcategoryId ?? this.selectedSubcategoryId),
      selectedUnitId: clearUnitId ? null : (selectedUnitId ?? this.selectedUnitId),
      selectedSupplierId: clearSupplierId ? null : (selectedSupplierId ?? this.selectedSupplierId),
      selectedCurrencyId: clearCurrencyId ? null : (selectedCurrencyId ?? this.selectedCurrencyId),
      selectedWarehouseId: clearWarehouseId ? null : (selectedWarehouseId ?? this.selectedWarehouseId),
      selectedBonusFreeProductId: clearBonusFreeId ? null : (selectedBonusFreeProductId ?? this.selectedBonusFreeProductId),
      selectedExpiryDate: clearExpiryDate ? null : (selectedExpiryDate ?? this.selectedExpiryDate),
    );
  }
}

final addProductProvider = AutoDisposeNotifierProvider<AddProductNotifier, AddProductState>(AddProductNotifier.new);

class AddProductNotifier extends AutoDisposeNotifier<AddProductState> {
  @override
  AddProductState build() {
    return AddProductState();
  }

  // 🎯 جلب كافة البيانات المبدئية
  Future<Map<String, dynamic>?> loadInitialData(Map<String, dynamic>? initialProduct) async {
    state = state.copyWith(isLoading: true);
    final db = ref.read(databaseHelperProvider);

    // استخدام Future.wait لتحسين الأداء (جلب البيانات بالتوازي)
    final results = await Future.wait([
      db.getAllGroups(),
      db.getAllUnits(),
      db.getAllSuppliers(),
      db.getAllCurrencies(),
      db.getAllWarehouses(),
      db.getAllProductsWithDetails(),
    ]);

    final groups = results[0] as List<Map<String, dynamic>>;
    final units = results[1] as List<Map<String, dynamic>>;
    final suppliers = results[2] as List<Map<String, dynamic>>;
    final currencies = results[3] as List<Map<String, dynamic>>;
    final warehouses = results[4] as List<Map<String, dynamic>>;
    final allProducts = results[5] as List<Map<String, dynamic>>;

    int? defaultWarehouseId = warehouses.firstWhere((w) => w['is_default'] == 1, orElse: () => <String, dynamic>{})['id'] as int?;
    if (defaultWarehouseId == null && warehouses.isNotEmpty) defaultWarehouseId = warehouses.first['id'] as int;

    int? defaultUnitId = units.firstWhere((u) => u['is_default'] == 1, orElse: () => <String, dynamic>{})['id'] as int?;
    if (defaultUnitId == null && units.isNotEmpty) defaultUnitId = units.first['id'] as int;

    int? defaultCurrencyId = currencies.firstWhere((c) => c['is_default'] == 1, orElse: () => <String, dynamic>{})['id'] as int?;
    if (defaultCurrencyId == null && currencies.isNotEmpty) defaultCurrencyId = currencies.first['id'] as int;

    state = state.copyWith(
      groups: groups, units: units, suppliers: suppliers,
      currencies: currencies, warehouses: warehouses, allProducts: allProducts,
      selectedWarehouseId: defaultWarehouseId,
      selectedUnitId: defaultUnitId,
      selectedCurrencyId: defaultCurrencyId,
    );

    if (initialProduct != null) {
      final productId = (initialProduct['id'] as num).toInt();
      final freshProduct = await db.getProductById(productId) ?? initialProduct;

      int? subCatId = (freshProduct['subcategory_id'] as num?)?.toInt();
      int? currentGroupId;
      int? currentCategoryId;
      List<Map<String, dynamic>> loadedCategories = [];
      List<Map<String, dynamic>> loadedSubcategories = [];

      if (subCatId != null) {
        final subDetails = await db.rawQuery('SELECT category_id FROM subcategories WHERE id = ?', [subCatId]);
        if (subDetails.isNotEmpty) {
          currentCategoryId = (subDetails.first['category_id'] as num).toInt();
          final catDetails = await db.rawQuery('SELECT group_id FROM categories WHERE id = ?', [currentCategoryId]);
          if (catDetails.isNotEmpty) {
            currentGroupId = (catDetails.first['group_id'] as num).toInt();
            loadedCategories = await db.getCategoriesByGroup(currentGroupId);
            loadedSubcategories = await db.getSubcategoriesByCategory(currentCategoryId);
          }
        }
      }

      final isBonus = (freshProduct['bonus_enabled'] as num?)?.toInt() == 1;
      DateTime? expiry;
      if (freshProduct['expiry_date'] != null) {
        try { expiry = DateTime.parse(freshProduct['expiry_date'].toString()); } catch (_) {}
      }

      state = state.copyWith(
        selectedGroupId: currentGroupId,
        categories: loadedCategories,
        selectedCategoryId: currentCategoryId,
        subcategories: loadedSubcategories,
        selectedSubcategoryId: subCatId,
        selectedUnitId: (freshProduct['unit_id'] as num?)?.toInt() ?? state.selectedUnitId,
        selectedSupplierId: (freshProduct['supplier_id'] as num?)?.toInt(),
        selectedCurrencyId: (freshProduct['currency_id'] as num?)?.toInt() ?? state.selectedCurrencyId,
        selectedWarehouseId: (freshProduct['warehouse_id'] as num?)?.toInt() ?? state.selectedWarehouseId,
        selectedExpiryDate: expiry,
        isBonusEnabled: isBonus,
        selectedBonusFreeProductId: (freshProduct['bonus_free_product_id'] as num?)?.toInt(),
        isLoading: false,
      );

      final pricesRecords = await db.getProductPrices(productId);
      Map<int, double> initialPrices = {};
      int? defPriceUnitId;
      for (var p in pricesRecords) {
        final uid = (p['unit_id'] as num).toInt();
        initialPrices[uid] = (p['price'] as num).toDouble();
        if ((p['is_default'] as num).toInt() == 1) defPriceUnitId = uid;
      }

      return {
        'product': freshProduct,
        'prices': initialPrices,
        'defaultUnitId': defPriceUnitId,
      };
    }

    state = state.copyWith(isLoading: false);
    return null;
  }

  // 🎯 التحكم المباشر بالواجهة (بديل Rx Variables في GetX)
  void toggleNewGroup(bool val) => state = state.copyWith(isAddingNewGroup: val);
  void toggleUnitPrices() => state = state.copyWith(showUnitPrices: !state.showUnitPrices);
  void toggleBonus(bool val) {state = state.copyWith(isBonusEnabled: val, clearBonusFreeId: !val,);}  void setExpiryDate(DateTime? date) => state = state.copyWith(selectedExpiryDate: date, clearExpiryDate: date == null);
  void setWarehouse(int? id) => state = state.copyWith(selectedWarehouseId: id, clearWarehouseId: id == null);
  void setSupplier(int? id) => state = state.copyWith(selectedSupplierId: id, clearSupplierId: id == null);
  void setUnit(int? id) => state = state.copyWith(selectedUnitId: id, clearUnitId: id == null);
  void setBonusProduct(int? id) => state = state.copyWith(selectedBonusFreeProductId: id, clearBonusFreeId: id == null);

  // 🎯 عمليات الإضافة الحية (Inline Additions)
  Future<void> addNewGroup(String name) async {
    state = state.copyWith(isLoading: true);
    final db = ref.read(databaseHelperProvider);
    final id = await db.insertGroup({'name': name, 'description': ''});
    final groups = await db.getAllGroups();
    final categories = await db.getCategoriesByGroup(id);
    state = state.copyWith(
        groups: groups, selectedGroupId: id, isAddingNewGroup: false,
        clearCategoryId: true, clearSubcategoryId: true, categories: categories, subcategories: [], isLoading: false
    );
  }

  Future<void> addNewCategory(String name, int groupId) async {
    state = state.copyWith(isLoading: true);
    final db = ref.read(databaseHelperProvider);
    await db.insertCategory({'name': name, 'description': '', 'group_id': groupId});
    final categories = await db.getCategoriesByGroup(groupId);
    state = state.copyWith(categories: categories, isLoading: false);
  }

  Future<void> addNewSubcategory(String name, int categoryId) async {
    state = state.copyWith(isLoading: true);
    final db = ref.read(databaseHelperProvider);
    await db.insertSubcategory({'name': name, 'description': '', 'category_id': categoryId});
    final subcategories = await db.getSubcategoriesByCategory(categoryId);
    state = state.copyWith(subcategories: subcategories, isLoading: false);
  }

  Future<void> loadCategories(int groupId) async {
    state = state.copyWith(selectedGroupId: groupId, clearCategoryId: true, clearSubcategoryId: true, categories: [], subcategories: [], isLoading: true);
    final db = ref.read(databaseHelperProvider);
    final categories = await db.getCategoriesByGroup(groupId);
    state = state.copyWith(categories: categories, isLoading: false);
  }

  Future<void> loadSubcategories(int categoryId) async {
    state = state.copyWith(selectedCategoryId: categoryId, clearSubcategoryId: true, subcategories: [], isLoading: true);
    final db = ref.read(databaseHelperProvider);
    final subcategories = await db.getSubcategoriesByCategory(categoryId);
    state = state.copyWith(subcategories: subcategories, isLoading: false);
  }

  void setSubcategory(int subId) => state = state.copyWith(selectedSubcategoryId: subId);

  // 🎯 الحفظ في قاعدة البيانات
  Future<Map<String, dynamic>> saveProduct({
    required bool isEditing, required int? editingProductId, required Map<String, dynamic> payload,
    required Map<int, double> unitPrices, required int? defaultUnitPriceId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final db = ref.read(databaseHelperProvider);
      int productId;

      if (isEditing && editingProductId != null) {
        productId = editingProductId;
        await db.updateProduct(productId, payload);
      } else {
        payload['created_at'] = DateTime.now().toIso8601String();
        productId = await db.insertProduct(payload);
      }

      for (final uid in state.units.map((u) => (u['id'] as num).toInt())) {
        if (unitPrices.containsKey(uid)) {
          final price = unitPrices[uid]!;
          final existingId = await db.getProductPriceId(productId, uid);
          final isDefault = (uid == defaultUnitPriceId) ? 1 : 0;
          if (existingId != null) {
            await db.updateProductPrice(existingId, price);
            if (isDefault == 1) await db.setDefaultProductPrice(productId, uid);
          } else {
            await db.insertProductPrice({'product_id': productId, 'unit_id': uid, 'price': price, 'is_default': isDefault});
          }
        }
      }

      state = state.copyWith(isLoading: false);
      return {'success': true};
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return {'success': false, 'error': e.toString()};
    }
  }
}