// lib/modules/loans/widgets/loan_filter.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LoanFilterBar extends StatelessWidget {
  final String selectedType;
  final String selectedStatus;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;

  const LoanFilterBar({
    super.key,
    required this.selectedType,
    required this.selectedStatus,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'النوع',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('جميع الأطراف')),
                DropdownMenuItem(value: 'customer', child: Text('عملاء فقط')),
                DropdownMenuItem(value: 'supplier', child: Text('موردون فقط')),
              ],
              onChanged: (val) {
                if (val != null) onTypeChanged(val);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                DropdownMenuItem(value: 'active', child: Text('نشطة')),
                DropdownMenuItem(value: 'paid', child: Text('مسددة')),
              ],
              onChanged: (val) {
                if (val != null) onStatusChanged(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
