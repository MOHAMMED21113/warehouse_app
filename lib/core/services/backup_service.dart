// lib/utils/backup_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../database/database_helper.dart';

class BackupService {
  final DatabaseHelper db = DatabaseHelper.instance;

  // ====================  عمل نسخة احتياطية ذكية (تضم كل شيء) ====================
  Future<Map<String, dynamic>> backupAllData() async {
    Map<String, dynamic> result = {
      'success': false,
      'path': null,
      'error': null,
    };

    try {
      // 1. تجميع جميع البيانات باستخدام الدالة الجديدة الشاملة
      final allTablesData = await db.exportDatabaseToJson();

      final backupData = {
        'backup_date': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
        'data': allTablesData, // تضم كل الجداول بما فيها الخزينة والسندات
      };

      final jsonData = jsonEncode(backupData);
      final bytes = utf8.encode(jsonData);

      final fileName =
          'warehouse_backup_'
          '${DateTime.now().year}_'
          '${DateTime.now().month.toString().padLeft(2, '0')}_'
          '${DateTime.now().day.toString().padLeft(2, '0')}_'
          '${DateTime.now().hour.toString().padLeft(2, '0')}'
          '${DateTime.now().minute.toString().padLeft(2, '0')}'
          '.json';

      // 2. استخدام FilePicker ليختار المستخدم مكان الحفظ بحرية
      try {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
          fileName: fileName,
          bytes: bytes,
        );
        if (outputFile != null) {
          result['success'] = true;
          result['path'] = outputFile;
          return result;
        }
      } catch (_) {
        // في حال تم الإغلاق أو الفشل
      }

      // 3. بديل: الحفظ في التنزيلات (Downloads) ليتمكن المستخدم من الوصول إليها بسهولة
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final backupDir = Directory('${dir.path}/WarehouseBackups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      result['success'] = true;
      result['path'] = file.path;
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  // ==================== 🔄 استعادة البيانات (ربط بالدالة الجبرية) ====================
  Future<Map<String, dynamic>> restoreFromBackup() async {
    Map<String, dynamic> result = {'success': false, 'error': null};

    try {
      String? filePath;

      // 1. فتح مدير الملفات لاختيار النسخة الاحتياطية
      try {
        FilePickerResult? pickerResult = await FilePicker.platform.pickFiles(
          dialogTitle: 'اختر ملف النسخة الاحتياطية',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (pickerResult != null && pickerResult.files.isNotEmpty) {
          filePath = pickerResult.files.single.path;
        }
      } catch (_) {}

      if (filePath == null) {
        result['error'] = 'لم يتم اختيار ملف النسخة الاحتياطية';
        return result;
      }

      // 2. قراءة الملف واستخراج البيانات
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

      if (backupData['data'] == null) {
        result['error'] = 'ملف النسخة الاحتياطية تالف أو غير صالح';
        return result;
      }

      // 🔴 3. السر هنا: توجيه البيانات للدالة الجبرية القوية في DatabaseHelper
      // بدلاً من محاولة فك التشفير ومواجهة القيود هنا
      await db.restoreDatabaseFromJson(backupData['data']);

      result['success'] = true;
      result['message'] = 'تم استعادة البيانات بنجاح';

    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }
}