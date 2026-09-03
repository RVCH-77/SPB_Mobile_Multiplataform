import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:first_app/core/network/api_config.dart';
import 'package:first_app/features/route/models/ruta_model.dart';

class RouteException implements Exception {
  final String message;
  RouteException(this.message);

  @override
  String toString() => message;
}

class RouteRepository {
  final http.Client _client;

  RouteRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Obtiene la lista de rutas asignadas u globales filtradas por fecha o estatus.
  /// Lanza una [RouteException] si la petición falla.
  Future<List<RutaModel>> getRutas({
    int? idOperador,
    String? fecha,
    String? estatus,
    String? token,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (idOperador != null && idOperador > 0) {
        queryParams['id_chofer'] = idOperador.toString();
        queryParams['id_operador'] = idOperador.toString();
      }
      if (fecha != null && fecha.trim().isNotEmpty) {
        queryParams['fecha'] = fecha.trim();
      }
      if (estatus != null && estatus.trim().isNotEmpty) {
        queryParams['estatus'] = estatus.trim();
      }

      // Reconstruir URI con parámetros opcionales (v2.0)
      Uri uri = ApiConfig.rutasOperadoresUri;
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.get(uri, headers: headers);
      
      if (response.body.trim().isEmpty) {
        throw RouteException('El servidor no devolvió datos (HTTP ${response.statusCode})');
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw RouteException('Respuesta inválida del servidor (HTTP ${response.statusCode})');
      }

      if (decoded is! Map<String, dynamic>) {
        throw RouteException('Formato de datos no reconocido.');
      }

      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> data = (body['rutas'] ?? body['data']) as List<dynamic>? ?? [];
        return data.map((item) => RutaModel.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        final String errorMsg = body['message'] as String? ?? 'Error al obtener la lista de rutas (HTTP ${response.statusCode}).';
        throw RouteException(errorMsg);
      }
    } on http.ClientException {
      throw RouteException('Error de conexión a internet. Revisa tu red.');
    } catch (e) {
      if (e is RouteException) rethrow;
      throw RouteException('Ocurrió un error inesperado al cargar rutas: $e');
    }
  }
}
