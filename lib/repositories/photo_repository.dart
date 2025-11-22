import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/photo_status_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PhotoRepository {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<PhotoDisplay>> getPhotos(String orderNumber) async {
    final hasConnection = await _hasConnection();
    final List<PhotoDisplay> photos = [];

    // Obtener fotos subidas desde API si hay conexión
    if (hasConnection) {
      try {
        final uploaded = await _apiService.getUploadedPhotos(orderNumber);
        photos.addAll(uploaded.map((p) => PhotoDisplay(
          remoteId: p['id'],
          path: p['path'],
          url: p['url'],
          status: PhotoStatusType.uploaded,
        )));
      } catch (e) {
        // Si falla, continuar con fotos locales
      }
    }

    // Obtener fotos pendientes desde DB local
    final pending = await _dbService.getPendingPhotosForOrder(orderNumber);
    photos.addAll(pending.map((p) => PhotoDisplay(
      localId: p['id'] as int,
      path: p['image_path'] as String,
      status: PhotoStatusType.local,
    )));

    return photos;
  }

  Future<void> addPhoto(String orderNumber, String imagePath) async {
    await _dbService.addPendingPhoto(orderNumber, imagePath);
  }

  Future<List<Map<String, dynamic>>> getPendingPhotos() async {
    return await _dbService.getPendingPhotos();
  }

  Future<List<Map<String, dynamic>>> getPendingPhotosForOrder(String orderNumber) async {
    return await _dbService.getPendingPhotosForOrder(orderNumber);
  }

  Future<void> deletePendingPhoto(int id) async {
    await _dbService.deletePendingPhoto(id);
  }

  Future<bool> _hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }
}

