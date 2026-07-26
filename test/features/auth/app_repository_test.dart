import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:first_app/features/auth/data/app_repository.dart';
import 'package:first_app/features/auth/models/user_model.dart';

class MockClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) mockHandler;

  MockClient(this.mockHandler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await mockHandler(request);
    final bytes = response.bodyBytes;
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  group('AppRepository Tests', () {
    test('login exitoso retorna UserModel', () async {
      final mockResponse = {
        'success': true,
        'message': 'Inicio de sesión exitoso',
        'token': 'mock_token',
        'data': {
          'id_usuario': 29,
          'usuario': 'marco.polo',
          'email': 'marco@ejemplo.com',
          'rol': 'operador',
        }
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final repository = AppRepository(client: client);
      final user = await repository.login('marco.polo', '123456');

      expect(user.idUsuario, 29);
      expect(user.usuario, 'marco.polo');
      expect(user.email, 'marco@ejemplo.com');
      expect(user.rol, 'operador');
      expect(user.token, 'mock_token');
    });

    test('login fallido lanza AuthException', () async {
      final mockResponse = {
        'success': false,
        'message': 'Usuario o contraseña incorrectos',
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 401);
      });

      final repository = AppRepository(client: client);

      expect(
        () => repository.login('wrong', 'credentials'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
