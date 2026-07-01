// lib/domain/entities/loyalty_reward_entity.dart
class LoyaltyRewardEntity {
  final int? id;
  final String title;
  final double pointsRequired;
  final String rewardType; // 'discount_percent', 'free_product', 'free_product_qty', 'coupon', 'gift'
  final double rewardValue; // نسبة الخصم، قيمة الكوبون
  final int? productId;      // المنتج المجاني (في حال free_product)
  final bool isActive;
  final int expiryDays;

  // 🆕 الحقول الجديدة لنظام "اشتري X واحصل على Y"
  final int? buyProductId;    // المنتج الذي يجب شراؤه
  final int? freeProductId;   // المنتج المجاني الممنوح
  final int? requiredQuantity; // الكمية المطلوب شراؤها
  final int? freeQuantity;     // الكمية المجانية

  const LoyaltyRewardEntity({
    this.id,
    required this.title,
    required this.pointsRequired,
    required this.rewardType,
    required this.rewardValue,
    this.productId,
    required this.isActive,
    required this.expiryDays,
    this.buyProductId,
    this.freeProductId,
    this.requiredQuantity,
    this.freeQuantity,
  });
}