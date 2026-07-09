// lib/core/widgets/transaction_lock_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bcrypt/bcrypt.dart';
import '../constants/app_colors.dart';
import '../providers/global_providers.dart';
import '../services/biometric_service.dart';
import '../../data/models/current_user.dart';

class TransactionLockDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const TransactionLockDialog({super.key, required this.onSuccess});

  @override
  ConsumerState<TransactionLockDialog> createState() => _TransactionLockDialogState();
}

class _TransactionLockDialogState extends ConsumerState<TransactionLockDialog>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometric = BiometricService();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _hasFailed = false;
  bool _usePassword = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Default to password if user doesn't have biometric enabled
    _usePassword = !CurrentUser.hasBiometric;
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      setState(() {
        _hasFailed = true;
        _errorMessage = 'الرجاء إدخال كلمة المرور';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });

    try {
      final db = ref.read(databaseHelperProvider);
      final user = await db.getUserByUsername(CurrentUser.username ?? '');
      
      if (user != null && BCrypt.checkpw(password, user['password_hash'])) {
        widget.onSuccess();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _hasFailed = true;
          _errorMessage = 'كلمة المرور غير صحيحة';
        });
      }
    } catch (e) {
      setState(() {
        _hasFailed = true;
        _errorMessage = 'حدث خطأ أثناء التحقق';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyBiometric() async {
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });
    final success = await _biometric.authenticateWithBiometrics();
    if (success) {
      widget.onSuccess();
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _hasFailed = true;
        _errorMessage = 'فشل التحقق من البصمة';
        // Suggest password after biometric failure
        _usePassword = true; 
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final Color cardBg  = isDark ? AppColors.navyMedium : AppColors.textPrimary;
    final Color textMain = isDark ? AppColors.textPrimary : AppColors.navy;
    final Color textSub  = isDark ? AppColors.textSecondary : AppColors.textHint;
    final Color inputFill = isDark ? AppColors.navy : const Color(0xFFF8FAFC);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ─── رأس الحوار ───
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navy, AppColors.navyMedium],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _hasFailed
                        ? AppColors.error.withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _hasFailed
                          ? AppColors.error.withOpacity(0.4)
                          : AppColors.primary.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _usePassword ? Icons.lock_person_rounded : Icons.fingerprint_rounded,
                    size: 30,
                    color: _hasFailed ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تأكيد العملية',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _usePassword 
                  ? 'يرجى إدخال كلمة المرور لتأكيد العملية'
                  : 'يرجى استخدام بصمتك لتأكيد العملية المالية',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary.withOpacity(0.6), fontSize: 13, height: 1.4),
              ),
            ]),
          ),
          
          // ─── رسالة الفشل ───
          if (_hasFailed)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
            
          // ─── حقل كلمة المرور ───
          if (_usePassword)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: TextStyle(color: textMain, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'كلمة المرور',
                  hintStyle: TextStyle(color: textSub),
                  filled: true,
                  fillColor: inputFill,
                  prefixIcon: Icon(Icons.lock_rounded, color: AppColors.primary.withOpacity(0.7)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: textSub, size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _verifyPassword(),
              ),
            ),
            
          // ─── تبديل إلى كلمة المرور ───
          if (!_usePassword && CurrentUser.hasBiometric)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: () => setState(() {
                  _usePassword = true;
                  _hasFailed = false;
                }),
                child: const Text('استخدام كلمة المرور بدلاً من ذلك', style: TextStyle(color: AppColors.primary)),
              ),
            ),

          // ─── تبديل إلى البصمة ───
          if (_usePassword && CurrentUser.hasBiometric)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                onPressed: () => setState(() {
                  _usePassword = false;
                  _hasFailed = false;
                }),
                label: const Text('استخدام البصمة'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),

          // ─── أزرار الإجراءات ───
          Padding(
            padding: EdgeInsets.fromLTRB(20, _usePassword && !CurrentUser.hasBiometric ? 20 : 12, 20, 24),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSub,
                    side: BorderSide(color: isDark ? AppColors.navyBorder : AppColors.textHint.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('إلغاء', style: TextStyle(color: textSub, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: !_isLoading
                        ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : (_usePassword ? _verifyPassword : _verifyBiometric),
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                        : Icon(_usePassword ? Icons.check_circle_outline_rounded : Icons.fingerprint_rounded, size: 20),
                    label: Text(
                      _isLoading ? 'جاري التحقق...' : 'تأكيد',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.navy,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      disabledForegroundColor: AppColors.navy.withOpacity(0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}