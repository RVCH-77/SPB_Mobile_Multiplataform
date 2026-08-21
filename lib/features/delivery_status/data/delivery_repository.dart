import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:first_app/core/network/api_config.dart';
import 'package:first_app/features/delivery_status/models/paquete_model.dart';

class DeliveryException implements Exception {
  final String message;
  DeliveryException(this.message);

  @override
  String toString() => message;
}

class DeliveryRepository {
  final http.Client _client;

  DeliveryRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Obtiene la lista de paquetes y detalles de la ruta
  Future<Map<String, dynamic>> obtenerDetallesRuta(int idRuta, int idChofer, {String? token}) async {
    try {
      final uri = ApiConfig.detallesRutaUri.replace(
        queryParameters: {
          'id_ruta': idRuta.toString(),
          'id_chofer': idChofer.toString(),
        },
      );

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.get(uri, headers: headers);
      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> paquetesJson = body['paquetes'] as List<dynamic>? ?? [];
        final List<PaqueteModel> paquetes = paquetesJson
            .map((item) => PaqueteModel.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'ruta': body['ruta'] as Map<String, dynamic>? ?? {},
          'resumen': body['resumen'] as Map<String, dynamic>? ?? {},
          'paquetes': paquetes,
        };
      } else {
        final String errorMsg = body['message'] as String? ?? 'Error al obtener detalles de la ruta.';
        throw DeliveryException(errorMsg);
      }
    } on http.ClientException {
      throw DeliveryException('Error de conexión a internet. Revisa tu red.');
    } catch (e) {
      if (e is DeliveryException) rethrow;
      throw DeliveryException('Ocurrió un error al cargar detalles: $e');
    }
  }

  /// Registra una entrega exitosa o fallida
  Future<PaqueteModel> actualizarEntrega({
    required int idPaquete,
    required int idRuta,
    required int idChofer,
    required String estatus, // 'exitoso' o 'fallido'
    required String? codigoEscaneado,
    String? motivoFallo,
    String? fotoEvidenciaBase64, // 'data:image/jpeg;base64,...'
    double? latitud,
    double? longitud,
    double? precision,
    bool? visitaDomiciliaria,
    String? token,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'id_paquete': idPaquete,
        'id_ruta': idRuta,
        'id_chofer': idChofer,
        'estatus': estatus,
        'codigo_escaneado': codigoEscaneado,
        if (motivoFallo != null) 'motivo_fallo': motivoFallo,
        if (fotoEvidenciaBase64 != null) 'foto_evidencia': fotoEvidenciaBase64,
        if (latitud != null) 'latitud': latitud,
        if (longitud != null) 'longitud': longitud,
        if (precision != null) 'precision': precision,
        if (visitaDomiciliaria != null) ...{
          'visita_domiciliaria': visitaDomiciliaria ? 1 : 0,
          'visita': visitaDomiciliaria ? 1 : 0,
          'domicilio_visitado': visitaDomiciliaria ? 1 : 0,
          'domicilios_visitados': visitaDomiciliaria ? 1 : 0,
        },
      };

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        ApiConfig.actualizarEntregaUri,
        headers: headers,
        body: jsonEncode(payload),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final Map<String, dynamic> paqueteData = body['paquete'] as Map<String, dynamic>? ?? {};
        return PaqueteModel.fromJson(paqueteData);
      } else {
        final String errorMsg = body['message'] as String? ?? 'Error al actualizar el estado del paquete.';
        throw DeliveryException(errorMsg);
      }
    } on http.ClientException {
      throw DeliveryException('Error de conexión a internet.');
    } catch (e) {
      if (e is DeliveryException) rethrow;
      throw DeliveryException('Error al reportar la entrega: $e');
    }
  }

  /// Cambia el estado de la ruta (iniciar_ruta o finalizar_ruta)
  Future<bool> actualizarEstadoRuta({
    required int idRuta,
    required int idChofer,
    required String accion, // 'iniciar_ruta' o 'finalizar_ruta'
    double? kilometraje, // km_inicial o km_final
    int? domiciliosVisitados, // Requerido para finalizar si hay fallidos
    String? fotoPath1, // Ruta del archivo de foto (km_inicial o km_final)
    String? fotoPath2, // Ruta del archivo de foto (foto_cierre)
    String? token,
  }) async {
    try {
      final Uri uri = accion == 'iniciar_ruta'
          ? ApiConfig.iniciarRutaUri
          : ApiConfig.finalizarRutaUri;

      final request = http.MultipartRequest('POST', uri);

      // Cabeceras
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Parámetros de texto comunes y específicos
      request.fields['id_ruta'] = idRuta.toString();
      request.fields['id_chofer'] = idChofer.toString();
      request.fields['id_operador'] = idChofer.toString();
      request.fields['accion'] = accion;
      request.fields['estatus'] = accion == 'iniciar_ruta' ? 'iniciar' : 'finalizar';

      if (kilometraje != null) {
        request.fields['kilometraje'] = kilometraje.toString();
        if (accion == 'iniciar_ruta') {
          request.fields['km_inicial'] = kilometraje.toString();
        } else {
          request.fields['km_final'] = kilometraje.toString();
        }
      }

      if (domiciliosVisitados != null) {
        request.fields['domicilios_visitados'] = domiciliosVisitados.toString();
      }

      // Adjuntar archivos si existen
      if (fotoPath1 != null && fotoPath1.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('foto_odometro', fotoPath1));
        if (accion == 'iniciar_ruta') {
          request.files.add(await http.MultipartFile.fromPath('foto_km_inicial', fotoPath1));
        } else {
          request.files.add(await http.MultipartFile.fromPath('foto_km_final', fotoPath1));
        }
      }

      if (fotoPath2 != null && fotoPath2.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('foto_evidencia_cierre', fotoPath2));
        request.files.add(await http.MultipartFile.fromPath('foto_cierre', fotoPath2));
      }

      // Enviar la petición multipart
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        return true;
      } else {
        final String errorMsg = body['message'] as String? ?? 'Error al actualizar el estado de la ruta.';
        throw DeliveryException(errorMsg);
      }
    } on http.ClientException {
      throw DeliveryException('Error de conexión a internet.');
    } catch (e) {
      if (e is DeliveryException) rethrow;
      throw DeliveryException('Error al cambiar estado de la ruta: $e');
    }
  }
}
