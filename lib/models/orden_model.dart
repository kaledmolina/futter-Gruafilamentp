class Orden {
  final int id;
  final String numeroOrden;
  final String? numeroExpediente;
  final String nombreCliente;
  final DateTime fechaHora;
  final double? valorServicio;
  final String? placa;
  final String? referencia;
  final String? nombreAsignado;
  final String? celular;
  final String? unidadNegocio;
  final String? movimiento;
  final String? servicio;
  final String? modalidad;
  final String? tipoActivo;
  final String? marca;
  final String ciudadOrigen;
  final String direccionOrigen;
  final String? observacionesOrigen;
  final String ciudadDestino;
  final String direccionDestino;
  final String? observacionesDestino;
  final bool esProgramada;
  final DateTime? fechaProgramada;
  final String status;

  Orden({
    required this.id,
    required this.numeroOrden,
    this.numeroExpediente,
    required this.nombreCliente,
    required this.fechaHora,
    this.valorServicio,
    this.placa,
    this.referencia,
    this.nombreAsignado,
    this.celular,
    this.unidadNegocio,
    this.movimiento,
    this.servicio,
    this.modalidad,
    this.tipoActivo,
    this.marca,
    required this.ciudadOrigen,
    required this.direccionOrigen,
    this.observacionesOrigen,
    required this.ciudadDestino,
    required this.direccionDestino,
    this.observacionesDestino,
    required this.esProgramada,
    this.fechaProgramada,
    required this.status,
  });

  factory Orden.fromJson(Map<String, dynamic> json) {
    return Orden(
      id: json['id'],
      numeroOrden: json['numero_orden'],
      numeroExpediente: json['numero_expediente'],
      nombreCliente: json['nombre_cliente'] ?? 'Cliente Desconocido',
      fechaHora: DateTime.tryParse(json['fecha_hora'] ?? '')?.toLocal() ?? DateTime.now(),
      valorServicio: double.tryParse(json['valor_servicio']?.toString() ?? '0'),
      placa: json['placa'],
      referencia: json['referencia'],
      nombreAsignado: json['nombre_asignado'],
      celular: json['celular'],
      unidadNegocio: json['unidad_negocio'],
      movimiento: json['movimiento'],
      servicio: json['servicio'],
      modalidad: json['modalidad'],
      tipoActivo: json['tipo_activo'],
      marca: json['marca'],
      ciudadOrigen: json['ciudad_origen'] ?? 'Origen no especificado',
      direccionOrigen: json['direccion_origen'] ?? 'Dirección no especificada',
      observacionesOrigen: json['observaciones_origen'],
      ciudadDestino: json['ciudad_destino'] ?? 'Destino no especificado',
      direccionDestino: json['direccion_destino'] ?? 'Dirección no especificada',
      observacionesDestino: json['observaciones_destino'],
      esProgramada: json['es_programada'] == 1 || json['es_programada'] == true,
      fechaProgramada: DateTime.tryParse(json['fecha_programada'] ?? '')?.toLocal(),
      status: json['status'] ?? 'desconocido',
    );
  }
}
