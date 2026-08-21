class ApiConfig {
  // Cambia esto a false para usar el entorno de producción
  static const bool useLocal = false;

  // Nota: En emuladores de Android, 'localhost' se mapea a '10.0.2.2'.
  // Para iOS, Web o Windows, se puede usar 'localhost' o la IP de tu máquina local.
  static const String _localBaseUrl = 'http://10.0.2.2/SPB/api'; 
  static const String _prodBaseUrl = 'https://spbservicios.com/spb-christopher/spb-clone/api';

  static String get baseUrl => useLocal ? _localBaseUrl : _prodBaseUrl;
  static String get operadoresBaseUrl => '$baseUrl/operadores';

  static Uri get loginUri => Uri.parse('$baseUrl/login.php');
  static Uri get meUri => Uri.parse('$baseUrl/me.php');
  static Uri get guardarUbicacionUri => Uri.parse('$baseUrl/guardar_ubicacion.php');
  static Uri get rutasChoferUri => Uri.parse('$baseUrl/rutas_chofer.php');
  static Uri get iniciarRutaUri => Uri.parse('$baseUrl/iniciar_ruta.php');
  static Uri get finalizarRutaUri => Uri.parse('$baseUrl/finalizar_ruta.php');

  // Endpoints V2 para operadores
  static Uri get loginOperadoresUri => Uri.parse('$operadoresBaseUrl/login.php');
  static Uri get rutasOperadoresUri => Uri.parse('$operadoresBaseUrl/rutas.php');
  static Uri get detallesRutaUri => Uri.parse('$operadoresBaseUrl/detalles_ruta.php');
  static Uri get actualizarEntregaUri => Uri.parse('$operadoresBaseUrl/actualizar_entrega.php');
  static Uri get estadoRutaUri => Uri.parse('$operadoresBaseUrl/estado_ruta.php');
}
