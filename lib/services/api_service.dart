import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/orden_model.dart';
import '../models/user_model.dart';

class ApiService {
  static const String _baseUrlDomain = 'https://sistema.asisvehjyh.com';
  static const String baseUrl = '$_baseUrlDomain/api';
  static const String domain = _baseUrlDomain;

  String getBaseUrl() => baseUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  Future<bool> checkApiStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/v1/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Fallo en la verificación de la API: $e");
      return false;
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    final token = await AuthService.instance.getToken();
    if (token == null) return;
    final response = await http.post(
      Uri.parse('$baseUrl/v1/update-fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcm_token': fcmToken}),
    );
    _handleResponse(response);
  }

  Future<Map<String, dynamic>> getOrders({int page = 1, String status = 'todas'}) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders?page=$page&status=$status'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<Orden> getOrderDetails(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/$orderNumber'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return Orden.fromJson(data);
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<Orden> acceptOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/accept'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return Orden.fromJson(data['order']);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<Orden> closeOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/close'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return Orden.fromJson(data['order']);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<Map<String, dynamic>> rejectOrder(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/reject'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  // CAMBIO: Acepta un String en lugar de un int
  Future<void> updateDetails(String orderNumber, Map<String, String> data) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/update-details'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    _handleResponse(response);
  }
  
  // CAMBIO: Acepta un String en lugar de un int
  Future<List<dynamic>> getUploadedPhotos(String orderNumber) async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/orders/$orderNumber/photos'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as List<dynamic>;
    }
    return data as List<dynamic>;
  }

  // NUEVO: Método para enviar la inspección
  Future<void> submitInspection(Map<String, dynamic> data) async {
    final token = await AuthService.instance.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v1/inspections'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    _handleResponse(response);
  }

  // NUEVO: Método para obtener el perfil completo del usuario
  Future<User> getProfile() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/profile'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return User.fromJson(data);
  }
  Future<bool> hasCompletedInspectionToday() async {
    final token = await AuthService.instance.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/v1/inspections/check-today'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final data = _handleResponse(response);
    return data['completed_today'] ?? false;
  }

  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'Ocurrió un error');
    }
  }
}
