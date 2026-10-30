import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static Future<bool> isLoggedIn() async {
    return FirebaseAuth.instance.currentUser != null;
  }

  static Future<bool> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      print('Ошибка входа: $e');
      return false;
    }
  }

  static Future<bool> register(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      print('Ошибка регистрации: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
