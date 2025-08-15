import 'package:intl/intl.dart';

class Vehicle {
  final int id;
  final String placa;
  final String? modelo;
  final String? marca;
  final String? tarjetaPropiedad;
  final DateTime? fechaTecnomecanica;
  final DateTime? fechaSoat;
  final String? mantenimientoPreventivoTaller;
  final DateTime? fechaMantenimiento;
  final DateTime? fechaUltimoAceite;

  Vehicle({
    required this.id,
    required this.placa,
    this.modelo,
    this.marca,
    this.tarjetaPropiedad,
    this.fechaTecnomecanica,
    this.fechaSoat,
    this.mantenimientoPreventivoTaller,
    this.fechaMantenimiento,
    this.fechaUltimoAceite,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      placa: json['placa'] ?? 'N/A',
      modelo: json['modelo'],
      marca: json['marca'],
      tarjetaPropiedad: json['tarjeta_propiedad'],
      fechaTecnomecanica: json['fecha_tecnomecanica'] != null ? DateTime.parse(json['fecha_tecnomecanica']) : null,
      fechaSoat: json['fecha_soat'] != null ? DateTime.parse(json['fecha_soat']) : null,
      mantenimientoPreventivoTaller: json['mantenimiento_preventivo_taller'],
      fechaMantenimiento: json['fecha_mantenimiento'] != null ? DateTime.parse(json['fecha_mantenimiento']) : null,
      fechaUltimoAceite: json['fecha_ultimo_aceite'] != null ? DateTime.parse(json['fecha_ultimo_aceite']) : null,
    );
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String? licenciaConduccion;
  final Vehicle? vehicle;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.licenciaConduccion,
    this.vehicle,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      licenciaConduccion: json['licencia_conduccion'],
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
    );
  }
}