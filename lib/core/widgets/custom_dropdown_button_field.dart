// lib/core/widgets/custom_dropdown_button_field.dart

import 'package:flutter/material.dart';

/// 🚀 مكوّن مخصص لحقول القوائم المنسدلة يمنع الـ RenderFlex Overflow تلقائياً
class CustomDropdownButtonFormField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final FormFieldValidator<T>? validator;
  final Widget? hint;
  final Widget? disabledHint;
  final double? menuMaxHeight;

  const CustomDropdownButtonFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.decoration,
    this.validator,
    this.hint,
    this.disabledHint,
    this.menuMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item.value,
            child: DefaultTextStyle.merge(
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              child: item.child,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        isExpanded: true, // ✅ منع الـ overflow داخلياً
        decoration: decoration ?? const InputDecoration(border: OutlineInputBorder()),
        validator: validator,
        hint: hint,
        disabledHint: disabledHint,
        menuMaxHeight: menuMaxHeight ?? 300,
      ),
    );
  }
}
