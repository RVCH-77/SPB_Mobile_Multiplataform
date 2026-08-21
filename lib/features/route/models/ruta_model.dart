// Estructura inmutable para representar una ruta y sus detalles

class ClienteModel {
  final int id;
  final String nombre;

  const ClienteModel({
    required this.id,
    required this.nombre,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? 'Sin cliente',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}

class ChoferPrincipalModel {
  final int id;
  final String nombre;
  final int? paquetesAsignados;

  const ChoferPrincipalModel({
    required this.id,
    required this.nombre,
    this.paquetesAsignados,
  });

  factory ChoferPrincipalModel.fromJson(Map<String, dynamic> json) {
    return ChoferPrincipalModel(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? 'Sin chofer',
      paquetesAsignados: json['paquetes_asignados'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      if (paquetesAsignados != null) 'paquetes_asignados': paquetesAsignados,
    };
  }
}

class ApoyoModel {
  final String nombre;
  final int paquetesAsignados;

  const ApoyoModel({
    required this.nombre,
    required this.paquetesAsignados,
  });

  factory ApoyoModel.fromJson(Map<String, dynamic> json) {
    return ApoyoModel(
      nombre: json['nombre'] as String? ?? '',
      paquetesAsignados: json['paquetes_asignados'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'paquetes_asignados': paquetesAsignados,
    };
  }
}

class RutaModel {
  final int id;
  final String ruta;
  final String fecha;
  final String destino;
  final String tipoRuta;
  final String estatusGlobal;
  final String miEstatus;
  final int misPaquetes;
  final int totalPaquetes;
  final int? vehiculoId;
  final ClienteModel? cliente;
  final ChoferPrincipalModel? choferPrincipal;
  final List<ApoyoModel> apoyos;
  final String rol;
  final int? idDetalle;
  final String notas;

  const RutaModel({
    required this.id,
    required this.ruta,
    required this.fecha,
    required this.destino,
    required this.tipoRuta,
    required this.estatusGlobal,
    required this.miEstatus,
    required this.misPaquetes,
    required this.totalPaquetes,
    this.vehiculoId,
    this.cliente,
    this.choferPrincipal,
    required this.apoyos,
    required this.rol,
    this.idDetalle,
    required this.notas,
  });

  factory RutaModel.fromJson(Map<String, dynamic> json) {
    return RutaModel(
      id: json['id'] as int? ?? json['id_ruta'] as int? ?? 0,
      ruta: json['ruta'] as String? ?? json['codigo_ruta'] as String? ?? 'Sin ruta',
      fecha: json['fecha'] as String? ?? '',
      destino: json['destino'] as String? ?? 'Sin destino',
      tipoRuta: json['tipo_ruta'] as String? ?? 'Sin tipo',
      estatusGlobal: json['estatus_global'] as String? ?? json['estatus_general'] as String? ?? 'Activa',
      miEstatus: json['mi_estatus'] as String? ?? json['estado_chofer'] as String? ?? 'pendiente',
      misPaquetes: json['mis_paquetes'] as int? ?? json['paquetes_asignados'] as int? ?? json['paquetes_totales'] as int? ?? 0,
      totalPaquetes: json['total_paquetes'] as int? ?? json['paquetes_totales'] as int? ?? 0,
      vehiculoId: json['vehiculo_id'] as int?,
      cliente: json['cliente'] != null
          ? ClienteModel.fromJson(json['cliente'] as Map<String, dynamic>)
          : null,
      choferPrincipal: json['chofer_principal'] != null
          ? ChoferPrincipalModel.fromJson(
              json['chofer_principal'] as Map<String, dynamic>)
          : null,
      apoyos: (json['apoyos'] as List<dynamic>?)
              ?.map((item) => ApoyoModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      rol: json['rol'] as String? ?? json['rol_chofer'] as String? ?? 'principal',
      idDetalle: json['id_detalle'] as int?,
      notas: json['notas'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ruta': ruta,
      'fecha': fecha,
      'destino': destino,
      'tipo_ruta': tipoRuta,
      'estatus_global': estatusGlobal,
      'mi_estatus': miEstatus,
      'mis_paquetes': misPaquetes,
      'total_paquetes': totalPaquetes,
      if (vehiculoId != null) 'vehiculo_id': vehiculoId,
      if (cliente != null) 'cliente': cliente!.toJson(),
      if (choferPrincipal != null) 'chofer_principal': choferPrincipal!.toJson(),
      'apoyos': apoyos.map((e) => e.toJson()).toList(),
      'rol': rol,
      if (idDetalle != null) 'id_detalle': idDetalle,
      'notas': notas,
    };
  }
}
