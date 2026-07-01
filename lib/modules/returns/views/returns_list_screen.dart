// lib/modules/returns/views/returns_list_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/invoice_printer.dart';
import '../../../database/database_helper.dart';

class ReturnsListScreen extends ConsumerStatefulWidget {
  const ReturnsListScreen({super.key});

  @override
  ConsumerState<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends ConsumerState<ReturnsListScreen> with SingleTickerProviderStateMixin {
  final db = DatabaseHelper.instance;
  late TabController _tabController;

  // ==================== State Variables ====================
  List<Map<String, dynamic>> _salesReturns = [];
  List<Map<String, dynamic>> _purchaseReturns = [];
  List<Map<String, dynamic>> _personsList = [];
  final Map<int, List<Map<String, dynamic>>> _returnItems = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  String _activeFilter = 'الكل'; // 'الكل', 'كاش', 'آجل', 'شبكة'
  String _sortMode = 'الأحدث'; // 'الأحدث', 'الأقدم', 'الأعلى مبلغاً', 'الأقل مبلغاً'
  DateTimeRange? _selectedDateRange;
  int? _selectedPersonId;
  String? _selectedPersonName;

  bool _isMultiSelectMode = false;
  final Set<int> _selectedIds = {};
  int _expandedId = -1;

  static const Color _salesAccent = Color(0xFF10B981);
  static const Color _purchaseAccent = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeFilter = 'الكل';
          _selectedIds.clear();
          _expandedId = -1;
          _selectedPersonId = null;
          _selectedPersonName = null;
        });
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ==================== Helper Methods ====================
  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        backgroundColor: color.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatNumber(double amount) {
    if (amount % 1 == 0) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  String _formatCompact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 10000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return _formatNumber(amount);
  }

  // ==================== Logic Methods ====================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await db.getSalesReturnsPaginated(page: 1, limit: 500);
      final purchases = await db.getPurchaseReturnsPaginated(page: 1, limit: 500);
      final isSales = _tabController.index == 0;
      final persons = isSales ? await db.getAllCustomers() : await db.getAllSuppliers();
      setState(() {
        _salesReturns = sales;
        _purchaseReturns = purchases;
        _personsList = persons;
        _selectedIds.clear();
      });
    } catch (e) {
      _showSnackBar('فشل تحميل البيانات: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReturnItems(int returnId, bool isSales) async {
    if (_returnItems.containsKey(returnId)) {
      return;
    }
    try {
      final items = await db.rawQuery('''
        SELECT ri.*, p.name as product_name
        FROM ${isSales ? 'sales_return_items' : 'purchase_return_items'} ri
        JOIN products p ON ri.product_id = p.id
        WHERE ri.return_id = ?
      ''', [returnId]);
      if (mounted) {
        setState(() {
          _returnItems[returnId] = items;
        });
      }
    } catch (e) {
      debugPrint('Error loading return items: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredList() {
    final isSales = _tabController.index == 0;
    final currentList = isSales ? _salesReturns : _purchaseReturns;
    var list = currentList.where((item) {
      if (_searchQuery.isNotEmpty) {
        final num = item['return_number']?.toString().toLowerCase() ?? '';
        final name = isSales ? (item['customer_name'] ?? '') : (item['supplier_name'] ?? '');
        if (!num.contains(_searchQuery) && !name.toString().toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }
      if (_activeFilter != 'الكل') {
        final rType = item['refund_type']?.toString() ?? 'كاش';
        if (rType != _activeFilter) {
          return false;
        }
      }
      if (_selectedPersonId != null) {
        final pid = isSales ? item['customer_id'] : item['supplier_id'];
        if (pid != _selectedPersonId) {
          return false;
        }
      }
      if (_selectedDateRange != null) {
        final dateStr = item['return_date']?.toString().substring(0, 10) ?? '';
        final itemDate = DateTime.tryParse(dateStr);
        if (itemDate != null) {
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
          if (itemDate.isBefore(start) || itemDate.isAfter(end)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (_sortMode == 'الأحدث') {
        return (b['return_date'] ?? '').toString().compareTo((a['return_date'] ?? '').toString());
      } else if (_sortMode == 'الأقدم') {
        return (a['return_date'] ?? '').toString().compareTo((b['return_date'] ?? '').toString());
      } else if (_sortMode == 'الأعلى مبلغاً') {
        final amtA = (a['total_amount'] as num?)?.toDouble() ?? 0.0;
        final amtB = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
        return amtB.compareTo(amtA);
      } else if (_sortMode == 'الأقل مبلغاً') {
        final amtA = (a['total_amount'] as num?)?.toDouble() ?? 0.0;
        final amtB = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
        return amtA.compareTo(amtB);
      }
      return 0;
    });

    return list;
  }

  void _toggleSelectAll() {
    final filtered = _getFilteredList();
    setState(() {
      if (_selectedIds.length == filtered.length && filtered.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(filtered.map((e) => e['id'] as int));
      }
    });
  }

  Future<void> _pickDateRange() async {
    final isSales = _tabController.index == 0;
    final dark = ref.read(themeModeProvider) == ThemeMode.dark;
    final cardBg = dark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = dark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
    final textSub = dark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    final textHint = dark ? Colors.white38 : const Color(0xFF94A3B8);
    final inputFill = dark ? AppColors.navyLight : Colors.white;
    final accentColor = isSales ? _salesAccent : _purchaseAccent;

    DateTime tempStart = _selectedDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime tempEnd = _selectedDateRange?.end ?? DateTime.now();

    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: textHint.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text('تحديد نطاق التاريخ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تاريخ البدء:', style: TextStyle(color: textSub, fontWeight: FontWeight.bold)),
                    Text(DateFormat('yyyy/MM/dd').format(tempStart), style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder)),
                  child: _NumericDatePicker(
                    initialDate: tempStart,
                    textColor: textMain,
                    accentColor: accentColor,
                    onDateTimeChanged: (newDate) {
                      setSheetState(() {
                        tempStart = newDate;
                        if (tempEnd.isBefore(tempStart)) {
                          tempEnd = tempStart;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تاريخ الانتهاء:', style: TextStyle(color: textSub, fontWeight: FontWeight.bold)),
                    Text(DateFormat('yyyy/MM/dd').format(tempEnd), style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder)),
                  child: _NumericDatePicker(
                    initialDate: tempEnd,
                    textColor: textMain,
                    accentColor: accentColor,
                    onDateTimeChanged: (newDate) {
                      setSheetState(() => tempEnd = newDate);
                    },
                  ),
                ),
                const SizedBox(height: 30),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(foregroundColor: textSub, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: cardBorder)),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (tempEnd.isBefore(tempStart)) {
                          _showSnackBar('تاريخ الانتهاء لا يمكن أن يكون قبل تاريخ البدء', AppColors.error);
                          return;
                        }
                        Navigator.pop(ctx, DateTimeRange(start: tempStart, end: tempEnd));
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('تطبيق الفلتر', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ]),
              ],
            ),
          );
        });
      },
    );

    if (result != null) {
      setState(() => _selectedDateRange = result);
    }
  }

  Future<void> _pickPersonFilter() async {
    final isSales = _tabController.index == 0;
    final dark = ref.read(themeModeProvider) == ThemeMode.dark;
    final cardBg = dark ? AppColors.darkCardColor : Colors.white;
    final textMain = dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
    final textHint = dark ? Colors.white38 : const Color(0xFF94A3B8);
    final inputFill = dark ? AppColors.navyLight : Colors.white;
    final accentColor = isSales ? _salesAccent : _purchaseAccent;

    if (_personsList.isEmpty) {
      _showSnackBar(isSales ? 'لا يوجد عملاء مسجلين' : 'لا يوجد موردين مسجلين', AppColors.warning);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (context, setSheetState) {
          final filtered = _personsList.where((p) {
            if (query.isEmpty) {
              return true;
            }
            return (p['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: textHint.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text(isSales ? 'تحديد العميل لعرض مرتجعاته' : 'تحديد المورد لعرض مرتجعاته', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain)),
                const SizedBox(height: 12),
                TextField(
                  style: TextStyle(color: textMain),
                  onChanged: (v) => setSheetState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم...',
                    hintStyle: TextStyle(color: textHint),
                    prefixIcon: Icon(Icons.search, color: textHint),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.clear_all_rounded, color: AppColors.error),
                  title: const Text('عرض مرتجعات الكل', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  onTap: () {
                    setState(() {
                      _selectedPersonId = null;
                      _selectedPersonName = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return ListTile(
                        leading: Icon(Icons.person_rounded, color: accentColor),
                        title: Text(p['name'] ?? '', style: TextStyle(color: textMain, fontWeight: FontWeight.bold)),
                        onTap: () {
                          setState(() {
                            _selectedPersonId = p['id'] as int;
                            _selectedPersonName = p['name'] as String;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _editReturn(Map<String, dynamic> item) async {
    final isSales = _tabController.index == 0;
    final dark = ref.read(themeModeProvider) == ThemeMode.dark;
    final cardBg = dark ? AppColors.darkCardColor : Colors.white;
    final textMain = dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
    final inputFill = dark ? AppColors.navyLight : Colors.white;
    final accentColor = isSales ? _salesAccent : _purchaseAccent;

    final table = isSales ? 'sales_returns' : 'purchase_returns';
    final notesController = TextEditingController(text: item['notes']?.toString() ?? '');
    final refundController = TextEditingController(text: (item['refund_amount'] ?? item['total_amount'] ?? 0).toString());
    String selectedRefundType = item['refund_type']?.toString() ?? 'كاش';
    if (!['كاش', 'آجل', 'شبكة'].contains(selectedRefundType)) {
      selectedRefundType = 'كاش';
    }
    final total = (item['total_amount'] as num?)?.toDouble() ?? 0.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('تعديل بيانات المرتجع رقم ${item['return_number']}', style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإجمالي: ${_formatNumber(total)} ﷼', style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRefundType,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(labelText: 'طريقة الاسترداد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: inputFill),
                    items: ['كاش', 'آجل', 'شبكة'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: textMain)))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedRefundType = v;
                          if (v == 'آجل') {
                            refundController.text = '0';
                          } else {
                            refundController.text = total.toString();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refundController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(labelText: 'المبلغ المسترد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: inputFill),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: TextStyle(color: textMain),
                    decoration: InputDecoration(labelText: 'الملاحظات', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: inputFill),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      final newRefund = double.tryParse(refundController.text.trim()) ?? total;
      final database = await db.database;
      await database.update(
        table,
        {
          'refund_type': selectedRefundType,
          'refund_amount': newRefund,
          'notes': notesController.text.trim(),
        },
        where: 'id = ?',
        whereArgs: [item['id']],
      );
      _showSnackBar('تم حفظ التعديلات بنجاح', AppColors.success);
      _loadData();
    }
  }

  Future<void> _deleteReturn(Map<String, dynamic> item) async {
    final isSales = _tabController.index == 0;
    final table = isSales ? 'sales_returns' : 'purchase_returns';
    final itemsTable = isSales ? 'sales_return_items' : 'purchase_return_items';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text('هل أنت متأكد من حذف المرتجع رقم ${item['return_number']}؟ لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final database = await db.database;
      await database.delete(itemsTable, where: 'return_id = ?', whereArgs: [item['id']]);
      await database.delete(table, where: 'id = ?', whereArgs: [item['id']]);
      _showSnackBar('تم حذف المرتجع بنجاح', AppColors.success);
      _loadData();
    }
  }

  Future<void> _exportPdfReport() async {
    final filtered = _getFilteredList();
    final toExport = _selectedIds.isNotEmpty
        ? filtered.where((item) => _selectedIds.contains(item['id'] as int)).toList()
        : filtered;

    if (toExport.isEmpty) {
      _showSnackBar('لا توجد بيانات لتصدير الـ PDF', AppColors.warning);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final isSales = _tabController.index == 0;
      final mappedInvoices = toExport.map((ret) {
        return {
          'invoice_number': ret['return_number'] ?? '---',
          'date': ret['return_date'],
          'customer_name': ret['customer_name'] ?? 'عميل عام',
          'supplier_name': ret['supplier_name'] ?? 'مورد عام',
          'total_amount': ret['total_amount'] ?? 0.0,
          'paid_amount': ret['total_amount'] ?? 0.0,
          'payment_status': ret['refund_type'] ?? 'كاش',
        };
      }).toList();

      final totalAmt = toExport.fold<double>(0.0, (sum, item) => sum + ((item['total_amount'] as num?)?.toDouble() ?? 0.0));

      String? dateRangeStr;
      if (_selectedDateRange != null) {
        dateRangeStr = '${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}';
      }

      await InvoicePrinter.printInvoicesReport(
        invoices: mappedInvoices,
        reportTitle: isSales ? 'سجل مرتجعات المبيعات' : 'سجل مرتجعات المشتريات',
        isSales: isSales,
        totalAmount: totalAmt,
        paidAmount: totalAmt,
        unpaidAmount: 0.0,
        personFilterName: _selectedPersonName,
        dateRangeStr: dateRangeStr,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnackBar('فشل تصدير الـ PDF: $e', AppColors.error);
    }
  }

  Future<void> _printReturn(Map<String, dynamic> item, bool isSales) async {
    final returnId = item['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final fullData = isSales
          ? await db.getFullSalesReturnData(returnId)
          : await db.getFullPurchaseReturnData(returnId);
      final itemsList = List<Map<String, dynamic>>.from(fullData['items'] as List);

      if (isSales) {
        await InvoicePrinter.printSalesReturnInvoice(
          returnData: fullData,
          items: itemsList,
        );
      } else {
        await InvoicePrinter.printPurchaseReturnInvoice(
          returnData: fullData,
          items: itemsList,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
      _showSnackBar('تمت طباعة الفاتورة بنجاح', AppColors.success);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnackBar('فشل الطباعة: $e', AppColors.error);
    }
  }

  void _exportToExcel() async {
    final isSales = _tabController.index == 0;
    final currentData = isSales ? _salesReturns : _purchaseReturns;

    if (currentData.isEmpty) {
      _showSnackBar('لا توجد بيانات للتصدير', AppColors.warning);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final exportService = ExcelExportService();
      final result = isSales
          ? await exportService.exportSalesReturnsToExcel()
          : await exportService.exportPurchaseReturnsToExcel();

      if (mounted) {
        Navigator.pop(context);
      }

      if (result['success']) {
        _showSnackBar('تم حفظ الملف بنجاح', AppColors.success);
      } else {
        _showSnackBar(result['error'] ?? 'فشل التصدير', AppColors.error);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnackBar(e.toString(), AppColors.error);
    }
  }

  // ==================== Build UI ====================
  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isSales = _tabController.index == 0;
    final accentColor = isSales ? _salesAccent : _purchaseAccent;
    final cardBg = dark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = dark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final filtered = _getFilteredList();

    return Scaffold(
      backgroundColor: dark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: dark ? AppColors.navyMedium : AppColors.navy,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('سجل المرتجعات', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        actions: [
          IconButton(
            icon: Icon(_isMultiSelectMode ? Icons.checklist_rtl_rounded : Icons.checklist_rounded, color: _isMultiSelectMode ? accentColor : AppColors.primary),
            tooltip: 'تحديد متعدد والتصدير',
            onPressed: () {
              setState(() {
                _isMultiSelectMode = !_isMultiSelectMode;
                if (!_isMultiSelectMode) {
                  _selectedIds.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.primary, size: 22),
            color: dark ? AppColors.navyMedium : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) => setState(() => _sortMode = v),
            itemBuilder: (_) => [
              _sortMenuItem('الأحدث', Icons.arrow_downward_rounded, _sortMode, accentColor, dark),
              _sortMenuItem('الأقدم', Icons.arrow_upward_rounded, _sortMode, accentColor, dark),
              _sortMenuItem('الأعلى مبلغاً', Icons.trending_up_rounded, _sortMode, accentColor, dark),
              _sortMenuItem('الأقل مبلغاً', Icons.trending_down_rounded, _sortMode, accentColor, dark),
            ],
          ),
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primary),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
                _searchQuery = '';
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'مرتجعات مبيعات', icon: Icon(Icons.sell)),
            Tab(text: 'مرتجعات مشتريات', icon: Icon(Icons.shopping_cart)),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)))
          : Column(children: [
              if (_showSearch)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  color: dark ? AppColors.navyMedium.withValues(alpha: 0.5) : accentColor.withValues(alpha: 0.04),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isSales ? 'بحث برقم المرتجع أو اسم العميل...' : 'بحث برقم المرتجع أو اسم المورد...',
                      hintStyle: TextStyle(color: dark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: dark ? Colors.white38 : const Color(0xFF94A3B8), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: dark ? Colors.white38 : const Color(0xFF94A3B8), size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              })
                          : null,
                      filled: true,
                      fillColor: dark ? AppColors.navyLight : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),

              _buildStatsBar(filtered, accentColor),
              _buildFilterChips(accentColor, dark),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Icon(Icons.receipt_long_rounded, size: 14, color: dark ? Colors.white38 : const Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text('${filtered.length} مرتجع', style: TextStyle(fontSize: 12, color: dark ? AppColors.darkTextSecondary : const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('ترتيب: $_sortMode', style: TextStyle(fontSize: 11, color: dark ? Colors.white38 : const Color(0xFF94A3B8))),
                ]),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: accentColor,
                  backgroundColor: cardBg,
                  child: filtered.isEmpty
                      ? ListView(children: [
                          Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [Icon(Icons.filter_list_off_rounded, size: 40, color: dark ? Colors.white38 : const Color(0xFF94A3B8)), const SizedBox(height: 10), Text('لا توجد نتائج مطابقة للفلاتر', style: TextStyle(color: dark ? AppColors.darkTextSecondary : const Color(0xFF64748B), fontWeight: FontWeight.w500))]))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 300 + (index.clamp(0, 10) * 50)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Transform.translate(offset: Offset(0, 16 * (1 - value)), child: Opacity(opacity: value, child: child)),
                              child: _buildReturnCard(filtered[index], accentColor, dark),
                            );
                          },
                        ),
                ),
              ),
            ]),
      bottomNavigationBar: _isMultiSelectMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: cardBg, border: Border(top: BorderSide(color: cardBorder))),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _toggleSelectAll,
                    child: Text('تحديد الكل (${filtered.length})', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.import_export_rounded, size: 18),
                    label: const Text('Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _exportToExcel,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text('تصدير PDF (${_selectedIds.isNotEmpty ? _selectedIds.length : filtered.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _exportPdfReport,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  PopupMenuItem<String> _sortMenuItem(String label, IconData icon, String currentSort, Color accentColor, bool dark) {
    final isActive = currentSort == label;
    final textMain = dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
    final textSub = dark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    return PopupMenuItem(
      value: label,
      child: Row(children: [
        Icon(icon, size: 18, color: isActive ? accentColor : textSub),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: isActive ? accentColor : textMain, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        if (isActive) ...[const Spacer(), Icon(Icons.check_rounded, size: 16, color: accentColor)],
      ]),
    );
  }

  Widget _buildStatsBar(List<Map<String, dynamic>> list, Color accentColor) {
    double total = 0.0;
    double refunded = 0.0;
    double deferred = 0.0;

    for (var item in list) {
      final t = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
      total += t;
      final rType = item['refund_type']?.toString() ?? 'كاش';
      if (rType == 'آجل') {
        deferred += t;
      } else {
        final r = (item['refund_amount'] as num?)?.toDouble() ?? t;
        refunded += r;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        _statItem('الإجمالي', _formatCompact(total), AppColors.primary, Icons.monetization_on_rounded),
        _statDivider(),
        _statItem('المسترد', _formatCompact(refunded), AppColors.success, Icons.check_circle_rounded),
        _statDivider(),
        _statItem('الآجل', _formatCompact(deferred), AppColors.error, Icons.schedule_rounded),
        _statDivider(),
        _statItem('العدد', '${list.length}', accentColor, Icons.receipt_rounded),
      ]),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Expanded(child: Column(children: [Icon(icon, size: 16, color: color), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54))]));
  }

  Widget _statDivider() => Container(width: 1, height: 36, color: AppColors.primary.withValues(alpha: 0.2));

  Widget _buildFilterChips(Color accentColor, bool dark) {
    final filters = ['الكل', 'كاش', 'آجل', 'شبكة'];
    final filterColors = {'الكل': AppColors.primary, 'كاش': AppColors.success, 'آجل': AppColors.error, 'شبكة': _purchaseAccent};
    final filterIcons = {'الكل': Icons.list_rounded, 'كاش': Icons.money_rounded, 'آجل': Icons.schedule_rounded, 'شبكة': Icons.credit_card_rounded};
    final cardBg = dark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = dark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textSub = dark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    final textHint = dark ? Colors.white38 : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(children: [
        Row(children: [
          ...filters.map((f) {
            final isActive = _activeFilter == f;
            final color = filterColors[f] ?? AppColors.primary;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: f != filters.last ? 6 : 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _activeFilter = f),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: isActive ? color.withValues(alpha: 0.15) : cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? color.withValues(alpha: 0.5) : cardBorder, width: isActive ? 1.5 : 1)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(filterIcons[f], size: 13, color: isActive ? color : textHint), const SizedBox(width: 4), Flexible(child: Text(f, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? color : textSub), overflow: TextOverflow.ellipsis))],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _selectedDateRange != null ? accentColor.withValues(alpha: 0.08) : cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _selectedDateRange != null ? accentColor.withValues(alpha: 0.4) : cardBorder)),
                child: Row(children: [
                  Icon(Icons.date_range_rounded, size: 16, color: _selectedDateRange != null ? accentColor : textHint),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedDateRange != null ? '${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} — ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}' : 'فلترة بالتاريخ', style: TextStyle(fontSize: 12, color: _selectedDateRange != null ? accentColor : textHint, fontWeight: _selectedDateRange != null ? FontWeight.w600 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                  if (_selectedDateRange != null)
                    GestureDetector(onTap: () => setState(() => _selectedDateRange = null), child: Icon(Icons.close_rounded, size: 16, color: accentColor)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: _pickPersonFilter,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _selectedPersonId != null ? accentColor.withValues(alpha: 0.08) : cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _selectedPersonId != null ? accentColor.withValues(alpha: 0.4) : cardBorder)),
                child: Row(children: [
                  Icon(Icons.person_search_rounded, size: 16, color: _selectedPersonId != null ? accentColor : textHint),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedPersonName ?? (_tabController.index == 0 ? 'تحديد العميل' : 'تحديد المورد'), style: TextStyle(fontSize: 12, color: _selectedPersonId != null ? accentColor : textHint, fontWeight: _selectedPersonId != null ? FontWeight.w600 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                  if (_selectedPersonId != null)
                    GestureDetector(onTap: () => setState(() { _selectedPersonId = null; _selectedPersonName = null; }), child: Icon(Icons.close_rounded, size: 16, color: accentColor)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildReturnCard(Map<String, dynamic> item, Color accentColor, bool dark) {
    final returnId = item['id'] as int;
    final isExpanded = _expandedId == returnId;
    final isSales = _tabController.index == 0;
    final personName = isSales ? (item['customer_name'] ?? '') : (item['supplier_name'] ?? '');
    final refundType = item['refund_type']?.toString() ?? 'كاش';
    final totalAmount = (item['total_amount'] ?? 0).toDouble();

    final cardBg = dark ? AppColors.darkCardColor : Colors.white;
    final cardBorder = dark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
    final textSub = dark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    final textHint = dark ? Colors.white38 : const Color(0xFF94A3B8);
    final inputFill = dark ? AppColors.navyLight : Colors.white;

    Color statusColor;
    IconData statusIcon;
    switch (refundType) {
      case 'كاش': statusColor = AppColors.success; statusIcon = Icons.check_circle_rounded; break;
      case 'شبكة': statusColor = _purchaseAccent; statusIcon = Icons.credit_card_rounded; break;
      default: statusColor = AppColors.error; statusIcon = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? accentColor.withValues(alpha: 0.5) : cardBorder, width: isExpanded ? 1.5 : 1),
        boxShadow: isExpanded ? [BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(children: [
        InkWell(
          onTap: () {
            if (_isMultiSelectMode) {
              setState(() {
                if (_selectedIds.contains(returnId)) {
                  _selectedIds.remove(returnId);
                } else {
                  _selectedIds.add(returnId);
                }
              });
            } else {
              setState(() => _expandedId = isExpanded ? -1 : returnId);
              if (!isExpanded) {
                _loadReturnItems(returnId, isSales);
              }
            }
          },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isMultiSelectMode) ...[
                      Checkbox(
                        value: _selectedIds.contains(returnId),
                        activeColor: accentColor,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedIds.add(returnId);
                            } else {
                              _selectedIds.remove(returnId);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(child: Text((item['return_number'] ?? '').toString().replaceAll('-', '\u2011'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: accentColor, letterSpacing: 0.3), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withValues(alpha: 0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, size: 12, color: statusColor), const SizedBox(width: 4), Text(refundType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor))])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(10), border: Border.all(color: cardBorder)), child: Icon(isSales ? Icons.person_rounded : Icons.business_rounded, color: textSub, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(personName.toString().isNotEmpty ? personName : 'عميل عام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Row(children: [Icon(Icons.calendar_today_rounded, size: 12, color: textHint), const SizedBox(width: 4), Text(item['return_date']?.toString().substring(0, 10) ?? '', style: TextStyle(fontSize: 11, color: textSub))])])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('المبلغ المسترد', style: TextStyle(fontSize: 10, color: textHint)), Text('${_formatNumber(totalAmount)} ﷼', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15))]),
                  ],
                ),
                Align(alignment: Alignment.center, child: Padding(padding: const EdgeInsets.only(top: 8.0), child: AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.keyboard_arrow_down_rounded, color: textHint, size: 24)))),
              ],
            ),
          ),
        ),
        AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, child: isExpanded ? _buildExpandedContent(item, returnId, isSales, accentColor, dark) : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> item, int returnId, bool isSales, Color accentColor, bool dark) {
    final items = _returnItems[returnId] ?? [];
    final cardBorder = dark ? AppColors.darkBorder : const Color(0xFFE2E8F0);
    final textMain = dark ? AppColors.darkTextPrimary : const Color(0xFF1E293B);
    final textSub = dark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    final displayNotes = item['notes']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 12),
          Text('أصناف المرتجع:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: cardBorder)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: dark ? AppColors.navyLight : Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                    child: Row(children: [Expanded(flex: 3, child: Text('الصنف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSub))), Expanded(flex: 1, child: Text('السعر', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSub))), Expanded(flex: 1, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSub))), Expanded(flex: 2, child: Text('الإجمالي', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSub)))]),
                  ),
                  ...items.map((prod) {
                    final price = ((isSales ? prod['unit_price'] : prod['unit_cost']) ?? 0).toDouble();
                    final qty = (prod['quantity'] ?? 0).toInt();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: cardBorder.withValues(alpha: 0.5)))),
                      child: Row(children: [Expanded(flex: 3, child: Text(prod['product_name']?.toString() ?? '', style: TextStyle(fontSize: 12, color: textMain), overflow: TextOverflow.ellipsis)), Expanded(flex: 1, child: Text(_formatNumber(price), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSub))), Expanded(flex: 1, child: Text('$qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSub))), Expanded(flex: 2, child: Text(_formatNumber(price * qty), textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMain)))]),
                    );
                  }),
                ],
              ),
            ),

          if (displayNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ملاحظات المرتجع:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)), const SizedBox(height: 4), Text(displayNotes, style: TextStyle(fontSize: 12, color: textMain))])),
          ],

          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _buildActionButton(Icons.edit_outlined, 'تعديل', AppColors.primary, () => _editReturn(item))),
            const SizedBox(width: 8),
            Expanded(child: _buildActionButton(Icons.print_outlined, 'طباعة', accentColor, () => _printReturn(item, isSales))),
            const SizedBox(width: 8),
            Expanded(child: _buildActionButton(Icons.delete_outline_rounded, 'حذف', AppColors.error, () => _deleteReturn(item))),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 18), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}

class _NumericDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateTimeChanged;
  final Color textColor;
  final Color accentColor;

  const _NumericDatePicker({required this.initialDate, required this.onDateTimeChanged, required this.textColor, required this.accentColor});

  @override
  State<_NumericDatePicker> createState() => _NumericDatePickerState();
}

class _NumericDatePickerState extends State<_NumericDatePicker> {
  late int day, month, year;
  late FixedExtentScrollController _dayController, _monthController, _yearController;

  @override
  void initState() {
    super.initState();
    day = widget.initialDate.day;
    month = widget.initialDate.month;
    year = widget.initialDate.year;
    _dayController = FixedExtentScrollController(initialItem: day - 1);
    _monthController = FixedExtentScrollController(initialItem: month - 1);
    _yearController = FixedExtentScrollController(initialItem: year - 2020);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int _getDaysInMonth(int y, int m) {
    if (m == 2) {
      return ((y % 4 == 0) && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[m - 1];
  }

  void _updateDate() {
    int maxDays = _getDaysInMonth(year, month);
    if (day > maxDays) {
      day = maxDays;
      _dayController.animateToItem(day - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    widget.onDateTimeChanged(DateTime(year, month, day));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(color: widget.textColor, fontSize: 16, fontWeight: FontWeight.bold);
    return Row(
      children: [
        Expanded(
          child: CupertinoPicker(
            scrollController: _yearController,
            itemExtent: 40,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: widget.accentColor.withValues(alpha: 0.15)),
            onSelectedItemChanged: (i) {
              year = 2020 + i;
              _updateDate();
            },
            children: List.generate(20, (i) => Center(child: Text('${2020 + i}', style: textStyle))),
          ),
        ),
        const Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
        Expanded(
          child: CupertinoPicker(
            scrollController: _monthController,
            itemExtent: 40,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: widget.accentColor.withValues(alpha: 0.15)),
            onSelectedItemChanged: (i) {
              month = i + 1;
              _updateDate();
            },
            children: List.generate(12, (i) => Center(child: Text((i + 1).toString().padLeft(2, '0'), style: textStyle))),
          ),
        ),
        const Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
        Expanded(
          child: CupertinoPicker(
            scrollController: _dayController,
            itemExtent: 40,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: widget.accentColor.withValues(alpha: 0.15)),
            onSelectedItemChanged: (i) {
              day = i + 1;
              _updateDate();
            },
            children: List.generate(_getDaysInMonth(year, month), (i) => Center(child: Text((i + 1).toString().padLeft(2, '0'), style: textStyle))),
          ),
        ),
      ],
    );
  }
}