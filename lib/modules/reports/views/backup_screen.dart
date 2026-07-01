// lib/modules/reports/views/backup_screen.dart
// 🆕 تصميم كحلي + ذهبي + دمج Google Drive — محول إلى Riverpod
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/services/google_drive_service.dart';
import '../../../core/services/backup_service.dart';
import '../../main_menu/views/main_menu_screen.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  final BackupService _backupService = BackupService();

  AppThemeColors get _colors =>
      AppThemeColors(isDark: ref.watch(themeModeProvider) == ThemeMode.dark);

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating));
  }

  Future<void> _createCloudBackup() async {
    setState(() => _isLoading = true);
    final result = await GoogleDriveService().backupDatabaseToDrive();
    setState(() => _isLoading = false);
    _snack(result['message'], result['success'] ? AppColors.success : AppColors.error);
  }

  Future<void> _createLocalBackup() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) { _snack('يرجى منح صلاحية التخزين', AppColors.error); return; }
    setState(() => _isLoading = true);
    final result = await _backupService.backupAllData();
    setState(() => _isLoading = false);
    _snack(result['success'] ? 'تم حفظ النسخة بنجاح' : '${result['error']}', result['success'] ? AppColors.success : AppColors.error);
  }

  Future<void> _restoreBackup() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) { _snack('يرجى منح صلاحية التخزين', AppColors.error); return; }
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _colors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.warning_rounded, color: AppColors.error)), const SizedBox(width: 10), Text('تأكيد الاستعادة', style: TextStyle(color: _colors.textMain, fontWeight: FontWeight.bold))]),
      content: Text('سيتم تدمير جميع البيانات الحالية. هل أنت متأكد؟', style: TextStyle(color: _colors.textSub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: _colors.textSub))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('استعادة', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    ));
    if (confirm != true) return;
    setState(() => _isLoading = true);
    final result = await _backupService.restoreFromBackup();
    if (result['success'] == true) {
      _snack('تمت الاستعادة بنجاح', AppColors.success);
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainMenuScreen()), (route) => false);
    } else {
      _snack('${result['error']}', AppColors.error);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.appBarBg, foregroundColor: AppColors.primary, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: const Text('النسخ الاحتياطي', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: AppColors.warning),
        const SizedBox(height: 16),
        Text('جاري معالجة البيانات...', style: TextStyle(color: colors.textSub, fontWeight: FontWeight.bold)),
      ]))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMedium]), shape: BoxShape.circle, border: Border.all(color: AppColors.warning.withOpacity(0.3))), child: const Icon(Icons.cloud_sync_rounded, size: 50, color: AppColors.primary)),
          const SizedBox(height: 20),
          Text('النسخ الاحتياطي للبيانات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textMain)),
          const SizedBox(height: 8),
          Text('يمكنك عمل نسخة احتياطية محلية أو سحابية\nللحفاظ على بياناتك بأمان', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.textSub)),
          const SizedBox(height: 36),
          _btn('نسخ احتياطي سحابي (Google Drive)', Icons.cloud_upload_rounded, AppColors.info, _createCloudBackup),
          const SizedBox(height: 14),
          _btn('نسخ احتياطي (محلي)', Icons.save_alt_rounded, AppColors.primary, _createLocalBackup),
          const SizedBox(height: 14),
          _btnOutline('استعادة البيانات (محلي)', Icons.restore_rounded, AppColors.warning, _restoreBackup),
          const SizedBox(height: 28),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.warning.withOpacity(colors.scaffoldBg == AppColors.navy ? 0.15 : 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withOpacity(0.3))), child: Row(children: [const Icon(Icons.warning_rounded, color: AppColors.warning, size: 20), const SizedBox(width: 10), Expanded(child: Text('تنبيه: استعادة البيانات ستحل محل البيانات الحالية. تأكد من عمل نسخة احتياطية أولاً.', style: TextStyle(fontSize: 12, color: colors.textSub)))])),
        ]),
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) => SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));
  Widget _btnOutline(String label, IconData icon, Color color, VoidCallback onTap) => SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));
}