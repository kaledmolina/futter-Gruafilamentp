import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/upload_service.dart';

enum SyncStatus { idle, syncing, error }

class SyncService {
  static final SyncService instance = SyncService._init();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;
  
  // StreamController para notificar cambios en operaciones pendientes
  final _pendingOperationsController = StreamController<String>.broadcast();
  Stream<String> get pendingOperationsStream => _pendingOperationsController.stream;

  SyncService._init();

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) || 
          result.contains(ConnectivityResult.wifi)) {
        debugPrint("Conexión detectada. Iniciando sincronización...");
        sync();
      }
    });
    sync();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingOperationsController.close();
  }
  
  // Método para notificar cambios manualmente (útil cuando se agregan nuevas operaciones)
  void notifyPendingOperationChange(String orderNumber) {
    if (!_pendingOperationsController.isClosed) {
      _pendingOperationsController.add(orderNumber);
    }
  }

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      await _dbService.setSyncStatus('syncing');
      
      // 1. Descargar órdenes actualizadas del servidor
      await _syncOrdersFromServer();
      
      // 2. Subir operaciones pendientes
      await _syncPendingOperations();
      
      // 3. Subir inspecciones pendientes
      await _syncPendingInspections();
      
      // 4. Subir fotos pendientes (ya manejado por UploadService)
      await UploadService.instance.syncPendingUploads();
      
      await _dbService.setSyncStatus('idle');
      debugPrint("Sincronización completada exitosamente");
      // Notificar que se completó la sincronización (vacío significa actualizar todas)
      _pendingOperationsController.add('');
    } catch (e) {
      await _dbService.setSyncStatus('error');
      debugPrint("Error en sincronización: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncOrdersFromServer() async {
    try {
      final response = await _apiService.getOrders(page: 1, status: 'todas');
      final ordersData = response['data'] as List;
      
      final orders = ordersData.map((json) => _orderJsonToDbMap(json)).toList();
      await _dbService.saveOrders(orders);
      await _dbService.setLastSyncOrders(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      debugPrint("Órdenes sincronizadas: ${orders.length}");
    } catch (e) {
      debugPrint("Error al sincronizar órdenes: $e");
    }
  }

  Future<void> _syncPendingOperations() async {
    final pending = await _dbService.getPendingOperations();
    debugPrint("Sincronizando ${pending.length} operaciones pendientes");
    
    for (var operation in pending) {
      final id = operation['id'] as int;
      final type = operation['operation_type'] as String;
      final orderNumber = operation['order_number'] as String;
      final data = jsonDecode(operation['operation_data'] as String);
      
      try {
        switch (type) {
          case 'accept':
            await _apiService.acceptOrder(orderNumber);
            break;
          case 'close':
            await _apiService.closeOrder(orderNumber);
            break;
          case 'reject':
            await _apiService.rejectOrder(orderNumber);
            break;
          case 'update_details':
            await _apiService.updateDetails(
              orderNumber,
              Map<String, String>.from(data),
            );
            break;
        }
        
        await _dbService.deletePendingOperation(id);
        debugPrint("Operación $type para orden $orderNumber sincronizada");
        // Notificar que se eliminó una operación pendiente para esta orden
        _pendingOperationsController.add(orderNumber);
      } catch (e) {
        await _dbService.incrementRetryCount(id, e.toString());
        debugPrint("Error al sincronizar operación $id: $e");
      }
    }
  }

  Future<void> _syncPendingInspections() async {
    final pending = await _dbService.getPendingInspections();
    debugPrint("Sincronizando ${pending.length} inspecciones pendientes");
    
    for (var inspection in pending) {
      final id = inspection['id'] as int;
      final data = jsonDecode(inspection['inspection_data'] as String);
      
      try {
        await _apiService.submitInspection(
          Map<String, dynamic>.from(data),
        );
        await _dbService.deletePendingInspection(id);
        debugPrint("Inspección $id sincronizada");
      } catch (e) {
        await _dbService.incrementInspectionRetryCount(id, e.toString());
        debugPrint("Error al sincronizar inspección $id: $e");
      }
    }
  }

  Map<String, dynamic> _orderJsonToDbMap(Map<String, dynamic> json) {
    return {
      'id': json['id'],
      'numero_orden': json['numero_orden'],
      'numero_expediente': json['numero_expediente'],
      'nombre_cliente': json['nombre_cliente'],
      'fecha_hora': json['fecha_hora'],
      'valor_servicio': json['valor_servicio']?.toString(),
      'placa': json['placa'],
      'referencia': json['referencia'],
      'nombre_asignado': json['nombre_asignado'],
      'celular': json['celular'],
      'unidad_negocio': json['unidad_negocio'],
      'movimiento': json['movimiento'],
      'servicio': json['servicio'],
      'modalidad': json['modalidad'],
      'tipo_activo': json['tipo_activo'],
      'marca': json['marca'],
      'ciudad_origen': json['ciudad_origen'],
      'direccion_origen': json['direccion_origen'],
      'observaciones_origen': json['observaciones_origen'],
      'ciudad_destino': json['ciudad_destino'],
      'direccion_destino': json['direccion_destino'],
      'observaciones_destino': json['observaciones_destino'],
      'es_programada': json['es_programada'] == 1 || json['es_programada'] == true ? 1 : 0,
      'fecha_programada': json['fecha_programada'],
      'status': json['status'],
    };
  }

  Future<SyncStatus> getSyncStatus() async {
    final status = await _dbService.getSyncStatus();
    switch (status) {
      case 'idle':
        return SyncStatus.idle;
      case 'syncing':
        return SyncStatus.syncing;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.idle;
    }
  }

  Future<int> getPendingOperationsCount() async {
    return await _dbService.getPendingOperationsCount();
  }
}

