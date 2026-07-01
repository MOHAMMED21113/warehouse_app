import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';

class HashUtil {
  static Future<String> hashPassword(String password) async {
    return await compute(_hashInIsolate, password);
  }

  static String _hashInIsolate(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool verifyPassword(String inputPassword, String hashedPassword) {
    try {
      return BCrypt.checkpw(inputPassword, hashedPassword);
    } catch (e) {
      debugPrint('⚠️ خطأ في التحقق من كلمة المرور: $e');
      return false;
    }
  }
}