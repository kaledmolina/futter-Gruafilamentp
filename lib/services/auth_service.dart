import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  
  final _api = ApiService();
  User? _currentUser;

  Future<bool> login(String email, String password) async {
    try {
      final response = await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', response['access_token']);
      // Guardamos los datos del usuario después del login
      _currentUser = User.fromJson(response['user']);
      await prefs.setString('user_data', jsonEncode(response['user']));
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    _currentUser = null;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
  
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Método para obtener el usuario actual
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      _currentUser = User.fromJson(jsonDecode(userDataString));
      return _currentUser;
    }
    return null;
  }
}
