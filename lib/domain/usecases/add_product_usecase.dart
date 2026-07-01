import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class AddProductUseCase {
  final ProductRepository repository;

  AddProductUseCase(this.repository);

  Future<int> call(ProductEntity product) async {
    return await repository.insertProduct(product);
  }
}