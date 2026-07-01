import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class SearchProductByBarcodeUseCase {
  final ProductRepository repository;

  SearchProductByBarcodeUseCase(this.repository);

  Future<ProductEntity?> call(String barcode) async {
    return await repository.searchProductByAnyBarcode(barcode);
  }
}