// lib/modules/settings/views/audit_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isLoading = true;
  String _selectedTable = 'all';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseHelperProvider);
    final service = AuditLogService(db);
    final res = await service.getAuditLog(tableName: _selectedTable);
    if (mounted) {
      setState(() {
        _logs = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الرقابة والتدقيق (Audit Log)'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'تصفية حسب الجدول:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedTable,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('جميع الجداول', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'products', child: Text('المنتجات (products)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'sales_invoices', child: Text('المبيعات (sales_invoices)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'loans', child: Text('السلف (loans)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTable = val);
                        _loadLogs();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('لا توجد سجلات تدقيق مسجلة حتى الآن'))
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getActionColor(log['action']?.toString() ?? ''),
                                  child: Icon(_getActionIcon(log['action']?.toString() ?? ''), color: Colors.white, size: 20),
                                ),
                                title: Text('${log['action']} في جدول: ${log['table_name']} (#${log['record_id']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('الوقت: ${log['timestamp']} | المستخدم: ID #${log['user_id']}'),
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

  Color _getActionColor(String act) {
    if (act == 'DELETE') return AppColors.error;
    if (act == 'INSERT') return AppColors.success;
    return AppColors.warning;
  }

  IconData _getActionIcon(String act) {
    if (act == 'DELETE') return Icons.delete_forever;
    if (act == 'INSERT') return Icons.add_circle;
    return Icons.edit;
  }
}
