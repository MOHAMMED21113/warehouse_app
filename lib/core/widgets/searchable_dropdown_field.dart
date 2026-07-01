// lib/core/widgets/searchable_dropdown_field.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SearchableDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String label;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final bool isEnabled;

  const SearchableDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.isEnabled = true,
  });

  @override
  State<SearchableDropdownField<T>> createState() => _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T> extends State<SearchableDropdownField<T>> {
  late TextEditingController _displayController;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(text: _getLabel(widget.value));
  }

  @override
  void didUpdateWidget(covariant SearchableDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLabel = _getLabel(widget.value);
    if (_displayController.text != newLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _displayController.text != newLabel) {
          _displayController.text = newLabel;
        }
      });
    }
  }

  @override
  void dispose() {
    _displayController.dispose();
    super.dispose();
  }

  String _getLabel(T? val) {
    if (val == null) return '';
    try {
      return widget.itemLabel(val);
    } catch (_) {
      return '';
    }
  }

  void _openSearchSheet() async {
    if (!widget.isEnabled) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.navyCard : Colors.white;
    final cardBorder = isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppColors.textPrimary : AppColors.navy;
    final textSub = isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final inputFill = isDark ? AppColors.navyLight : Colors.white;

    final selectedItem = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredList = widget.items.where((item) {
              if (query.isEmpty) return true;
              return widget.itemLabel(item).toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: textSub.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(widget.prefixIcon, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بحث واختيار: ${widget.label}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
                        ),
                      ),
                      if (widget.suffixIcon != null) widget.suffixIcon!,
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    autofocus: true,
                    style: TextStyle(color: textMain, fontSize: 14),
                    onChanged: (val) {
                      setSheetState(() => query = val);
                    },
                    decoration: InputDecoration(
                      hintText: 'اكتب للبحث داخل ${widget.label}...',
                      hintStyle: TextStyle(color: textSub, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: textSub),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: textSub, size: 18),
                              onPressed: () => setSheetState(() => query = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'النتائج (${filteredList.length})',
                        style: TextStyle(fontSize: 12, color: textSub, fontWeight: FontWeight.w600),
                      ),
                      if (widget.value != null)
                        TextButton.icon(
                          onPressed: () => Navigator.pop(ctx, null),
                          icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.error),
                          label: const Text('إلغاء الاختيار الحالي', style: TextStyle(color: AppColors.error, fontSize: 12)),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: textSub.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text('لا توجد نتائج مطابقة لبحثك "$query"', style: TextStyle(color: textSub)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              final label = widget.itemLabel(item);
                              final isSelected = widget.value == item;
                              return ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                tileColor: isSelected ? AppColors.primary.withOpacity(0.12) : null,
                                leading: Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? AppColors.primary : textSub,
                                ),
                                title: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.primary : textMain,
                                    fontWeight: isBoldOrSelected(isSelected),
                                  ),
                                ),
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // If modal returned an item or null (clear), trigger onChanged
    if (selectedItem != widget.value) {
      widget.onChanged(selectedItem);
    }
  }

  FontWeight isBoldOrSelected(bool selected) => selected ? FontWeight.bold : FontWeight.normal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBorder = isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
    final textMain = isDark ? AppColors.textPrimary : AppColors.navy;
    final textSub = isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final inputFill = isDark ? AppColors.navyLight : Colors.white;

    return TextFormField(
      controller: _displayController,
      readOnly: true,
      onTap: widget.isEnabled ? _openSearchSheet : null,
      style: TextStyle(color: widget.isEnabled ? textMain : textSub, fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText ?? 'اختر أو ابحث عن ${widget.label}...',
        prefixIcon: Icon(widget.prefixIcon, color: widget.isEnabled ? AppColors.primary : textSub, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.value != null && widget.isEnabled)
              IconButton(
                icon: Icon(Icons.clear_rounded, color: textSub, size: 18),
                onPressed: () => widget.onChanged(null),
              ),
            if (widget.suffixIcon != null) widget.suffixIcon!,
            IconButton(
              icon: Icon(Icons.arrow_drop_down_circle_outlined, color: widget.isEnabled ? AppColors.primary : textSub, size: 20),
              onPressed: widget.isEnabled ? _openSearchSheet : null,
            ),
            const SizedBox(width: 4),
          ],
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(color: textSub, fontSize: 13),
        hintStyle: TextStyle(color: textSub.withOpacity(0.7), fontSize: 13),
      ),
    );
  }
}
