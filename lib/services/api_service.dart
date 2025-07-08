import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/orden_model.dart';

class ApiService {
  // IMPORTANTE: Esta URL DEBE ser la URL pública que te proporciona IDX/Firebase Studio
  // para el puerto 8000. Búscala en la pestaña "Ports" o en las notificaciones del editor.
  // Debe ser algo como: https://8000-tu-proyecto-....cloudworkstations.dev
  static const String _baseUrl = 'https://gruap.kaledcloud.tech/api';

  // Getter para poder imprimir la URL en los logs de depuración.
  // ASEGÚRATE DE QUE ESTE MÉTODO EXISTA EN TU ARCHIVO
  String getBaseUrl() => _baseUrl;

  Future<bool> checkApiStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/v1/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print("Fallo en la verificación de la API: $e");
      return false;
    }
  }
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }
  Future<Orden> getOrderDetails(int orderId) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/v1/orders/$orderId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return Orden.fromJson(data);
  }

  Future<Map<String, dynamic>> acceptOrder(int orderId) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/orders/$orderId/accept'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }
  Future<Map<String, dynamic>> closeOrder(int orderId) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/orders/$orderId/close'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }
  Future<Map<String, dynamic>> rejectOrder(int orderId) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/v1/orders/$orderId/reject'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }
  Future<void> updateFcmToken(String fcmToken) async {
    final token = await AuthService.instance.getToken();
    if (token == null) return;
    await http.post(
      Uri.parse('$_baseUrl/v1/update-fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcm_token': fcmToken}),
    );
  }
  Future<List<dynamic>> getOrders() async {
      final token = await AuthService.instance.getToken();
      final response = await http.get(
          Uri.parse('$_baseUrl/v1/orders'),
          headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
          },
      );
      return _handleResponse(response);
  }
  
  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'Ocurrió un error en la API');
    }
  }
}