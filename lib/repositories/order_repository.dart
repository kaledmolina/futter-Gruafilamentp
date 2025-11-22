import 'dart:convert';
import '../models/orden_model.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OrderRepository {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<Orden>> getOrders({int page = 1, String status = 'todas'}) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        final response = await _apiService.getOrders(page: page, status: status);
        final ordersData = response['data'] as List;
        
        final orders = ordersData.map((json) => Orden.fromJson(json)).toList();
        await _saveOrdersToLocal(ordersData);
        
        return orders;
      } catch (e) {
        return await _getOrdersFromLocal(status: status);
      }
    }
    
    return await _getOrdersFromLocal(status: status);
  }

  Future<Orden> getOrderDetails(String orderNumber) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        final order = await _apiService.getOrderDetails(orderNumber);
        await _saveOrderToLocal(order);
        return order;
      } catch (e) {
        final localOrder = await _getOrderFromLocal(orderNumber);
        if (localOrder != null) return localOrder;
        rethrow;
      }
    }
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) return localOrder;
    throw Exception('Orden no encontrada localmente y sin conexión');
  }

  Future<Orden> acceptOrder(String orderNumber) async {
    // Validar si ya hay una orden en proceso (excluyendo la actual)
    final ordersInProcess = await _dbService.getOrdersInProcess();
    
    // Obtener todas las operaciones pendientes
    final allPendingOps = await _dbService.getPendingOperations();
    
    // Obtener las órdenes que tienen operaciones pendientes de "close" (ya están siendo cerradas)
    final ordersBeingClosed = allPendingOps
        .where((op) => op['operation_type'] == 'close')
        .map((op) => op['order_number'] as String)
        .toSet();
    
    // Filtrar órdenes en proceso excluyendo:
    // 1. La orden actual
    // 2. Las órdenes que tienen una operación pendiente de "close" (ya están siendo cerradas)
    final otherOrdersInProcess = ordersInProcess
        .where((order) {
          final orderNum = order['numero_orden'] as String;
          return orderNum != orderNumber && !ordersBeingClosed.contains(orderNum);
        })
        .toList();
    
    if (otherOrdersInProcess.isNotEmpty) {
      throw Exception('Ya tienes una orden de servicio en proceso. Debes finalizarla antes de iniciar otra.');
    }
    
    // Validar si hay operaciones pendientes de aceptar para otras órdenes
    // (excluyendo las que están siendo cerradas)
    final otherAcceptOps = allPendingOps
        .where((op) => 
            op['operation_type'] == 'accept' && 
            op['order_number'] != orderNumber &&
            !ordersBeingClosed.contains(op['order_number'] as String))
        .toList();
    
    if (otherAcceptOps.isNotEmpty) {
      throw Exception('Ya tienes una orden de servicio en proceso. Debes finalizarla antes de iniciar otra.');
    }
    
    final hasConnection = await _hasConnection();
    
    // Verificar si ya existe una operación pendiente de aceptar para esta orden
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasAcceptPending = existingOps.any((op) => op['operation_type'] == 'accept');
    
    if (hasAcceptPending) {
      // Si ya hay una operación pendiente, retornar orden con estado actualizado localmente
      final localOrder = await _getOrderFromLocal(orderNumber);
      if (localOrder != null) {
        return Orden(
          id: localOrder.id,
          numeroOrden: localOrder.numeroOrden,
          numeroExpediente: localOrder.numeroExpediente,
          nombreCliente: localOrder.nombreCliente,
          fechaHora: localOrder.fechaHora,
          valorServicio: localOrder.valorServicio,
          placa: localOrder.placa,
          referencia: localOrder.referencia,
          nombreAsignado: localOrder.nombreAsignado,
          celular: localOrder.celular,
          unidadNegocio: localOrder.unidadNegocio,
          movimiento: localOrder.movimiento,
          servicio: localOrder.servicio,
          modalidad: localOrder.modalidad,
          tipoActivo: localOrder.tipoActivo,
          marca: localOrder.marca,
          ciudadOrigen: localOrder.ciudadOrigen,
          direccionOrigen: localOrder.direccionOrigen,
          observacionesOrigen: localOrder.observacionesOrigen,
          ciudadDestino: localOrder.ciudadDestino,
          direccionDestino: localOrder.direccionDestino,
          observacionesDestino: localOrder.observacionesDestino,
          esProgramada: localOrder.esProgramada,
          fechaProgramada: localOrder.fechaProgramada,
          status: 'en proceso',
        );
      }
    }
    
    if (hasConnection) {
      try {
        final order = await _apiService.acceptOrder(orderNumber);
        await _saveOrderToLocal(order);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('accept', orderNumber),
        );
        return order;
      } catch (e) {
        // Actualizar estado local inmediatamente
        await _updateLocalOrderStatus(orderNumber, 'en proceso');
        await _queueOperation('accept', orderNumber, {});
        rethrow;
      }
    }
    
    // Actualizar estado local inmediatamente antes de encolar
    await _updateLocalOrderStatus(orderNumber, 'en proceso');
    await _queueOperation('accept', orderNumber, {});
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) {
      return localOrder;
    }
    throw Exception('Orden no encontrada');
  }

  Future<Orden> closeOrder(String orderNumber) async {
    final hasConnection = await _hasConnection();
    
    // Verificar si ya existe una operación pendiente de cerrar
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasClosePending = existingOps.any((op) => op['operation_type'] == 'close');
    
    if (hasClosePending) {
      // Si ya hay una operación pendiente, retornar orden con estado actualizado localmente
      final localOrder = await _getOrderFromLocal(orderNumber);
      if (localOrder != null) {
        return Orden(
          id: localOrder.id,
          numeroOrden: localOrder.numeroOrden,
          numeroExpediente: localOrder.numeroExpediente,
          nombreCliente: localOrder.nombreCliente,
          fechaHora: localOrder.fechaHora,
          valorServicio: localOrder.valorServicio,
          placa: localOrder.placa,
          referencia: localOrder.referencia,
          nombreAsignado: localOrder.nombreAsignado,
          celular: localOrder.celular,
          unidadNegocio: localOrder.unidadNegocio,
          movimiento: localOrder.movimiento,
          servicio: localOrder.servicio,
          modalidad: localOrder.modalidad,
          tipoActivo: localOrder.tipoActivo,
          marca: localOrder.marca,
          ciudadOrigen: localOrder.ciudadOrigen,
          direccionOrigen: localOrder.direccionOrigen,
          observacionesOrigen: localOrder.observacionesOrigen,
          ciudadDestino: localOrder.ciudadDestino,
          direccionDestino: localOrder.direccionDestino,
          observacionesDestino: localOrder.observacionesDestino,
          esProgramada: localOrder.esProgramada,
          fechaProgramada: localOrder.fechaProgramada,
          status: 'cerrada',
        );
      }
    }
    
    if (hasConnection) {
      try {
        final order = await _apiService.closeOrder(orderNumber);
        await _saveOrderToLocal(order);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('close', orderNumber),
        );
        return order;
      } catch (e) {
        // Actualizar estado local inmediatamente
        await _updateLocalOrderStatus(orderNumber, 'cerrada');
        await _queueOperation('close', orderNumber, {});
        rethrow;
      }
    }
    
    // Actualizar estado local inmediatamente antes de encolar
    await _updateLocalOrderStatus(orderNumber, 'cerrada');
    await _queueOperation('close', orderNumber, {});
    
    final localOrder = await _getOrderFromLocal(orderNumber);
    if (localOrder != null) {
      return localOrder;
    }
    throw Exception('Orden no encontrada');
  }

  Future<void> rejectOrder(String orderNumber) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        await _apiService.rejectOrder(orderNumber);
        await _dbService.deleteOrder(orderNumber);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('reject', orderNumber),
        );
      } catch (e) {
        await _queueOperation('reject', orderNumber, {});
        rethrow;
      }
    } else {
      await _queueOperation('reject', orderNumber, {});
    }
  }

  Future<void> updateOrderDetails(String orderNumber, Map<String, String> data) async {
    final hasConnection = await _hasConnection();
    
    if (hasConnection) {
      try {
        await _apiService.updateDetails(orderNumber, data);
        await _updateLocalOrder(orderNumber, data);
        await _dbService.deletePendingOperation(
          await _findPendingOperation('update_details', orderNumber),
        );
      } catch (e) {
        await _queueOperation('update_details', orderNumber, data);
        rethrow;
      }
    } else {
      await _queueOperation('update_details', orderNumber, data);
      await _updateLocalOrder(orderNumber, data);
    }
  }

  Future<bool> _hasConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<void> _saveOrdersToLocal(List<dynamic> ordersData) async {
    final orders = ordersData.map((json) => _orderJsonToDbMap(json)).toList();
    await _dbService.saveOrders(orders);
    await _dbService.setLastSyncOrders(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  Future<void> _saveOrderToLocal(Orden order) async {
    final orderMap = _ordenToDbMap(order);
    await _dbService.saveOrder(orderMap);
  }

  Future<List<Orden>> _getOrdersFromLocal({String? status}) async {
    final ordersData = await _dbService.getOrders(status: status);
    return ordersData.map((map) => _dbMapToOrden(map)).toList();
  }

  Future<Orden?> _getOrderFromLocal(String orderNumber) async {
    final orderData = await _dbService.getOrderByNumber(orderNumber);
    if (orderData == null) return null;
    return _dbMapToOrden(orderData);
  }

  Future<void> _updateLocalOrder(String orderNumber, Map<String, String> data) async {
    final updates = <String, dynamic>{};
    if (data.containsKey('celular')) updates['celular'] = data['celular'];
    if (data.containsKey('observaciones_origen')) {
      updates['observaciones_origen'] = data['observaciones_origen'];
    }
    if (data.containsKey('observaciones_destino')) {
      updates['observaciones_destino'] = data['observaciones_destino'];
    }
    await _dbService.updateOrder(orderNumber, updates);
  }

  Future<void> _updateLocalOrderStatus(String orderNumber, String newStatus) async {
    await _dbService.updateOrder(orderNumber, {'status': newStatus});
  }

  Future<void> _queueOperation(String type, String orderNumber, Map<String, dynamic> data) async {
    // Verificar si ya existe una operación del mismo tipo para esta orden
    final existingOps = await _dbService.getPendingOperationsForOrder(orderNumber);
    final hasDuplicate = existingOps.any((op) => op['operation_type'] == type);
    
    if (!hasDuplicate) {
      await _dbService.addPendingOperation(
        operationType: type,
        orderNumber: orderNumber,
        operationData: data,
      );
      // Notificar que se agregó una nueva operación pendiente
      SyncService.instance.notifyPendingOperationChange(orderNumber);
    }
  }

  Future<int> _findPendingOperation(String type, String orderNumber) async {
    final pending = await _dbService.getPendingOperationsForOrder(orderNumber);
    final operation = pending.firstWhere(
      (op) => op['operation_type'] == type,
      orElse: () => {'id': 0},
    );
    return operation['id'] as int;
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

  Map<String, dynamic> _ordenToDbMap(Orden order) {
    return {
      'id': order.id,
      'numero_orden': order.numeroOrden,
      'numero_expediente': order.numeroExpediente,
      'nombre_cliente': order.nombreCliente,
      'fecha_hora': order.fechaHora.toIso8601String(),
      'valor_servicio': order.valorServicio?.toString(),
      'placa': order.placa,
      'referencia': order.referencia,
      'nombre_asignado': order.nombreAsignado,
      'celular': order.celular,
      'unidad_negocio': order.unidadNegocio,
      'movimiento': order.movimiento,
      'servicio': order.servicio,
      'modalidad': order.modalidad,
      'tipo_activo': order.tipoActivo,
      'marca': order.marca,
      'ciudad_origen': order.ciudadOrigen,
      'direccion_origen': order.direccionOrigen,
      'observaciones_origen': order.observacionesOrigen,
      'ciudad_destino': order.ciudadDestino,
      'direccion_destino': order.direccionDestino,
      'observaciones_destino': order.observacionesDestino,
      'es_programada': order.esProgramada ? 1 : 0,
      'fecha_programada': order.fechaProgramada?.toIso8601String(),
      'status': order.status,
    };
  }

  Orden _dbMapToOrden(Map<String, dynamic> map) {
    return Orden(
      id: map['id'] as int,
      numeroOrden: map['numero_orden'] as String,
      numeroExpediente: map['numero_expediente'] as String?,
      nombreCliente: map['nombre_cliente'] as String,
      fechaHora: DateTime.parse(map['fecha_hora'] as String).toLocal(),
      valorServicio: map['valor_servicio'] != null
          ? double.tryParse(map['valor_servicio'] as String)
          : null,
      placa: map['placa'] as String?,
      referencia: map['referencia'] as String?,
      nombreAsignado: map['nombre_asignado'] as String?,
      celular: map['celular'] as String?,
      unidadNegocio: map['unidad_negocio'] as String?,
      movimiento: map['movimiento'] as String?,
      servicio: map['servicio'] as String?,
      modalidad: map['modalidad'] as String?,
      tipoActivo: map['tipo_activo'] as String?,
      marca: map['marca'] as String?,
      ciudadOrigen: map['ciudad_origen'] as String,
      direccionOrigen: map['direccion_origen'] as String,
      observacionesOrigen: map['observaciones_origen'] as String?,
      ciudadDestino: map['ciudad_destino'] as String,
      direccionDestino: map['direccion_destino'] as String,
      observacionesDestino: map['observaciones_destino'] as String?,
      esProgramada: (map['es_programada'] as int) == 1,
      fechaProgramada: map['fecha_programada'] != null
          ? DateTime.parse(map['fecha_programada'] as String).toLocal()
          : null,
      status: map['status'] as String,
    );
  }
}

