import 'package:flutter_test/flutter_test.dart';
import 'package:first_app/features/auth/data/app_repository.dart';
import 'package:first_app/features/auth/models/user_model.dart';
import 'package:first_app/features/auth/presentation/auth_view_model.dart';

class MockAppRepository extends AppRepository {
  final Future<UserModel> Function(String usuario, String pass)? mockLogin;
  final Future<UserModel> Function(String token)? mockObtenerPerfil;

  MockAppRepository({this.mockLogin, this.mockObtenerPerfil});

  @override
  Future<UserModel> login(String usuario, String pass) {
    if (mockLogin != null) {
      return mockLogin!(usuario, pass);
    }
    return super.login(usuario, pass);
  }

  @override
  Future<UserModel> obtenerPerfil(String token) {
    if (mockObtenerPerfil != null) {
      return mockObtenerPerfil!(token);
    }
    return super.obtenerPerfil(token);
  }
}

void main() {
  group('AuthViewModel Tests', () {
    const testUser = UserModel(
      idUsuario: 29,
      usuario: 'marco.polo',
      email: 'marco@ejemplo.com',
      rol: 'operador',
      token: 'valid_token',
    );

    test('Estado inicial es correcto', () {
      final repository = MockAppRepository();
      final viewModel = AuthViewModel(repository: repository);

      expect(viewModel.currentUser, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isAuthenticated, isFalse);
    });

    test('Login exitoso actualiza estado correctamente', () async {
      final repository = MockAppRepository(
        mockLogin: (usuario, pass) async => testUser,
      );
      final viewModel = AuthViewModel(repository: repository);

      // Agregamos un listener para comprobar que notifica cambios
      bool notified = false;
      viewModel.addListener(() {
        notified = true;
      });

      final result = await viewModel.login('marco.polo', '123456');

      expect(result, isTrue);
      expect(viewModel.currentUser, testUser);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isAuthenticated, isTrue);
      expect(notified, isTrue);
    });

    test('Login fallido propaga el mensaje de error', () async {
      final repository = MockAppRepository(
        mockLogin: (usuario, pass) async => throw AuthException('Credenciales incorrectas'),
      );
      final viewModel = AuthViewModel(repository: repository);

      final result = await viewModel.login('wrong', 'pass');

      expect(result, isFalse);
      expect(viewModel.currentUser, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, 'Credenciales incorrectas');
      expect(viewModel.isAuthenticated, isFalse);
    });

    test('Logout limpia todos los estados del usuario', () async {
      final repository = MockAppRepository(
        mockLogin: (usuario, pass) async => testUser,
      );
      final viewModel = AuthViewModel(repository: repository);

      await viewModel.login('marco.polo', '123456');
      expect(viewModel.isAuthenticated, isTrue);

      viewModel.logout();

      expect(viewModel.currentUser, isNull);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isAuthenticated, isFalse);
    });

    test('AutoLogin exitoso restaura sesión', () async {
      final repository = MockAppRepository(
        mockObtenerPerfil: (token) async => testUser,
      );
      final viewModel = AuthViewModel(repository: repository);

      final result = await viewModel.tryAutoLogin('valid_token');

      expect(result, isTrue);
      expect(viewModel.currentUser, testUser);
      expect(viewModel.isAuthenticated, isTrue);
    });

    test('AutoLogin fallido limpia la sesión de forma silenciosa', () async {
      final repository = MockAppRepository(
        mockObtenerPerfil: (token) async => throw AuthException('Token inválido'),
      );
      final viewModel = AuthViewModel(repository: repository);

      final result = await viewModel.tryAutoLogin('invalid_token');

      expect(result, isFalse);
      expect(viewModel.currentUser, isNull);
      expect(viewModel.errorMessage, isNull); // Limpieza silenciosa
      expect(viewModel.isAuthenticated, isFalse);
    });
  });
}
