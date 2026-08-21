// Modelo para representar un paquete y su estado de entrega
class PaqueteModel {
  final int idPaquete;
  final int idChofer;
  final String codigoPaquete;
  final String? guiaFisicaSupervisor;
  final String? guiaFisicaOperador;
  final bool coincideGuia;
  final String estatus; // 'pendiente', 'exitoso', 'fallido'
  final String? fotoEvidenciaUrl;
  final String? motivoFallo;
  final double? latitud;
  final double? longitud;
  final double? precisionM;
  final String? fechaEscaneo;

  const PaqueteModel({
    required this.idPaquete,
    required this.idChofer,
    required this.codigoPaquete,
    this.guiaFisicaSupervisor,
    this.guiaFisicaOperador,
    required this.coincideGuia,
    required this.estatus,
    this.fotoEvidenciaUrl,
    this.motivoFallo,
    this.latitud,
    this.longitud,
    this.precisionM,
    this.fechaEscaneo,
  });

  factory PaqueteModel.fromJson(Map<String, dynamic> json) {
    // Resolver compatibilidad de nombres entre v1 y v2
    final double? parsedLat = (json['latitud'] ?? json['latitud_entrega']) != null
        ? double.tryParse(json['latitud'].toString()) ?? double.tryParse(json['latitud_entrega'].toString())
        : null;

    final double? parsedLng = (json['longitud'] ?? json['longitud_entrega']) != null
        ? double.tryParse(json['longitud'].toString()) ?? double.tryParse(json['longitud_entrega'].toString())
        : null;

    final double? parsedPrecision = (json['precision_m'] ?? json['accuracy_m'] ?? json['precision']) != null
        ? double.tryParse(json['precision_m'].toString()) ??
            double.tryParse(json['accuracy_m'].toString()) ??
            double.tryParse(json['precision'].toString())
        : null;

    // coincide_guia
    bool parsedCoincide = false;
    if (json['coincide_guia'] is bool) {
      parsedCoincide = json['coincide_guia'] as bool;
    } else if (json['match_guia'] is bool) {
      parsedCoincide = json['match_guia'] as bool;
    } else {
      // Fallback manual si ambos códigos de guía física están presentes y son iguales
      final supervisorGuia = json['guia_fisica_supervisor'] ?? json['codigo_barras_independiente'];
      final operadorGuia = json['guia_fisica_operador'] ?? json['codigo_escaneado_operador'];
      if (supervisorGuia != null && operadorGuia != null) {
        parsedCoincide = supervisorGuia.toString() == operadorGuia.toString();
      }
    }

    return PaqueteModel(
      idPaquete: json['id_paquete'] as int? ?? json['id'] as int? ?? 0,
      idChofer: json['id_chofer'] as int? ?? 0,
      codigoPaquete: json['codigo_paquete'] as String? ?? '',
      guiaFisicaSupervisor: json['guia_fisica_supervisor'] as String? ?? json['codigo_barras_independiente'] as String?,
      guiaFisicaOperador: json['guia_fisica_operador'] as String? ?? json['codigo_escaneado_operador'] as String?,
      coincideGuia: parsedCoincide,
      estatus: json['estatus'] as String? ?? 'pendiente',
      fotoEvidenciaUrl: json['foto_evidencia_url'] as String? ?? json['foto_evidencia'] as String?,
      motivoFallo: json['motivo_fallo'] as String?,
      latitud: parsedLat,
      longitud: parsedLng,
      precisionM: parsedPrecision,
      fechaEscaneo: json['fecha_escaneo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_paquete': idPaquete,
      'id_chofer': idChofer,
      'codigo_paquete': codigoPaquete,
      'guia_fisica_supervisor': guiaFisicaSupervisor,
      'guia_fisica_operador': guiaFisicaOperador,
      'coincide_guia': coincideGuia,
      'estatus': estatus,
      'foto_evidencia_url': fotoEvidenciaUrl,
      'motivo_fallo': motivoFallo,
      'latitud': latitud,
      'longitud': longitud,
      'precision_m': precisionM,
      'fecha_escaneo': fechaEscaneo,
    };
  }
}
