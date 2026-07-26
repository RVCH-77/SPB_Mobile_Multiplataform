import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first_app/features/auth/data/app_repository.dart';
import 'package:first_app/features/auth/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  final AppRepository _repository;

  AuthViewModel({required AppRepository repository}) : _repository = repository;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Intenta iniciar sesión con el usuario y contraseña proporcionados.
  /// Retorna `true` si el login es exitoso, `false` en caso de error.
  Future<bool> login(String usuario, String pass) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.login(usuario, pass);
      
      // Guardar token en almacenamiento local si existe
      if (_currentUser?.token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _currentUser!.token!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _currentUser = null;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado al iniciar sesión.';
      _isLoading = false;
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  /// Intenta restaurar la sesión usando un token guardado.
  /// Retorna `true` si el token es válido y se obtiene el perfil.
  Future<bool> tryAutoLogin(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.obtenerPerfil(token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Si falla, limpiamos el estado silenciosamente para que inicie sesión de nuevo
      _isLoading = false;
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión activa del usuario y limpia los datos.
  void logout() {
    _currentUser = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();

    // Eliminar token asíncronamente
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('auth_token');
    });
  }
}
