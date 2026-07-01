// lib/data/models/current_user.dart
class CurrentUser {
  static int? id;
  static String? username;
  static String? fullName;
  static String? role;
  static bool hasBiometric = false;
  static List<String> securePermissions = [];

  static bool isAdmin() => role == 'admin';
  static bool isEmployee() => role == 'employee' || role == 'admin';
  static bool isViewer() => role == 'viewer';

  static void clear() {
    id = null;
    username = null;
    fullName = null;
    role = null;
    hasBiometric = false;
    securePermissions = [];
  }
}