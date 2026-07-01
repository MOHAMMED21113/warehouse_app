// lib/core/widgets/custom_responsive_row.dart

import 'package:flutter/material.dart';

/// 🚀 مكوّن مخصص لصف البيانات (Row) يمنع الـ RenderFlex Overflow تلقائياً للنصوص الطويلة
class CustomResponsiveRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const CustomResponsiveRow({
    super.key,
    required this.leading,
    required this.trailing,
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = EdgeInsets.zero,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(
            child: DefaultTextStyle.merge(
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              child: leading,
            ),
          ),
          SizedBox(width: spacing),
          DefaultTextStyle.merge(
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            child: trailing,
          ),
        ],
      ),
    );
  }
}
