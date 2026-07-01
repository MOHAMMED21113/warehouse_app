// lib/modules/users/views/permissions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/guards/permission_guard.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  String _selectedRole = 'accountant';
  final List<String> _entities = ['products', 'invoices', 'customers', 'loans', 'reports', 'users'];
  final List<String> _actions = ['read', 'write', 'update', 'delete'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصلاحيات والأدوار (Roles & Permissions)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedRole,
              decoration: const InputDecoration(labelText: 'اختر الدور الوظيفي لتعديل صلاحياته', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('مدير النظام (Admin)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'accountant', child: Text('محاسب عام (Accountant)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'cashier', child: Text('كاشير مبيعات (Cashier)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'warehouse_supervisor', child: Text('مشرف المخزن (Warehouse Supervisor)', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 24),
            const Text('مصفوفة الصلاحيات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _entities.length,
                itemBuilder: (context, index) {
                  final entity = _entities[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getEntityTitle(entity), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Divider(),
                          Wrap(
                            spacing: 16,
                            children: _actions.map((act) {
                              final hasPerm = PermissionGuard.rolePermissions[_selectedRole]?[entity]?.contains(act) ?? false;
                              return FilterChip(
                                label: Text(_getActionTitle(act)),
                                selected: hasPerm,
                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                checkmarkColor: AppColors.primary,
                                onSelected: (val) {
                                  setState(() {
                                    PermissionGuard.updatePermission(_selectedRole, entity, act, val);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEntityTitle(String e) {
    switch (e) {
      case 'products': return 'إدارة المنتجات والمخزون';
      case 'invoices': return 'فواتير البيع والشراء';
      case 'customers': return 'العملاء والموردين';
      case 'loans': return 'سلف وقروض الأطراف';
      case 'reports': return 'التقارير المالية والمحاسبية';
      case 'users': return 'إدارة المستخدمين والنظام';
    }
    return e;
  }

  String _getActionTitle(String a) {
    switch (a) {
      case 'read': return 'عرض وقراءة';
      case 'write': return 'إضافة وثبات';
      case 'update': return 'تعديل البيانات';
      case 'delete': return 'حذف وإلغاء';
    }
    return a;
  }
}
