class ApiConfig {
  // Cambia esto a false para usar el entorno de producción
  static const bool useLocal = false;

  // Nota: En emuladores de Android, 'localhost' se mapea a '10.0.2.2'.
  // Para iOS, Web o Windows, se puede usar 'localhost' o la IP de tu máquina local.
  static const String _localBaseUrl = 'http://10.0.2.2/SPB/api'; 
  static const String _prodBaseUrl = 'https://spbservicios.com/spb/api';

  static String get baseUrl => useLocal ? _localBaseUrl : _prodBaseUrl;

  static Uri get loginUri => Uri.parse('$baseUrl/login.php');
  static Uri get meUri => Uri.parse('$baseUrl/me.php');
}
