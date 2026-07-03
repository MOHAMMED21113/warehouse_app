// lib/modules/settings/views/audit_log_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/audit_log_service.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<String> _availableTables = [];
  bool _isLoading = true;
  String _selectedTable = 'all';
  String _selectedAction = 'all';
  String? _startDate;
  String? _endDate;

  final Map<String, String> _tableTranslations = {
    'products': 'المنتجات (Products)',
    'sales_invoices': 'فواتير المبيعات (Sales Invoices)',
    'purchase_invoices': 'فواتير المشتريات (Purchase Invoices)',
    'customers': 'العملاء (Customers)',
    'suppliers': 'الموردون (Suppliers)',
    'loans': 'السلف والقروض (Loans)',
    'financial_vouchers': 'السندات المالية (Vouchers)',
    'damaged_products': 'التالف والهالك (Damaged)',
    'warehouses': 'المستودعات (Warehouses)',
    'users': 'المستخدمون (Users)',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseHelperProvider);
    final service = AuditLogService(db);
    final tables = await service.getUniqueTables();
    if (mounted) {
      setState(() {
        _availableTables = tables;
      });
    }
    await _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseHelperProvider);
    final service = AuditLogService(db);
    final res = await service.getAuditLog(
      tableName: _selectedTable,
      action: _selectedAction,
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) {
      setState(() {
        _logs = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(
              start: DateTime.tryParse(_startDate!) ?? now,
              end: DateTime.tryParse(_endDate!) ?? now,
            )
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadLogs();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadLogs();
  }

  String _getTranslatedTableName(String rawName) {
    return _tableTranslations[rawName] ?? rawName;
  }

  String _getActionArabicName(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT':
      case 'CREATE':
      case 'إضافة':
        return 'إضافة جديدة';
      case 'UPDATE':
      case 'تعديل':
        return 'تعديل بيانات';
      case 'DELETE':
      case 'حذف':
        return 'حذف سجل';
      default:
        return action;
    }
  }

  Color _getActionColor(String act) {
    final a = act.toUpperCase();
    if (a == 'DELETE' || a == 'حذف') return AppColors.error;
    if (a == 'INSERT' || a == 'CREATE' || a == 'إضافة') return AppColors.success;
    return AppColors.warning;
  }

  IconData _getActionIcon(String act) {
    final a = act.toUpperCase();
    if (a == 'DELETE' || a == 'حذف') return Icons.delete_forever_rounded;
    if (a == 'INSERT' || a == 'CREATE' || a == 'إضافة') return Icons.add_circle_rounded;
    return Icons.edit_note_rounded;
  }

  void _showLogDetailsDialog(Map<String, dynamic> log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Map<String, dynamic>? oldMap;
    Map<String, dynamic>? newMap;

    try {
      if (log['old_value'] != null && log['old_value'].toString().isNotEmpty) {
        oldMap = jsonDecode(log['old_value'].toString()) as Map<String, dynamic>;
      }
    } catch (_) {}

    try {
      if (log['new_value'] != null && log['new_value'].toString().isNotEmpty) {
        newMap = jsonDecode(log['new_value'].toString()) as Map<String, dynamic>;
      }
    } catch (_) {}

    final action = log['action']?.toString() ?? '';
    final color = _getActionColor(action);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor ?? colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(_getActionIcon(action), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل عملية: ${_getActionArabicName(action)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  Text(
                    'الجدول: ${_getTranslatedTableName(log['table_name']?.toString() ?? '')} (#${log['record_id']})',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('رقم العملية: #${log['id']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      Text('المستخدم: ID #${log['user_id'] ?? 1}', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                      Text('${log['timestamp']}', style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (action == 'UPDATE' && oldMap != null && newMap != null) ...[
                  Text('مقارنة التغييرات المحدثة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  _buildChangesDiffTable(oldMap, newMap, theme),
                ] else if (action == 'INSERT' && newMap != null) ...[
                  const Text('البيانات التي تم إضافتها:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success)),
                  const SizedBox(height: 8),
                  _buildSingleDataViewer(newMap, AppColors.success, theme),
                ] else if (action == 'DELETE' && oldMap != null) ...[
                  const Text('البيانات التي تم حذفها:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
                  const SizedBox(height: 8),
                  _buildSingleDataViewer(oldMap, AppColors.error, theme),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('لا توجد تفاصيل إضافية مسجلة لهذه العملية', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildChangesDiffTable(Map<String, dynamic> oldMap, Map<String, dynamic> newMap, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final allKeys = {...oldMap.keys, ...newMap.keys}.toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: allKeys.map((key) {
          final oldVal = oldMap[key]?.toString() ?? '-';
          final newVal = newMap[key]?.toString() ?? '-';
          final isChanged = oldVal != newVal;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isChanged ? AppColors.warning.withValues(alpha: 0.08) : null,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    key,
                    style: TextStyle(fontSize: 12, fontWeight: isChanged ? FontWeight.bold : FontWeight.normal, color: colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    oldVal,
                    style: TextStyle(
                      fontSize: 12,
                      color: isChanged ? AppColors.error : colorScheme.onSurface.withValues(alpha: 0.6),
                      decoration: isChanged ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: Text(
                    newVal,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isChanged ? FontWeight.bold : FontWeight.normal,
                      color: isChanged ? AppColors.success : colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSingleDataViewer(Map<String, dynamic> dataMap, Color accentColor, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: dataMap.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    entry.value?.toString() ?? '-',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tableItems = [
      const DropdownMenuItem(value: 'all', child: Text('جميع الجداول', overflow: TextOverflow.ellipsis)),
      ..._tableTranslations.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))),
      ..._availableTables.where((t) => !_tableTranslations.containsKey(t)).map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الرقابة والتدقيق (Audit Log)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedTable,
                        decoration: InputDecoration(
                          labelText: 'الجدول المستهدف',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: tableItems,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTable = val);
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedAction,
                        decoration: InputDecoration(
                          labelText: 'نوع العملية',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('جميع العمليات')),
                          DropdownMenuItem(value: 'INSERT', child: Text('إضافة جديدة 🟢')),
                          DropdownMenuItem(value: 'UPDATE', child: Text('تعديل بيانات 🟡')),
                          DropdownMenuItem(value: 'DELETE', child: Text('حذف سجل 🔴')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedAction = val);
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range_rounded, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _startDate != null && _endDate != null
                                      ? 'التاريخ: $_startDate إلى $_endDate'
                                      : 'تصفية حسب التاريخ (كل الفترات)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_startDate != null)
                                InkWell(
                                  onTap: _clearDateFilter,
                                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد عمليات مسجلة تطابق خيارات البحث',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: colorScheme.primary,
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final action = log['action']?.toString() ?? '';
                            final color = _getActionColor(action);
                            final icon = _getActionIcon(action);

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: color.withValues(alpha: 0.35), width: 1),
                              ),
                              child: InkWell(
                                onTap: () => _showLogDetailsDialog(log),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(icon, color: color, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${_getActionArabicName(action)} - ${_getTranslatedTableName(log['table_name']?.toString() ?? '')}',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colorScheme.onSurface),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '#${log['record_id']}',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.access_time_rounded, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${log['timestamp']}',
                                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.person_outline_rounded, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'المستخدم ID #${log['user_id'] ?? 1}',
                                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
