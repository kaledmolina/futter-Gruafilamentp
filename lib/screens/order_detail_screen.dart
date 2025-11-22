import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/orden_model.dart';
import '../repositories/order_repository.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'manage_order_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/connection_status_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  const OrderDetailScreen({super.key, required this.orderNumber});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  Orden? _currentOrder;
  bool _isLoading = true;
  String? _error;
  bool _hasStateChanged = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    SyncService.instance.sync();
  }
  
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    // Cargar desde caché primero
    try {
      final cachedOrder = await _orderRepo.getOrderDetails(widget.orderNumber);
      if (mounted) {
        setState(() {
          _currentOrder = cachedOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Si no hay caché, intentar desde servidor
      try {
        final order = await _orderRepo.getOrderDetails(widget.orderNumber);
        if (mounted) {
          setState(() {
            _currentOrder = order;
            _isLoading = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _error = err.toString();
            _isLoading = false;
          });
        }
      }
    }
  }
   Future<void> _launchCaller(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la aplicación de llamadas para el número $phoneNumber')),
        );
      }
    }
  }

  Future<void> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: Text(confirmText),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _takeOrder() async {
    if (_isLoading) return; // Prevenir múltiples llamadas
    
    setState(() => _isLoading = true);
    
    try {
      // Validar si ya hay una orden en proceso antes de aceptar
      final ordersInProcess = await DatabaseService.instance.getOrdersInProcess();
      
      // Obtener todas las operaciones pendientes
      final allPendingOps = await DatabaseService.instance.getPendingOperations();
      
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
            return orderNum != widget.orderNumber && !ordersBeingClosed.contains(orderNum);
          })
          .toList();
      
      // Validar también operaciones pendientes de aceptar para otras órdenes
      // (excluyendo las que están siendo cerradas)
      final otherAcceptOps = allPendingOps
          .where((op) => 
              op['operation_type'] == 'accept' && 
              op['order_number'] != widget.orderNumber &&
              !ordersBeingClosed.contains(op['order_number'] as String))
          .toList();
      
      String? orderInProcessNumber;
      String? clientName;
      
      if (otherOrdersInProcess.isNotEmpty) {
        final orderInProcess = otherOrdersInProcess.first;
        orderInProcessNumber = orderInProcess['numero_orden'] as String;
        clientName = orderInProcess['nombre_cliente'] as String? ?? 'N/A';
      } else if (otherAcceptOps.isNotEmpty) {
        final pendingOp = otherAcceptOps.first;
        orderInProcessNumber = pendingOp['order_number'] as String;
        // Intentar obtener el nombre del cliente de la orden local
        final orderData = await DatabaseService.instance.getOrderByNumber(orderInProcessNumber);
        clientName = orderData?['nombre_cliente'] as String? ?? 'N/A';
      }
      
      if (orderInProcessNumber != null) {
        if (mounted) {
          setState(() => _isLoading = false);
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
              title: const Text(
                'Orden en Proceso',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'No puedes iniciar una nueva orden de servicio porque ya tienes una orden en proceso:\n\n'
                'Orden #$orderInProcessNumber\n'
                'Cliente: $clientName\n\n'
                'Debes finalizar esta orden antes de poder iniciar otra.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navegar a la orden en proceso
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderNumber: orderInProcessNumber!),
                      ),
                    );
                  },
                  child: const Text('Ver Orden en Proceso'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // Si no hay órdenes en proceso, proceder con aceptar la orden
      setState(() {
        // Actualizar UI inmediatamente
        if (_currentOrder != null) {
          _currentOrder = Orden(
            id: _currentOrder!.id,
            numeroOrden: _currentOrder!.numeroOrden,
            numeroExpediente: _currentOrder!.numeroExpediente,
            nombreCliente: _currentOrder!.nombreCliente,
            fechaHora: _currentOrder!.fechaHora,
            valorServicio: _currentOrder!.valorServicio,
            placa: _currentOrder!.placa,
            referencia: _currentOrder!.referencia,
            nombreAsignado: _currentOrder!.nombreAsignado,
            celular: _currentOrder!.celular,
            unidadNegocio: _currentOrder!.unidadNegocio,
            movimiento: _currentOrder!.movimiento,
            servicio: _currentOrder!.servicio,
            modalidad: _currentOrder!.modalidad,
            tipoActivo: _currentOrder!.tipoActivo,
            marca: _currentOrder!.marca,
            ciudadOrigen: _currentOrder!.ciudadOrigen,
            direccionOrigen: _currentOrder!.direccionOrigen,
            observacionesOrigen: _currentOrder!.observacionesOrigen,
            ciudadDestino: _currentOrder!.ciudadDestino,
            direccionDestino: _currentOrder!.direccionDestino,
            observacionesDestino: _currentOrder!.observacionesDestino,
            esProgramada: _currentOrder!.esProgramada,
            fechaProgramada: _currentOrder!.fechaProgramada,
            status: 'en proceso',
          );
          _hasStateChanged = true;
        }
      });
      
      final updatedOrder = await _orderRepo.acceptOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden tomada exitosamente.'), backgroundColor: Colors.green),
        );
        SyncService.instance.sync();
      }
    } catch (e) {
      if (mounted) {
        // Verificar si el error es por orden en proceso
        if (e.toString().contains('Ya tienes una orden de servicio en proceso')) {
          // Este caso ya fue manejado arriba, pero por si acaso
          final ordersInProcess = await DatabaseService.instance.getOrdersInProcess();
          final otherOrdersInProcess = ordersInProcess
              .where((order) => order['numero_orden'] != widget.orderNumber)
              .toList();
          
          if (otherOrdersInProcess.isNotEmpty) {
            final orderInProcess = otherOrdersInProcess.first;
            final orderNumber = orderInProcess['numero_orden'] as String;
            final clientName = orderInProcess['nombre_cliente'] as String? ?? 'N/A';
            
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
                title: const Text(
                  'Orden en Proceso',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'No puedes iniciar una nueva orden de servicio porque ya tienes una orden en proceso:\n\n'
                  'Orden #$orderNumber\n'
                  'Cliente: $clientName\n\n'
                  'Debes finalizar esta orden antes de poder iniciar otra.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Entendido'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(orderNumber: orderNumber),
                        ),
                      );
                    },
                    child: const Text('Ver Orden en Proceso'),
                  ),
                ],
              ),
            );
            return;
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orden guardada localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
        SyncService.instance.sync();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _rejectOrder() async {
    setState(() => _isLoading = true);
    try {
      await _orderRepo.rejectOrder(widget.orderNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden rechazada.'), backgroundColor: Colors.orange),
        );
        SyncService.instance.sync();
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orden guardada localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
        SyncService.instance.sync();
        Navigator.of(context).pop('refresh');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeOrder() async {
    if (_isLoading) return; // Prevenir múltiples llamadas
    
    setState(() {
      _isLoading = true;
      // Actualizar UI inmediatamente
      if (_currentOrder != null) {
        _currentOrder = Orden(
          id: _currentOrder!.id,
          numeroOrden: _currentOrder!.numeroOrden,
          numeroExpediente: _currentOrder!.numeroExpediente,
          nombreCliente: _currentOrder!.nombreCliente,
          fechaHora: _currentOrder!.fechaHora,
          valorServicio: _currentOrder!.valorServicio,
          placa: _currentOrder!.placa,
          referencia: _currentOrder!.referencia,
          nombreAsignado: _currentOrder!.nombreAsignado,
          celular: _currentOrder!.celular,
          unidadNegocio: _currentOrder!.unidadNegocio,
          movimiento: _currentOrder!.movimiento,
          servicio: _currentOrder!.servicio,
          modalidad: _currentOrder!.modalidad,
          tipoActivo: _currentOrder!.tipoActivo,
          marca: _currentOrder!.marca,
          ciudadOrigen: _currentOrder!.ciudadOrigen,
          direccionOrigen: _currentOrder!.direccionOrigen,
          observacionesOrigen: _currentOrder!.observacionesOrigen,
          ciudadDestino: _currentOrder!.ciudadDestino,
          direccionDestino: _currentOrder!.direccionDestino,
          observacionesDestino: _currentOrder!.observacionesDestino,
          esProgramada: _currentOrder!.esProgramada,
          fechaProgramada: _currentOrder!.fechaProgramada,
          status: 'cerrada',
        );
        _hasStateChanged = true;
      }
    });
    
    try {
      final updatedOrder = await _orderRepo.closeOrder(widget.orderNumber);
      if (mounted) {
        setState(() => _currentOrder = updatedOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden cerrada exitosamente.'), backgroundColor: Colors.blue),
        );
        SyncService.instance.sync();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop('refresh');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Orden guardada localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
        SyncService.instance.sync();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop('refresh');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasStateChanged ? 'refresh' : null);
        return false;
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Detalles de Orden #${widget.orderNumber}'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: ConnectionStatusIndicator(),
              ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading && _currentOrder == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error al cargar detalles: $_error'));
    }
    if (_currentOrder == null) {
      return const Center(child: Text('No se encontraron datos.'));
    }
    
    final orden = _currentOrder!;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          child: _buildDetailSection(orden),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: _buildActionButtons(orden),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Orden orden) {
    if (orden.status == 'abierta') {
      return Row(
        children: [
          Expanded(
            // CORRECCIÓN: Se cambia OutlinedButton por ElevatedButton
            child: ElevatedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Rechazar Orden',
                content: 'Si rechaza la orden, ya no podrá tomarla y se notificará al operador. ¿Está seguro?',
                confirmText: 'Sí, Rechazar',
                onConfirm: _rejectOrder,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Tomar Orden',
                content: '¿Está seguro de que desea tomar esta orden?',
                confirmText: 'Sí, Tomar',
                onConfirm: _takeOrder,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Tomar Orden', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }
    if (orden.status == 'en proceso') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_document, color: Colors.white),
            label: const Text('Gestionar Orden', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ManageOrderScreen(orden: orden),
                ),
              );
              if (result == 'refresh' && mounted) {
                _loadOrderDetails();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('Cerrar Orden', style: TextStyle(color: Colors.white)),
            onPressed: () => _showConfirmationDialog(
              title: 'Cerrar Orden',
              content: '¿Está seguro de que desea cerrar esta orden? Esta acción no se puede deshacer.',
              confirmText: 'Sí, Cerrar',
              onConfirm: _closeOrder,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailSection(Orden orden) {
    final dateFormatter = DateFormat('dd/MM/yyyy hh:mm a', 'es_CO');
    
    return Column(
      children: [
        _buildGlassCard(
          child: _buildDetailCard('Información Principal', [
            _buildDetailRow('Estado', orden.status.toUpperCase(), highlight: true),
            _buildDetailRow('Número de Orden', orden.numeroOrden),
            _buildDetailRow('Número de Expediente', orden.numeroExpediente),
            _buildDetailRow('Nombre Cliente', orden.nombreCliente),
            _buildDetailRow('Fecha y Hora', dateFormatter.format(orden.fechaHora)),
            _buildDetailRow('¿Es Programada?', orden.esProgramada ? 'Sí' : 'No'),
          ]),
        ),
        _buildGlassCard(
          child: _buildDetailCard('Información de Contacto', [
            _buildDetailRow('Nombre Asignado', orden.nombreAsignado),
            _buildDetailRow('Celular', orden.celular),
          ]),
        ),
        _buildGlassCard(
          child: _buildDetailCard('Detalles del Vehículo/Activo', [
            _buildDetailRow('Placa', orden.placa),
            _buildDetailRow('Referencia', orden.referencia),
            _buildDetailRow('Tipo de Activo', orden.tipoActivo),
            _buildDetailRow('Marca', orden.marca),
          ]),
        ),
        _buildGlassCard(
          child: _buildDetailCard('Detalles del Servicio', [
            _buildDetailRow('Unidad de Negocio', orden.unidadNegocio),
            _buildDetailRow('Movimiento', orden.movimiento),
            _buildDetailRow('Servicio', orden.servicio),
            _buildDetailRow('Modalidad', orden.modalidad),
          ]),
        ),
        _buildGlassCard(
          child: _buildDetailCard('Origen', [
            _buildDetailRow('Ciudad', orden.ciudadOrigen),
            _buildDetailRow('Dirección', orden.direccionOrigen),
            _buildDetailRow('Observaciones', orden.observacionesOrigen),
          ]),
        ),
        _buildGlassCard(
          child: _buildDetailCard('Destino', [
            _buildDetailRow('Ciudad', orden.ciudadDestino),
            _buildDetailRow('Dirección', orden.direccionDestino),
            _buildDetailRow('Observaciones', orden.observacionesDestino),
          ]),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20, thickness: 1),
          ...children,
        ],
      ),
    );
  }
    // MÉTODO ACTUALIZADO PARA HACER EL NÚMERO CLICKEABLE
  Widget _buildDetailRow(String label, String? value, {bool highlight = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    // Si la etiqueta es "Celular", hacemos el valor clickeable
    bool isPhone = label.toLowerCase() == 'celular';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(
            child: isPhone
              ? InkWell(
                  onTap: () => _launchCaller(value),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                    color: highlight ? Theme.of(context).primaryColor : Colors.black87,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}