import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'database_service.dart';
import 'auth_service.dart';
import '../models/photo_status_model.dart';

class UploadService {
  static final UploadService instance = UploadService._init();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  final _uploadStatusController = StreamController<PhotoDisplay>.broadcast();
  Stream<PhotoDisplay> get uploadStatusStream => _uploadStatusController.stream;

  UploadService._init();

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi)) {
        debugPrint("Conexión detectada. Intentando sincronizar...");
        syncPendingUploads();
      }
    });
    syncPendingUploads();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _uploadStatusController.close();
  }

  Future<void> syncPendingUploads() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final db = DatabaseService.instance;
    final pendingPhotos = await db.getPendingPhotos();
    
    debugPrint("Se encontraron ${pendingPhotos.length} fotos pendientes.");

    for (var photo in pendingPhotos) {
      final photoId = photo['id'] as int;
      final photoPath = photo['image_path'] as String;
      final orderNumber = photo['order_number'] as String;


      _uploadStatusController.add(PhotoDisplay(localId: photoId, path: photoPath, status: PhotoStatusType.uploading));
      
      try {
        final success = await _uploadPhoto(orderNumber, photoPath);
        if (success) {
          await db.deletePendingPhoto(photoId);
          _uploadStatusController.add(PhotoDisplay(localId: photoId, path: photoPath, status: PhotoStatusType.uploaded));
        } else {
           _uploadStatusController.add(PhotoDisplay(localId: photoId, path: photoPath, status: PhotoStatusType.error));
        }
      } catch (e, stackTrace) {
        debugPrint("Error subiendo foto $photoId ($photoPath): $e");
        debugPrint("Stack trace: $stackTrace");
        _uploadStatusController.add(PhotoDisplay(
          localId: photoId, 
          path: photoPath, 
          status: PhotoStatusType.error,
          errorMessage: e.toString(),
        ));
      }
    }
    _isSyncing = false;
  }
  
  Future<bool> _uploadPhoto(String orderNumber, String imagePath) async {
    final token = await AuthService.instance.getToken();
    if (token == null) return false;

    final uri = Uri.parse('${ApiService.baseUrl}/v1/orders/$orderNumber/upload-photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('photo', imagePath));
      
    final response = await request.send();
    
    if (response.statusCode == 200) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error al borrar archivo local: $e");
      }
      return true;
    }
    return false;
  }
}
