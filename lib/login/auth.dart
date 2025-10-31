import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  static const _kLoggedIn = 'logged_in';
  static const _kName = 'name';
  static const _kAge = 'age';
  static const _kHeight = 'height';
  static const _kWeight = 'weight';
  static const _kUserId = 'user_id';
  static const _kEmail = 'email';
  static const _kPassword = 'password'; // 注意: デモ用途のみ

  Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLoggedIn) ?? false;
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLoggedIn, false);
  }

  Future<void> saveProfile({
    required String name,
    required int age,
    required double height,
    required double weight,
    required String userId,
    required String password,
    String? email,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, name);
    await sp.setInt(_kAge, age);
    await sp.setDouble(_kHeight, height);
    await sp.setDouble(_kWeight, weight);
    await sp.setString(_kUserId, userId);
    await sp.setString(_kPassword, password);
    if (email != null) await sp.setString(_kEmail, email);
    await sp.setBool(_kLoggedIn, true);
  }

  Future<void> setLoggedInUser({required String userId, String? email}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUserId, userId);
    if (email != null) await sp.setString(_kEmail, email);
    await sp.setBool(_kLoggedIn, true);
  }

  Future<bool> login({required String userId, required String password}) async {
    final sp = await SharedPreferences.getInstance();
    final savedId = sp.getString(_kUserId);
    final savedPw = sp.getString(_kPassword);
    final ok = (savedId != null && savedPw != null &&
        userId == savedId && password == savedPw);
    if (ok) {
      await sp.setBool(_kLoggedIn, true);
    }
    return ok;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'name': sp.getString(_kName),
      'age': sp.getInt(_kAge),
      'height': sp.getDouble(_kHeight),
      'weight': sp.getDouble(_kWeight),
      'userId': sp.getString(_kUserId),
      'email': sp.getString(_kEmail),
    };
  }
}

