// lib/domain/entities/customer_level_entity.dart
class CustomerLevelEntity {
  final int? id;
  final String name;
  final double minTotalPurchases;
  final double discountPercent;
  final String color;

  const CustomerLevelEntity({
    this.id,
    required this.name,
    required this.minTotalPurchases,
    required this.discountPercent,
    required this.color,
  });
}