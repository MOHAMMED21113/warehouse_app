import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProductsPaginatedUseCase {
  final ProductRepository repository;

  GetProductsPaginatedUseCase(this.repository);

  Future<(List<ProductEntity>, int)> call({
    required int page,
    required int limit,
    String? searchQuery,
    bool? isActive,
  }) async {
    return await repository.getProductsPaginated(
      page: page,
      limit: limit,
      searchQuery: searchQuery,
      isActive: isActive,
    );
  }
}