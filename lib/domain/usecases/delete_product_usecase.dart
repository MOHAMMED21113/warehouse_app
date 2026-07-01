import '../repositories/product_repository.dart';

class DeleteProductUseCase {
  final ProductRepository repository;

  DeleteProductUseCase(this.repository);

  Future<Map<String, dynamic>> call(int id) async {
    return await repository.deleteProductSafe(id);
  }
}