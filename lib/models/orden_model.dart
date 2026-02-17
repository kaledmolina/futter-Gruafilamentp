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
      numeroOrden: json['numero_orden']?.toString() ?? '',
      numeroExpediente: json['numero_expediente']?.toString(),
      nombreCliente: json['nombre_cliente']?.toString() ?? 'Cliente Desconocido',
      fechaHora: DateTime.tryParse(json['fecha_hora']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      valorServicio: double.tryParse(json['valor_servicio']?.toString() ?? '0'),
      placa: json['placa']?.toString(),
      referencia: json['referencia']?.toString(),
      nombreAsignado: json['nombre_asignado']?.toString(),
      celular: json['celular']?.toString(),
      unidadNegocio: json['unidad_negocio']?.toString(),
      movimiento: json['movimiento']?.toString(),
      servicio: json['servicio']?.toString(),
      modalidad: json['modalidad']?.toString(),
      tipoActivo: json['tipo_activo']?.toString(),
      marca: json['marca']?.toString(),
      ciudadOrigen: json['ciudad_origen']?.toString() ?? 'Origen no especificado',
      direccionOrigen: json['direccion_origen']?.toString() ?? 'Dirección no especificada',
      observacionesOrigen: json['observaciones_origen']?.toString(),
      ciudadDestino: json['ciudad_destino']?.toString() ?? 'Destino no especificado',
      direccionDestino: json['direccion_destino']?.toString() ?? 'Dirección no especificada',
      observacionesDestino: json['observaciones_destino']?.toString(),
      esProgramada: json['es_programada'] == 1 || json['es_programada'] == true || json['es_programada'] == '1',
      fechaProgramada: DateTime.tryParse(json['fecha_programada']?.toString() ?? '')?.toLocal(),
      status: json['status']?.toString() ?? 'desconocido',
    );
  }
}
