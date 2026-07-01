// lib/data/models/user_model.dart

class UserModel {
  final int? id;
  final String username;
  final String fullName;
  final String role; // 'admin' أو 'user'
  final bool isActive;
  final List<String> permissions;
  final bool hasBiometric;
  final List<String> securePermissions;
  final int? createdBy;
  final String? createdAt;
  final String? lastLogin;

  const UserModel({
    this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.isActive = true,
    required this.permissions,
    this.hasBiometric = false,
    required this.securePermissions,
    this.createdBy,
    this.createdAt,
    this.lastLogin,
  });

  UserModel copyWith({
    int? id,
    String? username,
    String? fullName,
    String? role,
    bool? isActive,
    List<String>? permissions,
    bool? hasBiometric,
    List<String>? securePermissions,
    int? createdBy,
    String? createdAt,
    String? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      hasBiometric: hasBiometric ?? this.hasBiometric,
      securePermissions: securePermissions ?? this.securePermissions,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'permissions': permissions.join(','),
      'has_biometric': hasBiometric ? 1 : 0,
      'secure_permissions': securePermissions.join(','),
      'created_by': createdBy,
      'created_at': createdAt,
      'last_login': lastLogin,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final permString = map['permissions'] as String? ?? '';
    final securePermString = map['secure_permissions'] as String? ?? '';
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      permissions: (permString == '*' || permString == 'all') ? ['*'] : (permString.isEmpty ? [] : permString.split(',')),
      hasBiometric: (map['has_biometric'] as int? ?? 0) == 1,
      securePermissions: securePermString.isEmpty ? [] : securePermString.split(','),
      createdBy: map['created_by'] as int?,
      createdAt: map['created_at'] as String?,
      lastLogin: map['last_login'] as String?,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get hasAllPermissions => permissions.contains('*');

  bool hasPermission(String permission) {
    if (isAdmin || hasAllPermissions) return true;
    return permissions.contains(permission);
  }

  bool requiresSecurity(String permission) {
    if (isAdmin && securePermissions.isEmpty) return false; // Admin doesn't necessarily bypass security if not configured, but let's say they do if securePermissions is empty? No, secure_permissions should be explicit.
    return securePermissions.contains(permission);
  }
}