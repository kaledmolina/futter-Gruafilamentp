import '../services/api_service.dart';
import '../services/database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';

class InspectionRepository {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;

  Future<void> submitInspection(Map<String, dynamic> inspectionData) async {
    final hasConnection = await _hasConnection();
    
    // Guardar fecha localmente inmediatamente para bloquear la UI
    await _dbService.setLastInspectionDate(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    
    if (hasConnection) {
      try {
        await _apiService.submitInspection(inspectionData);
        await _dbService.deletePendingInspection(
          await _findPendingInspection(inspectionData),
        );
      } catch (e) {
        await _queueInspection(inspectionData);
        rethrow;
      }
    } else {
      await _queueInspection(inspectionData);
    }
  }

  Future<bool> hasCompletedInspectionToday() async {
    // 1. Revisar metadatos locales (lo más rápido y funciona offline)
    final lastDateTimestamp = await _dbService.getLastInspectionDate();
    if (lastDateTimestamp > 0) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastDateTimestamp * 1000);
      final now = DateTime.now();
      if (lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day) {
        return true;
      }
    }

    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        final apiResult = await _apiService.hasCompletedInspectionToday();
        if (apiResult) {
          // Actualizar local si la API dice que sí
          await _dbService.setLastInspectionDate(DateTime.now().millisecondsSinceEpoch ~/ 1000);
          return true;
        }
      } catch (e) {
        // Fallback a chequeo local de pendientes
      }
    }
    
    // 3. Revisar pendientes (por si acaso se guardó pero no se actualizó metadata)
    return await _checkLocalInspectionToday();
  }

  Future<List<Map<String, dynamic>>> getPendingInspections() async {
    final pending = await _dbService.getPendingInspections();
    return pending.map((item) {
      final data = jsonDecode(item['inspection_data'] as String);
      return {
        'id': item['id'],
        'data': data,
        'created_at': item['created_at'],
        'retry_count': item['retry_count'],
        'last_error': item['last_error'],
      };
    }).toList();
  }

  Future<bool> _hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<void> _queueInspection(Map<String, dynamic> inspectionData) async {
    await _dbService.addPendingInspection(inspectionData);
  }

  Future<int> _findPendingInspection(Map<String, dynamic> inspectionData) async {
    final pending = await _dbService.getPendingInspections();
    for (var item in pending) {
      final data = jsonDecode(item['inspection_data'] as String);
      if (_inspectionDataEquals(data, inspectionData)) {
        return item['id'] as int;
      }
    }
    return 0;
  }

  bool _inspectionDataEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  Future<bool> _checkLocalInspectionToday() async {
    final pending = await _dbService.getPendingInspections();
    final now = DateTime.now();
    for (var item in pending) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (item['created_at'] as int) * 1000,
      );
      if (createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day) {
        return true;
      }
    }
    return false;
  }
}

