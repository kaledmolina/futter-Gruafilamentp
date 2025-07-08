import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/orden_model.dart';
import '../services/api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Orden> _orderFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }
  
  void _loadOrderDetails() {
    setState(() {
      _orderFuture = _apiService.getOrderDetails(widget.orderId);
    });
  }

  // Diálogo de confirmación genérico
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
    setState(() => _isLoading = true);
    try {
      await _apiService.acceptOrder(widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden tomada exitosamente.'), backgroundColor: Colors.green),
        );
        _loadOrderDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _rejectOrder() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.rejectOrder(widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden rechazada.'), backgroundColor: Colors.orange),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeOrder() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.closeOrder(widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden cerrada exitosamente.'), backgroundColor: Colors.blue),
        );
        Navigator.of(context).pop('refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalles de Orden #${widget.orderId}')),
      body: FutureBuilder<Orden>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar detalles: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No se encontraron datos.'));
          }

          final orden = snapshot.data!;
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Espacio para botones
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDetailSection(orden) // Widget que contiene todos los detalles
                  ],
                ),
              ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(16.0),
                  child: _buildActionButtons(orden),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget que construye la sección de botones de acción
  Widget _buildActionButtons(Orden orden) {
    if (orden.status == 'abierta') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showConfirmationDialog(
                title: 'Rechazar Orden',
                content: 'Si rechaza la orden, ya no podrá tomarla y se notificará al operador. ¿Está seguro?',
                confirmText: 'Sí, Rechazar',
                onConfirm: _rejectOrder,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Rechazar'),
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
      return ElevatedButton(
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
        child: const Text('Cerrar Orden', style: TextStyle(color: Colors.white)),
      );
    }
    return const SizedBox.shrink(); // No muestra botones para otros estados
  }

  // Widget que construye toda la sección de detalles
  Widget _buildDetailSection(Orden orden) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final dateFormatter = DateFormat('dd/MM/yyyy hh:mm a');
    
    return Column(
      children: [
        _buildDetailCard('Información Principal', [
          _buildDetailRow('Estado', orden.status.toUpperCase(), highlight: true),
          _buildDetailRow('Número de Orden', orden.numeroOrden),
          _buildDetailRow('Número de Expediente', orden.numeroExpediente),
          _buildDetailRow('Nombre Cliente', orden.nombreCliente),
          _buildDetailRow('Fecha y Hora', dateFormatter.format(orden.fechaHora)),
          _buildDetailRow('Valor del Servicio', orden.valorServicio != null ? currencyFormatter.format(orden.valorServicio) : 'No especificado'),
          _buildDetailRow('¿Es Programada?', orden.esProgramada ? 'Sí' : 'No'),
        ]),
        _buildDetailCard('Información de Contacto', [
          _buildDetailRow('Nombre Asignado', orden.nombreAsignado),
          _buildDetailRow('Celular', orden.celular),
        ]),
        _buildDetailCard('Detalles del Vehículo/Activo', [
          _buildDetailRow('Placa', orden.placa),
          _buildDetailRow('Referencia', orden.referencia),
          _buildDetailRow('Tipo de Activo', orden.tipoActivo),
          _buildDetailRow('Marca', orden.marca),
        ]),
        _buildDetailCard('Detalles del Servicio', [
          _buildDetailRow('Unidad de Negocio', orden.unidadNegocio),
          _buildDetailRow('Movimiento', orden.movimiento),
          _buildDetailRow('Servicio', orden.servicio),
          _buildDetailRow('Modalidad', orden.modalidad),
        ]),
        _buildDetailCard('Origen', [
          _buildDetailRow('Ciudad', orden.ciudadOrigen),
          _buildDetailRow('Dirección', orden.direccionOrigen),
          _buildDetailRow('Observaciones', orden.observacionesOrigen),
        ]),
        _buildDetailCard('Destino', [
          _buildDetailRow('Ciudad', orden.ciudadDestino),
          _buildDetailRow('Dirección', orden.direccionDestino),
          _buildDetailRow('Observaciones', orden.observacionesDestino),
        ]),
      ],
    );
  }

  // Widget para construir cada tarjeta de detalles
  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  // Widget para construir cada fila de detalle (Label: Value)
  Widget _buildDetailRow(String label, String? value, {bool highlight = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(
            child: Text(
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