// lib/core/services/google_drive_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// 1. كلاس وسيط لدمج مصادقة جوجل مع مكتبات الـ API
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

// 2. الكلاس الأساسي للنسخ الاحتياطي
class GoogleDriveService {
  // الصلاحية المطلوبة للوصول إلى الملفات التي ينشئها التطبيق في Drive
  final List<String> _scopes = [drive.DriveApi.driveFileScope];

  // اسم المجلد الذي سيتم إنشاؤه في جوجل درايف
  final String _folderName = 'تطبيق المخازن - نسخ احتياطي';

  // ====== 🆕 دالة جديدة للبحث عن المجلد أو إنشائه ======
  Future<String?> _getOrCreateBackupFolder(drive.DriveApi driveApi) async {
    try {
      // 1. البحث: هل المجلد موجود مسبقاً؟
      final query = "mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false";
      final folderList = await driveApi.files.list(q: query, spaces: 'drive');

      if (folderList.files != null && folderList.files!.isNotEmpty) {
        // المجلد موجود، نرجع كود الـ ID الخاص به
        return folderList.files!.first.id;
      }

      // 2. إذا لم يكن موجوداً، نقوم بإنشاء مجلد جديد
      final newFolder = drive.File();
      newFolder.name = _folderName;
      newFolder.mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(newFolder);
      return createdFolder.id; // نرجع الـ ID للمجلد الجديد
    } catch (e) {
      print('خطأ في جلب أو إنشاء المجلد: $e');
      return null;
    }
  }
  // ======================================================

  Future<Map<String, dynamic>> backupDatabaseToDrive() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // 1. التهيئة
      await googleSignIn.initialize();

      // 2. المصادقة
      GoogleSignInAccount? account;
      try {
        account = await googleSignIn.authenticate(scopeHint: _scopes);
      } catch (e) {
        return {'success': false, 'message': 'تم إلغاء العملية أو حدث خطأ أثناء المصادقة'};
      }

      if (account == null) {
        return {'success': false, 'message': 'تم إلغاء تسجيل الدخول'};
      }

      // 3. التفويض
      var authorization = await account.authorizationClient.authorizationForScopes(_scopes);
      if (authorization == null) {
        authorization = await account.authorizationClient.authorizeScopes(_scopes);
      }

      final token = authorization?.accessToken;
      if (token == null) {
        return {'success': false, 'message': 'فشل في الحصول على صلاحية الرفع إلى Drive'};
      }

      // 4. إعداد عميل الاتصال
      final authHeaders = {'Authorization': 'Bearer $token'};
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      // --- 🆕 جلب كود المجلد المخصص من جوجل درايف ---
      final folderId = await _getOrCreateBackupFolder(driveApi);

      // 5. جلب مسار قاعدة البيانات المحلية
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'warehouse.db');
      final file = File(path);

      if (!await file.exists()) {
        return {'success': false, 'message': 'لم يتم العثور على قاعدة البيانات للنسخ الاحتياطي'};
      }

      // 6. تجهيز الملف
      final driveFile = drive.File();
      final timestamp = DateTime.now().toString().replaceAll(':', '-').split('.')[0];
      driveFile.name = 'Warehouse_Backup_$timestamp.db';

      // --- 🆕 توجيه الملف لكي يتم حفظه داخل المجلد المخصص ---
      if (folderId != null) {
        driveFile.parents = [folderId];
      }

      // الرفع للسحابة
      final media = drive.Media(file.openRead(), file.lengthSync());
      await driveApi.files.create(driveFile, uploadMedia: media);

      // 7. تسجيل الخروج
      await googleSignIn.signOut();

      return {'success': true, 'message': 'تم الرفع بنجاح إلى مجلد "$_folderName" ☁️'};

    } catch (e) {
      print('خطأ في النسخ الاحتياطي السحابي: $e');
      return {'success': false, 'message': 'حدث خطأ غير متوقع: $e'};
    }
  }
}