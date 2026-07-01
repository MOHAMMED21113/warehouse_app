// lib/modules/loans/widgets/loan_card.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final VoidCallback? onPaymentPressed;
  final VoidCallback? onPrintPressed;
  final VoidCallback? onTap;

  const LoanCard({
    super.key,
    required this.loan,
    this.onPaymentPressed,
    this.onPrintPressed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = loan['status']?.toString() ?? 'active';
    final rem = (loan['remaining_balance'] as num?)?.toDouble() ?? 0.0;
    final total = (loan['amount'] as num?)?.toDouble() ?? 0.0;
    final type = loan['loan_type']?.toString() == 'customer' ? 'عميل' : 'مورد';

    Color cardBorder;
    String statusText;
    if (status == 'paid') {
      cardBorder = AppColors.success;
      statusText = 'مسددة بالكامل';
    } else if (rem > 0) {
      cardBorder = AppColors.warning;
      statusText = 'نشطة (متبقي)';
    } else {
      cardBorder = AppColors.error;
      statusText = 'متأخرة';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${loan['party_name']} ($type)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardBorder.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: cardBorder, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onPrintPressed != null)
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: AppColors.primary),
                      onPressed: onPrintPressed,
                      tooltip: 'طباعة إذن السلفة',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المبلغ الأصلي: ${total.toStringAsFixed(2)} ﷼', style: const TextStyle(fontSize: 14)),
                  Text(
                    'المتبقي: ${rem.toStringAsFixed(2)} ﷼',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: rem > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تاريخ السلفة: ${loan['loan_date'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  if (loan['due_date'] != null)
                    Text('الاستحقاق: ${loan['due_date']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              if (rem > 0 && onPaymentPressed != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: onPaymentPressed,
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('سداد دفعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
