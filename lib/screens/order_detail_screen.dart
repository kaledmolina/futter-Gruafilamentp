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
import '../widgets/glass_card.dart';

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
  List<dynamic> _photos = [];
  bool _isLoadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _loadOrderDetails();
    _loadPhotos(); // Cargar fotos al inicio
    SyncService.instance.sync();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoadingPhotos = true);
    try {
      final photos = await _orderRepo.getOrderPhotos(widget.orderNumber);
      if (mounted) {
        setState(() {
          _photos = photos;
        });
      }
    } catch (e) {
      debugPrint('Error cargando fotos: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPhotos = false);
    }
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
        RefreshIndicator(
          onRefresh: _loadOrderDetails,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
            child: _buildDetailSection(orden),
          ),
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
    if (orden.status == 'abierta' || orden.status == 'programada') {
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
        _buildPhotosSection(_photos),
      ],
    );
  }

  Widget _buildPhotosSection(List<dynamic> photos) {
    // REMOVED early return to ensure section is always visible
    // if (photos.isEmpty && !_isLoadingPhotos) {
    //   return const SizedBox.shrink(); 
    // }

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'Fotos de la Orden',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1),
            if (_isLoadingPhotos)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ))
            else if (photos.isEmpty)
               const Center(child: Text('No hay fotos disponibles.'))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photoMap = photos[index];
                  final url = photoMap['url'] as String?;
                  
                  if (url == null) return const SizedBox.shrink();

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              backgroundColor: Colors.black, 
                              foregroundColor: Colors.white,
                              title: const Text('Vista de Foto'),
                            ),
                            backgroundColor: Colors.black,
                            body: Center(
                              child: InteractiveViewer(
                                child: Image.network(
                                  url, 
                                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                           return Container(
                             color: Colors.grey[200],
                             child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                           );
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 16.0,
        sigmaX: 5.0,
        sigmaY: 5.0,
        child: child,
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