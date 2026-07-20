// lib/modules/auth/views/users_screen.dart
// ✅ تصميم احترافي فاخر Navy/Gold — مع صلاحيات موحدة من AppPermissions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_permissions.dart';
import '../../../core/providers/global_providers.dart';
import '../../../data/models/current_user.dart';
import '../../../data/models/user_model.dart';
import '../../../database/database_helper.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  late AnimationController _headerAnim;
  late Animation<double> _headerFade;

  // ✅ جميع الصلاحيات مستوردة من AppPermissions (بدون تكرار)
  final Map<String, String> _availablePermissions = AppPermissions.getPermissionLabels();
  final Map<String, IconData> _permissionIcons = AppPermissions.getPermissionIcons();
  final Map<String, List<String>> _permissionGroups = AppPermissions.getPermissionGroups();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic);
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final db = ref.read(databaseHelperProvider);
    _users = await db.getAllUsers();
    ref.invalidate(usersProvider);

    if (CurrentUser.id != null) {
      final currentRaw = await db.getUserByIdRaw(CurrentUser.id!);
      if (currentRaw != null) {
        final currentModel = UserModel.fromMap(currentRaw);
        CurrentUser.username = currentModel.username;
        CurrentUser.fullName = currentModel.fullName;
        CurrentUser.role = currentModel.role;
        CurrentUser.hasBiometric = currentModel.hasBiometric;
        CurrentUser.securePermissions = currentModel.securePermissions;
        ref.read(currentUserProvider.notifier).state = currentModel;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ==================== الإحصائيات ====================
  Map<String, int> _getUserStats() {
    int admins = 0, employees = 0, viewers = 0;
    for (final u in _users) {
      switch (u['role']) {
        case 'admin':
          admins++;
          break;
        case 'employee':
          employees++;
          break;
        case 'viewer':
          viewers++;
          break;
        default:
          employees++;
      }
    }
    return {'admins': admins, 'employees': employees, 'viewers': viewers};
  }

  // ==================== SliverAppBar ====================
  Widget _buildSliverAppBar(bool isDark) {
    final stats = _getUserStats();
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      floating: false,
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            size: 20, color: AppColors.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('إدارة المستخدمين',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: AppColors.primary)),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.person_add_rounded,
                color: AppColors.primary, size: 20),
            onPressed: () => _showAddEditDialog(),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: FadeTransition(
          opacity: _headerFade,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.navy,
                  AppColors.navyMedium,
                  AppColors.navyLight,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 65, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _buildUserCountRing(_users.length),
                        const SizedBox(width: 20),
                        Expanded(child: _buildStatsRow(stats)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCountRing(int total) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 2),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              valueColor:
              AlwaysStoppedAnimation(Colors.white.withOpacity(0.07)),
              strokeCap: StrokeCap.round,
            ),
            CircularProgressIndicator(
              value: value,
              strokeWidth: 6,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10)
                      ],
                    ),
                  ),
                  Text(
                    'مستخدم',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, int> stats) {
    return Column(
      children: [
        Row(children: [
          Expanded(
              child: _miniStat('مدراء', '${stats['admins']}',
                  AppColors.primary, Icons.shield_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _miniStat('موظفين', '${stats['employees']}',
                  AppColors.success, Icons.badge_rounded)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _miniStat('مشاهدين', '${stats['viewers']}',
                  AppColors.info, Icons.visibility_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _miniStat('الإجمالي', '${_users.length}',
                  const Color(0xFF94A3B8), Icons.groups_rounded)),
        ]),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== حوار إضافة / تعديل ====================
  Future<void> _showAddEditDialog({Map<String, dynamic>? user}) async {
    final isEditing = user != null;
    final usernameCtrl = TextEditingController(text: user?['username']);
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController(text: user?['full_name']);
    String selectedRole = user?['role'] ?? 'employee';

    List<String> selectedPermissions = [];
    List<String> securePermissions = [];
    bool hasBiometric = user?['has_biometric'] == 1;
    if (isEditing && user?['permissions'] != null && user!['permissions'].toString().isNotEmpty) {
      selectedPermissions = user['permissions'].toString().split(',').map((e) => e.trim()).toList();
    }
    if (isEditing && user?['secure_permissions'] != null && user!['secure_permissions'].toString().isNotEmpty) {
      securePermissions = user['secure_permissions'].toString().split(',').map((e) => e.trim()).toList();
    }

    bool obscurePassword = true;

    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    // ✅ استخدام القوائم من AppPermissions
    final permLabels = AppPermissions.getPermissionLabels();
    final permIcons = AppPermissions.getPermissionIcons();
    final permGroups = AppPermissions.getPermissionGroups();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              final sheetBg = isDark ? AppColors.navyCard : Colors.white;
              final inputFill =
              isDark ? AppColors.navy : const Color(0xFFF8FAFC);
              final borderClr =
              isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
              final titleClr = isDark
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFF0F172A);
              final subClr = isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569);
              final hintClr = isDark
                  ? const Color(0xFF64748B)
                  : const Color(0xFF94A3B8);

              return Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                  border: Border(
                      top: BorderSide(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1.5)),
                  boxShadow: [
                    BoxShadow(
                      color:
                      Colors.black.withOpacity(isDark ? 0.35 : 0.1),
                      blurRadius: 25,
                      offset: const Offset(0, -6),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom:
                      MediaQuery.of(context).viewInsets.bottom + 20,
                      left: 20,
                      right: 20,
                      top: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // مقبض السحب
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // هيدر الحوار
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              AppColors.navy,
                              AppColors.navyMedium,
                            ]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy
                                    .withOpacity(isDark ? 0.4 : 0.2),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                  AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(13)),
                              child: Icon(
                                  isEditing
                                      ? Icons.manage_accounts_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  color: AppColors.primary,
                                  size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing
                                        ? 'تعديل المستخدم'
                                        : 'مستخدم جديد',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isEditing
                                        ? 'تحديث البيانات والصلاحيات'
                                        : 'أدخل المعلومات وحدد الصلاحيات',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary
                                            .withOpacity(0.8)),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 24),

                        // اسم المستخدم
                        _sectionLabel(
                            'اسم المستخدم', Icons.person_rounded, titleClr),
                        const SizedBox(height: 8),
                        _buildField(usernameCtrl, 'أدخل اسم المستخدم',
                            Icons.alternate_email_rounded, inputFill,
                            borderClr, titleClr, hintClr),
                        const SizedBox(height: 18),

                        // كلمة المرور
                        _sectionLabel(
                            'كلمة المرور', Icons.lock_rounded, titleClr),
                        const SizedBox(height: 8),
                        _buildField(
                            passwordCtrl,
                            isEditing
                                ? 'اتركها فارغة إذا لا تريد التغيير'
                                : 'أدخل كلمة المرور',
                            Icons.vpn_key_rounded,
                            inputFill,
                            borderClr,
                            titleClr,
                            hintClr,
                            obscure: obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: hintClr,
                                size: 19,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            )),
                        const SizedBox(height: 18),

                        // الاسم الكامل
                        _sectionLabel('الاسم الكامل',
                            Icons.badge_rounded, titleClr),
                        const SizedBox(height: 8),
                        _buildField(fullNameCtrl, 'الاسم الكامل (اختياري)',
                            Icons.text_fields_rounded, inputFill,
                            borderClr, titleClr, hintClr),
                        const SizedBox(height: 18),

                        // الدور
                        _sectionLabel('الدور الأساسي',
                            Icons.admin_panel_settings_rounded, titleClr),
                        const SizedBox(height: 8),
                        _buildRoleSelector(selectedRole, isDark, inputFill,
                            borderClr, titleClr, (v) {
                              setModalState(() => selectedRole = v!);
                            }),
                        const SizedBox(height: 24),

                        // تفعيل البصمة
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderClr),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تفعيل التحقق بالبصمة',
                                      style: TextStyle(color: titleClr, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'للدخول وتأكيد العمليات المحمية',
                                      style: TextStyle(color: subClr, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: hasBiometric,
                                onChanged: (val) => setModalState(() => hasBiometric = val),
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // الصلاحيات المخصصة
                        if (selectedRole != 'admin') ...[
                          _buildPermissionsHeader(
                              selectedPermissions.length, isDark),
                          const SizedBox(height: 12),
                          _buildPermissionsList(selectedPermissions, securePermissions, isDark, inputFill, borderClr, setModalState),
                          const SizedBox(height: 24),
                        ],

                        // أزرار
                        _buildFormButtons(
                          isEditing: isEditing,
                          isDark: isDark,
                          borderClr: borderClr,
                          onSave: () async {
                            final db = ref.read(databaseHelperProvider);
                            if (usernameCtrl.text.trim().isEmpty) {
                              _showErrorMsg('يرجى إدخال اسم المستخدم');
                              return;
                            }
                            if (!isEditing &&
                                passwordCtrl.text.trim().isEmpty) {
                              _showErrorMsg('يرجى إدخال كلمة المرور');
                              return;
                            }

                            final perms = selectedRole == 'admin'
                                ? 'all'
                                : selectedPermissions.join(',');

                            if (isEditing) {
                              final data = {
                                'username':
                                usernameCtrl.text.trim(),
                                'full_name':
                                fullNameCtrl.text.trim(),
                                'role': selectedRole,
                                'permissions': perms,
                                'has_biometric': hasBiometric ? 1 : 0,
                                'secure_permissions': securePermissions.join(','),
                              };
                              if (passwordCtrl.text.trim().isNotEmpty &&
                                  passwordCtrl.text != '********') {
                                data['password_hash'] =
                                    passwordCtrl.text.trim();
                              }
                              await db.updateUser(user!['id'], data);
                              _showSuccessMsg(
                                  'تم تعديل المستخدم وصلاحياته بنجاح');
                            } else {
                              await db.insertUser({
                                'username':
                                usernameCtrl.text.trim(),
                                'password_hash':
                                passwordCtrl.text.trim(),
                                'full_name':
                                fullNameCtrl.text.trim(),
                                'role': selectedRole,
                                'permissions': perms,
                                'has_biometric': hasBiometric ? 1 : 0,
                                'secure_permissions': securePermissions.join(','),
                              });
                              _showSuccessMsg('تم إضافة المستخدم بنجاح');
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              _loadUsers();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ==================== عناصر النموذج ====================
  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: color, fontSize: 13)),
      ],
    );
  }

  Widget _buildField(
      TextEditingController ctrl,
      String hint,
      IconData icon,
      Color fill,
      Color border,
      Color textClr,
      Color hintClr,
      {bool obscure = false, Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: textClr, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintClr, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 19),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(String selectedRole, bool isDark, Color fill,
      Color border, Color textClr, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedRole,
        isExpanded: true,
        dropdownColor: isDark ? AppColors.navyCard : Colors.white,
        style: TextStyle(color: textClr, fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: Icon(Icons.admin_panel_settings_outlined,
              color: AppColors.primary, size: 20),
        ),
        items: [
          DropdownMenuItem(
              value: 'admin',
              child: Row(children: [
                Icon(Icons.shield_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('مدير النظام',
                    style: TextStyle(color: textClr)),
              ])),
          DropdownMenuItem(
              value: 'employee',
              child: Row(children: [
                Icon(Icons.badge_rounded,
                    size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Text('موظف (صلاحيات مخصصة)',
                    style: TextStyle(color: textClr)),
              ])),
          DropdownMenuItem(
              value: 'viewer',
              child: Row(children: [
                Icon(Icons.visibility_rounded,
                    size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Text('مشاهد فقط', style: TextStyle(color: textClr)),
              ])),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPermissionsHeader(int count, bool isDark) {
    final total = AppPermissions.getAllPermissions().length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withOpacity(isDark ? 0.14 : 0.08),
          AppColors.primary.withOpacity(isDark ? 0.04 : 0.02),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.security_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الصلاحيات المخصصة',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : AppColors.navy,
                  fontSize: 13),
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border:
              Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              '$count / $total',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ قائمة الصلاحيات تستخدم AppPermissions
  Widget _buildPermissionsList(
      List<String> selected,
      List<String> secure,
      bool isDark,
      Color fill,
      Color border,
      StateSetter setModalState) {

    final permLabels = AppPermissions.getPermissionLabels();
    final permGroups = AppPermissions.getPermissionGroups();

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: permGroups.entries.map((group) {
            return Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(group.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                children: group.value.map((permKey) {
                  final isSelected = selected.contains(permKey);
                  final isSecure = secure.contains(permKey);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selected.add(permKey);
                              } else {
                                selected.remove(permKey);
                                secure.remove(permKey);
                              }
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                        Expanded(
                          child: Text(
                            permLabels[permKey] ?? permKey,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                          ),
                        ),
                        if (isSelected)
                          IconButton(
                            icon: Icon(
                              isSecure ? Icons.lock_rounded : Icons.lock_open_rounded,
                              color: isSecure ? AppColors.error : AppColors.primary.withOpacity(0.5),
                              size: 20,
                            ),
                            tooltip: isSecure ? 'يتطلب تحقق أمني' : 'لا يتطلب تحقق',
                            onPressed: () {
                              setModalState(() {
                                if (isSecure) {
                                  secure.remove(permKey);
                                } else {
                                  secure.add(permKey);
                                }
                              });
                            },
                          )
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFormButtons({
    required bool isEditing,
    required bool isDark,
    required Color borderClr,
    required VoidCallback onSave,
  }) {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: borderClr, width: 1.5),
            ),
            child: Text('إلغاء',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569))),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: SizedBox(
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSave,
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        isEditing
                            ? Icons.save_rounded
                            : Icons.person_add_rounded,
                        size: 18,
                        color: AppColors.navy),
                    const SizedBox(width: 6),
                    Text(isEditing ? 'حفظ التعديلات' : 'إضافة المستخدم',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.navy)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ==================== رسائل ====================
  void _showErrorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child:
            Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child:
            Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ==================== حوار الحذف ====================
  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    // ✅ الحصول على المستخدم الحالي من Riverpod
    final currentUser = ref.read(currentUserProvider);

    if (currentUser != null && currentUser.id == user['id']) {
      _showErrorMsg('لا يمكن حذف حسابك الحالي');
      return;
    }

    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyCard : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
              top: BorderSide(
                  color: AppColors.error.withOpacity(0.4), width: 1.5)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  AppColors.error.withOpacity(0.15),
                  AppColors.error.withOpacity(0.02),
                ]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  size: 44, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text('حذف المستخدم',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    height: 1.6),
                children: [
                  const TextSpan(text: 'هل أنت متأكد من حذف '),
                  TextSpan(
                      text: '"${user['username']}"',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A))),
                  const TextSpan(text: '؟\nهذا الإجراء لا يمكن التراجع عنه.'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(
                          color: isDark
                              ? AppColors.navyBorder
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Text('إلغاء',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final db = ref.read(databaseHelperProvider);
                      await db.deleteUser(user['id']);
                      if (mounted) {
                        Navigator.pop(context);
                        _loadUsers();
                      }
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('حذف',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
  // ==================== الواجهة الرئيسية ====================
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final scaffoldBg = isDark ? AppColors.navy : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(
              valueColor:
              AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : NestedScrollView(
        headerSliverBuilder: (ctx, inner) =>
        [_buildSliverAppBar(isDark)],
        body: _users.isEmpty
            ? _buildEmptyState(isDark)
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          physics: const BouncingScrollPhysics(),
          itemCount: _users.length,
          itemBuilder: (context, index) =>
              _buildUserCard(_users[index], index, isDark),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight]),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 5))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAddEditDialog(),
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding:
              EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_rounded,
                      color: AppColors.navy, size: 20),
                  SizedBox(width: 6),
                  Text('إضافة مستخدم',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== بطاقة المستخدم ====================
  Widget _buildUserCard(
      Map<String, dynamic> user, int index, bool isDark) {
    final isCurrent = user['id'] == CurrentUser.id;
    final roleColor = _getRoleColor(user['role']);
    final roleIcon = _getRoleIcon(user['role']);
    final cardBg = isDark ? AppColors.navyCard : Colors.white;
    final cardBorder =
    isDark ? AppColors.navyBorder : const Color(0xFFE2E8F0);
    final titleClr =
    isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subClr =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final hintClr =
    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    String permText = 'كامل الصلاحيات';
    if (user['role'] != 'admin' &&
        user['permissions'] != null &&
        user['permissions'].toString().isNotEmpty &&
        user['permissions'].toString() != 'all') {
      final c = user['permissions'].toString().split(',').length;
      permText = '$c صلاحيات';
    } else if (user['role'] == 'viewer') {
      permText = 'مشاهدة فقط';
    } else if (user['role'] != 'admin') {
      permText = 'بدون صلاحيات';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 10) * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(30 * (1 - value), 0),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isCurrent
                  ? AppColors.primary.withOpacity(0.4)
                  : cardBorder,
              width: isCurrent ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        roleColor,
                        roleColor.withOpacity(0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [
                                  AppColors.navy,
                                  AppColors.navyMedium
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: roleColor.withOpacity(0.4),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: roleColor.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Center(
                            child: Text(
                                (user['username'] ?? 'U')[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        user['username'] ?? '',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: titleClr))),
                                if (isCurrent)
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary
                                                .withOpacity(0.15),
                                            AppColors.primary
                                                .withOpacity(0.05),
                                          ]),
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withOpacity(0.3)),
                                    ),
                                    child: const Text('أنت ⭐',
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 9,
                                            fontWeight:
                                            FontWeight.bold)),
                                  ),
                              ]),
                              if (user['full_name'] != null &&
                                  user['full_name']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user['full_name'],
                                    style: TextStyle(
                                        fontSize: 12, color: subClr)),
                              ],
                              const SizedBox(height: 6),
                              Row(children: [
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [
                                          roleColor.withOpacity(
                                              isDark ? 0.2 : 0.12),
                                          roleColor.withOpacity(
                                              isDark ? 0.08 : 0.04),
                                        ]),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    border: Border.all(
                                        color: roleColor
                                            .withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(roleIcon,
                                          size: 11,
                                          color: roleColor),
                                      const SizedBox(width: 4),
                                      Text(
                                          _getRoleName(user['role']),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: roleColor,
                                              fontWeight:
                                              FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.security_rounded,
                                        size: 10, color: hintClr),
                                    const SizedBox(width: 3),
                                    Text(permText,
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: hintClr,
                                            fontWeight:
                                            FontWeight.w600)),
                                  ],
                                ),
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            _actionBtn(
                                Icons.manage_accounts_rounded,
                                AppColors.primary
                                    .withOpacity(
                                    isDark ? 0.12 : 0.06),
                                AppColors.primary,
                                    () => _showAddEditDialog(
                                    user: user)),
                            if (!isCurrent) ...[
                              const SizedBox(height: 6),
                              _actionBtn(
                                  Icons.delete_outline_rounded,
                                  AppColors.error.withOpacity(
                                      isDark ? 0.12 : 0.06),
                                  AppColors.error,
                                      () => _confirmDelete(user)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fg.withOpacity(0.15))),
        child: Icon(icon, color: fg, size: 17),
      ),
    );
  }

  // ==================== حالة فارغة ====================
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [
                AppColors.primary.withOpacity(0.12),
                AppColors.primary.withOpacity(0.02),
              ]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_add_rounded,
                size: 60, color: AppColors.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 22),
          Text('لا يوجد مستخدمون',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text('أضف مستخدمين جدد وحدد صلاحياتهم',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B))),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddEditDialog(),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded,
                          size: 18, color: AppColors.navy),
                      SizedBox(width: 8),
                      Text('إضافة مستخدم',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.navy)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ==================== مساعدات ====================
  String _getRoleName(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'employee':
        return 'موظف';
      case 'viewer':
        return 'مشاهد';
      default:
        return 'موظف';
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return AppColors.primary;
      case 'employee':
        return AppColors.success;
      case 'viewer':
        return AppColors.info;
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.shield_rounded;
      case 'employee':
        return Icons.badge_rounded;
      case 'viewer':
        return Icons.visibility_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}