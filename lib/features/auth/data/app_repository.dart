import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:first_app/core/network/api_config.dart';
import 'package:first_app/features/auth/models/user_model.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AppRepository {
  final http.Client _client;

  AppRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Realiza la petición de inicio de sesión.
  /// Lanza una [AuthException] si las credenciales son incorrectas o si ocurre un error de red.
  Future<UserModel> login(String usuario, String pass) async {
    try {
      final response = await _client.post(
        ApiConfig.loginOperadoresUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario': usuario,
          'pass': pass,
        }),
      );

      if (response.body.trim().isEmpty) {
        throw AuthException('El servidor no devolvió respuesta (HTTP ${response.statusCode})');
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw AuthException('Respuesta inválida del servidor (HTTP ${response.statusCode})');
      }

      if (decoded is! Map<String, dynamic>) {
        throw AuthException('Formato de respuesta inesperado del servidor');
      }

      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        final String token = body['token'] as String;
        final Map<String, dynamic> userData = body['data'] as Map<String, dynamic>;
        
        return UserModel.fromJson(userData, token: token);
      } else {
        final String errorMsg = body['message'] as String? ?? 'Error al iniciar sesión (HTTP ${response.statusCode})';
        throw AuthException(errorMsg);
      }
    } on http.ClientException {
      throw AuthException('Error de conexión a internet. Revisa tu conexión.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Ocurrió un error inesperado: $e');
    }
  }

  /// Obtiene los datos del perfil del usuario usando su token.
  /// Lanza una [AuthException] si el token es inválido o expira, o por problemas de red.
  Future<UserModel> obtenerPerfil(String token) async {
    try {
      final response = await _client.get(
        ApiConfig.meUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.body.trim().isEmpty) {
        throw AuthException('El servidor no devolvió respuesta (HTTP ${response.statusCode})');
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw AuthException('Respuesta inválida del servidor (HTTP ${response.statusCode})');
      }

      if (decoded is! Map<String, dynamic>) {
        throw AuthException('Formato de datos no reconocido.');
      }

      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        final Map<String, dynamic> userData = body['data'] as Map<String, dynamic>;
        return UserModel.fromJson(userData, token: token);
      } else {
        final String errorMsg = body['message'] as String? ?? 'Error al obtener perfil (HTTP ${response.statusCode})';
        throw AuthException(errorMsg);
      }
    } on http.ClientException {
      throw AuthException('Error de conexión a internet.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Ocurrió un error al obtener el perfil: $e');
    }
  }
}
