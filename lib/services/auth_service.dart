import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  // Patrón Singleton para tener una única instancia de este servicio.
  AuthService._();
  static final instance = AuthService._();

  final _api = ApiService();

  // Llama a la API para iniciar sesión y guarda el token si es exitoso.
  Future<bool> login(String email, String password) async {
    try {
      final response = await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', response['access_token']);
      return true;
    } catch (e) {
      print(e); // Imprime el error para depuración.
      return false;
    }
  }

  // Cierra la sesión eliminando el token guardado.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Verifica si hay un token guardado para saber si el usuario está logueado.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }

  // Obtiene el token de autenticación guardado.
  Future<String?> getToken() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
  }
}