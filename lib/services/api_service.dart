import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/orden_model.dart';

class ApiService {
  static const String baseUrl = 'https://gruap.kaledcloud.tech/api';
  static const String domain = 'https://gruap.kaledcloud.tech';

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
    await http.post(
      Uri.parse('$baseUrl/v1/update-fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcm_token': fcmToken}),
    );
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

  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['message'] ?? 'Ocurrió un error');
    }
  }
}
