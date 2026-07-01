// lib/core/guards/permission_guard.dart

class PermissionGuard {
  static final Map<String, Map<String, List<String>>> rolePermissions = {
    'admin': {
      'products': ['read', 'write', 'update', 'delete'],
      'invoices': ['read', 'write', 'update', 'delete'],
      'customers': ['read', 'write', 'update', 'delete'],
      'loans': ['read', 'write', 'update', 'delete'],
      'reports': ['read', 'write', 'update', 'delete'],
      'users': ['read', 'write', 'update', 'delete'],
    },
    'accountant': {
      'products': ['read'],
      'invoices': ['read', 'write'],
      'customers': ['read', 'write'],
      'loans': ['read', 'write', 'update'],
      'reports': ['read'],
      'users': [],
    },
    'cashier': {
      'products': ['read'],
      'invoices': ['read', 'write'],
      'customers': ['read'],
      'loans': ['read'],
      'reports': [],
      'users': [],
    },
    'warehouse_supervisor': {
      'products': ['read', 'write', 'update'],
      'invoices': ['read'],
      'customers': ['read'],
      'loans': [],
      'reports': ['read'],
      'users': [],
    },
  };

  static String currentUserRole = 'admin';

  static bool hasPermission(String entity, String action) {
    if (currentUserRole == 'admin') return true;
    final perms = rolePermissions[currentUserRole]?[entity];
    return perms?.contains(action) ?? false;
  }

  static void updatePermission(String role, String entity, String action, bool value) {
    if (rolePermissions[role] == null) {
      rolePermissions[role] = {};
    }
    if (rolePermissions[role]![entity] == null) {
      rolePermissions[role]![entity] = [];
    }
    if (value) {
      if (!rolePermissions[role]![entity]!.contains(action)) {
        rolePermissions[role]![entity]!.add(action);
      }
    } else {
      rolePermissions[role]![entity]!.remove(action);
    }
  }
}