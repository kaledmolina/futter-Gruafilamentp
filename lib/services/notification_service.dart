import 'package:flutter/foundation.dart'; // <-- AÑADIDO: Import para debugPrint
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'auth_service.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();

  Future<void> initialize() async {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      if (await AuthService.instance.isLoggedIn()) {
        await _apiService.updateFcmToken(newToken);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // CAMBIO: Se usa debugPrint
      debugPrint('Notificación en primer plano recibida: ${message.notification?.title}');
    });
  }

  // CAMBIO: Ahora devuelve un String con el error, o null si todo fue exitoso.
  Future<String?> requestPermissionAndRegisterToken() async {
    // CAMBIO: Se usa debugPrint
    debugPrint("==> Iniciando proceso de permisos y registro de token...");
    
    debugPrint("1. Solicitando permisos de notificación...");
    NotificationSettings settings = await _firebaseMessaging.requestPermission();
    debugPrint("... Estado del permiso: ${settings.authorizationStatus}");

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint("2. Permiso concedido. Obteniendo token FCM...");
        final fcmToken = await _firebaseMessaging.getToken();
        if (fcmToken != null) {
          debugPrint("... Token FCM obtenido: $fcmToken");
          try {
            debugPrint("3. Enviando token al backend...");
            await _apiService.updateFcmToken(fcmToken);
            debugPrint("... Token FCM registrado exitosamente en el backend.");
            return null; // Éxito
          } catch (e) {
            final errorMessage = "Error al enviar token al servidor: $e";
            debugPrint("!!! ERROR al registrar el token FCM en el backend.");
            debugPrint("    URL de la API: ${_apiService.getBaseUrl()}");
            debugPrint("    Error: $e");
            return errorMessage; // Devuelve el error
          }
        } else {
            const errorMessage = "No se pudo obtener el token del dispositivo.";
            debugPrint("!!! ERROR: $errorMessage");
            return errorMessage; // Devuelve el error
        }
    } else {
        const errorMessage = "Permiso de notificación denegado.";
        debugPrint("!!! $errorMessage");
        return errorMessage; // Devuelve el error
    }
  }
}