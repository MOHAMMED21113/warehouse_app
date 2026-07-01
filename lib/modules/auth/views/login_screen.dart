import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../database/database_helper.dart';
import '../../../data/models/current_user.dart';
import '../../../data/models/user_model.dart';
import '../../main_menu/views/main_menu_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();

  final db = DatabaseHelper.instance;
  final LocalAuthentication auth = LocalAuthentication();

  bool _isLoading = true;
  bool _hasBiometricHardware = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final users = await db.getAllUsers();
      print('🚀 [LoginScreen] users count = ${users.length}');
      if (users.isNotEmpty) {
        print('🚀 [LoginScreen] users[0] = ${users.first}');
      }

      // Check biometrics
      final canCheckBiometrics = await auth.canCheckBiometrics;
      final isDeviceSupported = await auth.isDeviceSupported();
      _hasBiometricHardware = canCheckBiometrics || isDeviceSupported;

    } catch (e) {
      debugPrint('Error in LoginScreen init: $e');
    } finally {
      setState(() => _isLoading = false);
      _animCtrl.forward();
    }
  }
  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnack('يرجى إدخال اسم المستخدم وكلمة المرور', AppColors.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 🎯 استخدام دالة login من قاعدة البيانات بدلاً من التحقق اليدوي هنا
      // هذه الدالة تتعامل بذكاء مع التشفير (Bcrypt) وتدعم كلمات المرور القديمة العادية
      final userMap = await db.login(username, password);

      if (userMap != null) {
        // التحقق مما إذا كان الحساب موقوفاً
        if (userMap['is_active'] == 0) {
          _showSnack('هذا الحساب غير نشط، يرجى مراجعة الإدارة', AppColors.warning);
          return;
        }

        // تسجيل الدخول ناجح، توجيه المستخدم وتحديث حالة التطبيق
        await _setLoginState(userMap);
        return;
      }

      // في حال كانت البيانات غير مطابقة
      _showSnack('اسم المستخدم أو كلمة المرور غير صحيحة', AppColors.error);
    } catch (e) {
      debugPrint('Login Error: $e');
      _showSnack('حدث خطأ أثناء تسجيل الدخول', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'الرجاء التحقق بالبصمة لتسجيل الدخول',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        setState(() => _isLoading = true);
        final prefs = await SharedPreferences.getInstance();
        final lastUsername = prefs.getString('last_logged_in_username');
        
        final users = await db.getAllUsers();
        Map<String, dynamic>? targetUser;

        if (lastUsername != null) {
          targetUser = users.cast<Map<String,dynamic>?>().firstWhere(
            (u) => u?['username'] == lastUsername && u?['has_biometric'] == 1,
            orElse: () => null,
          );
        }

        if (targetUser == null) {
          final biometricUsers = users.where((u) => u['has_biometric'] == 1).toList();
          if (biometricUsers.length == 1) {
            targetUser = biometricUsers.first;
          } else if (users.length == 1) {
            targetUser = users.first;
          } else {
            _showSnack('يرجى تسجيل الدخول بكلمة المرور لتحديد الحساب أولاً', AppColors.warning);
            setState(() => _isLoading = false);
            return;
          }
        }

        await _setLoginState(targetUser);
      }
    } catch (e) {
      _showSnack('فشل التحقق بالبصمة', AppColors.error);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setLoginState(Map<String, dynamic> userMap) async {
    final userModel = UserModel.fromMap(userMap);
    
    // Set global CurrentUser
    CurrentUser.id = userModel.id!;
    CurrentUser.username = userModel.username;
    CurrentUser.fullName = userModel.fullName;
    CurrentUser.role = userModel.role;
    CurrentUser.hasBiometric = userModel.hasBiometric;
    
    // Load permissions
    // Set permissions
    CurrentUser.securePermissions = userModel.securePermissions;

    // Set riverpod state
    ref.read(currentUserProvider.notifier).state = userModel;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('last_logged_in_username', userModel.username);
    await prefs.setString('last_active_time', DateTime.now().toIso8601String());

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainMenuScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyMedium, AppColors.navy],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Background decorative circles
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Icon & Name
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2),
                            ),
                            child: const Icon(Icons.inventory_2_rounded, size: 64, color: AppColors.primary),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'المخازن الذكي',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // The Form Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.navyCard,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _buildForm(),
                          ),
                          
                          // Biometric Button
                          if (_hasBiometricHardware) ...[
                            const SizedBox(height: 30),
                            GestureDetector(
                              onTap: _authenticateBiometric,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                    ),
                                    child:  Icon(Icons.fingerprint_rounded, size: 40, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('الدخول بالبصمة', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _usernameCtrl,
          icon: Icons.person_outline_rounded,
          label: 'اسم المستخدم',
        ),
        const SizedBox(height: 16),
        
        _buildTextField(
          controller: _passwordCtrl,
          icon: Icons.lock_outline_rounded,
          label: 'كلمة المرور',
          isPassword: true,
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.navy,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
          child: const Text(
            'تسجيل الدخول',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool isPassword = false,
  }) {
    return TextField(

      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(

        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.8)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
