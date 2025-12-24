import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class DebugDatabaseScreen extends StatefulWidget {
  const DebugDatabaseScreen({super.key});

  @override
  State<DebugDatabaseScreen> createState() => _DebugDatabaseScreenState();
}

class _DebugDatabaseScreenState extends State<DebugDatabaseScreen> {
  List<Map<String, dynamic>> _pendingOperations = [];
  List<Map<String, dynamic>> _pendingInspections = [];
  List<Map<String, dynamic>> _pendingPhotos = [];
  Map<String, String> _syncMetadata = {};
  bool _loading = true;
  bool _showTechnicalDetails = false;

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    
    try {
      _pendingOperations = await db.getPendingOperations();
      _pendingInspections = await db.getPendingInspections();
      _pendingPhotos = await db.getPendingPhotos();
      
      _syncMetadata = {
        'last_sync_orders': await db.getSyncMetadata('last_sync_orders') ?? '0',
        'last_sync_profile': await db.getSyncMetadata('last_sync_profile') ?? '0',
        'pending_operations_count': await db.getSyncMetadata('pending_operations_count') ?? '0',
        'sync_status': await db.getSyncMetadata('sync_status') ?? 'idle',
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar información: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Nunca';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Hace unos segundos';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
      } else {
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  String _getOperationTypeName(String type) {
    switch (type) {
      case 'accept':
        return 'Aceptar Orden';
      case 'close':
        return 'Cerrar Orden';
      case 'reject':
        return 'Rechazar Orden';
      case 'update_details':
        return 'Actualizar Detalles';
      default:
        return type;
    }
  }

  String? _getErrorMessage(String? error) {
    if (error == null || error.isEmpty) return null;
    
    // Simplificar mensajes de error comunes
    if (error.contains('SocketException') || error.contains('Failed host lookup')) {
      return 'Sin conexión a internet';
    } else if (error.contains('TimeoutException')) {
      return 'Tiempo de espera agotado';
    } else if (error.contains('401') || error.contains('Unauthorized')) {
      return 'Sesión expirada. Por favor, cierra sesión y vuelve a iniciar';
    } else if (error.contains('500') || error.contains('Internal Server Error')) {
      return 'Error del servidor. Intenta más tarde';
    }
    
    // Si el error es muy largo, truncarlo
    if (error.length > 100) {
      return '${error.substring(0, 100)}...';
    }
    
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _pendingOperations.length + _pendingInspections.length + _pendingPhotos.length;
    final hasErrors = _pendingOperations.any((op) => op['last_error'] != null) ||
                     _pendingInspections.any((insp) => insp['last_error'] != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Sincronización'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDatabaseInfo,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: Icon(_showTechnicalDetails ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showTechnicalDetails = !_showTechnicalDetails),
            tooltip: _showTechnicalDetails ? 'Ocultar detalles técnicos' : 'Mostrar detalles técnicos',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDatabaseInfo,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(totalPending, hasErrors),
                    const SizedBox(height: 16),
                    if (totalPending > 0) ...[
                      if (_pendingOperations.isNotEmpty)
                        _buildPendingOperationsCard(),
                      const SizedBox(height: 16),
                      if (_pendingInspections.isNotEmpty)
                        _buildPendingInspectionsCard(),
                      const SizedBox(height: 16),
                      if (_pendingPhotos.isNotEmpty)
                        _buildPendingPhotosCard(),
                    ] else
                      _buildAllSyncedCard(),
                    if (_showTechnicalDetails) ...[
                      const SizedBox(height: 16),
                      _buildTechnicalDetailsCard(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(int totalPending, bool hasErrors) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtext;

    if (totalPending == 0) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Todo Sincronizado';
      statusSubtext = 'Todas tus tareas se han sincronizado correctamente';
    } else if (hasErrors) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Hay Errores de Sincronización';
      statusSubtext = 'Algunas tareas no se pudieron sincronizar. Revisa los detalles abajo.';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.cloud_upload;
      statusText = 'Tareas Pendientes';
      statusSubtext = 'Tienes $totalPending tarea${totalPending > 1 ? 's' : ''} esperando sincronización';
    }

    return Card(
      elevation: 4,
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusSubtext,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOperationsCard() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Operaciones Pendientes (${_pendingOperations.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          ..._pendingOperations.map((op) {
            final orderNumber = op['order_number'] as String;
            final operationType = _getOperationTypeName(op['operation_type'] as String);
            final retryCount = op['retry_count'] as int;
            final error = _getErrorMessage(op['last_error'] as String?);
            final createdAt = _formatTimestamp(op['created_at'] as int?);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          operationType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (error != null)
                        const Icon(Icons.error, color: Colors.red, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Orden: $orderNumber', style: const TextStyle(fontSize: 14)),
                  if (retryCount > 0)
                    Text(
                      'Intentos de sincronización: $retryCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'Creado: $createdAt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (_showTechnicalDetails) ...[
                    const Divider(),
                    _buildTechnicalOperationDetails(op),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPendingInspectionsCard() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Inspecciones Pendientes (${_pendingInspections.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          ..._pendingInspections.map((insp) {
            final retryCount = insp['retry_count'] as int;
            final error = _getErrorMessage(insp['last_error'] as String?);
            final createdAt = _formatTimestamp(insp['created_at'] as int?);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Inspección Preoperacional',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (error != null)
                        const Icon(Icons.error, color: Colors.red, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (retryCount > 0)
                    Text(
                      'Intentos de sincronización: $retryCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'Creado: $createdAt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPendingPhotosCard() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Fotos Pendientes (${_pendingPhotos.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _pendingPhotos.map((photo) {
                final orderNumber = photo['order_number'] as String;
                final createdAt = _formatTimestamp(photo['created_at'] as int?);
                final error = _getErrorMessage(photo['last_error'] as String?);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo, color: Colors.purple, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Foto de la Orden $orderNumber',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Creada: $createdAt',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (error != null)
                             const Icon(Icons.error, color: Colors.red, size: 20),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                         Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSyncedCard() {
    return Card(
      elevation: 2,
      color: Colors.green.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.cloud_done, size: 64, color: Colors.green[700]),
            const SizedBox(height: 16),
            const Text(
              '¡Todo está sincronizado!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Última sincronización: ${_formatTimestamp(int.tryParse(_syncMetadata['last_sync_orders'] ?? '0'))}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalDetailsCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: const Text(
          'Detalles Técnicos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.code),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTechnicalRow('Estado de Sincronización', _syncMetadata['sync_status'] ?? 'N/A'),
                _buildTechnicalRow('Última Sincronización (Órdenes)', _formatTimestamp(int.tryParse(_syncMetadata['last_sync_orders'] ?? '0'))),
                _buildTechnicalRow('Última Sincronización (Perfil)', _formatTimestamp(int.tryParse(_syncMetadata['last_sync_profile'] ?? '0'))),
                _buildTechnicalRow('Total Operaciones Pendientes', _syncMetadata['pending_operations_count'] ?? '0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalOperationDetails(Map<String, dynamic> op) {
    final data = jsonDecode(op['operation_data'] as String);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos técnicos:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            const JsonEncoder.withIndent('  ').convert(data),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
