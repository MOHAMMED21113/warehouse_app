// lib/modules/products/providers/batches_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';

final productBatchesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, productId) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getProductBatches(productId);
});
