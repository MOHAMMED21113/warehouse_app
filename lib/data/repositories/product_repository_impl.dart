// lib/data/repositories/product_repository_impl.dart
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalDataSource dataSource;

  ProductRepositoryImpl(this.dataSource);

  @override
  Future<(List<ProductEntity>, int)> getProductsPaginated({
    required int page,
    required int limit,
    String? searchQuery,
    bool? isActive,
  }) async {
    return await dataSource.getProductsPaginated(
      page: page,
      limit: limit,
      searchQuery: searchQuery,
      isActive: isActive,
    );
  }

  @override
  Future<ProductEntity?> searchProductByAnyBarcode(String barcode) async {
    return await dataSource.searchProductByAnyBarcode(barcode);
  }

  @override
  Future<ProductEntity?> getProductById(int id) async {
    return await dataSource.getProductById(id);
  }

  @override
  Future<int> insertProduct(ProductEntity product) async {
    return await dataSource.insertProduct(product);
  }

  @override
  Future<void> updateProduct(ProductEntity product) async {
    await dataSource.updateProduct(product);
  }

  @override
  Future<Map<String, dynamic>> deleteProductSafe(int id) async {
    return await dataSource.deleteProductSafe(id);
  }
}