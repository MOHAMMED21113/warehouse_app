// lib/domain/repositories/product_repository.dart

import '../entities/product_entity.dart';

abstract class ProductRepository {
  Future<(List<ProductEntity>, int)> getProductsPaginated({
    required int page,
    required int limit,
    String? searchQuery,
    bool? isActive,
  });

  Future<ProductEntity?> searchProductByAnyBarcode(String barcode);

  Future<ProductEntity?> getProductById(int id);

  Future<int> insertProduct(ProductEntity product);

  Future<void> updateProduct(ProductEntity product);

  Future<Map<String, dynamic>> deleteProductSafe(int id);
}