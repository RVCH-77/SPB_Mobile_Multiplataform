// Estructura inmutable para representar un usuario

class UserModel {
  final int idUsuario;
  final String usuario;
  final String email;
  final String rol;
  final String? token;
  final int? idChofer;
  final String? nombreChofer;

  //Constructor
  const UserModel({
    required this.idUsuario,
    required this.usuario,
    required this.email,
    required this.rol,
    this.token,
    this.idChofer,
    this.nombreChofer,
  });

  // Constructor factory para crear una instancia desde el JSON de la API
  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    final empleado = json['empleado'] as Map<String, dynamic>?;
    final int? idChoferParsed = json['id_chofer'] as int? ??
        json['operador_asignado'] as int? ??
        empleado?['id'] as int?;

    final String? nombreChoferParsed = json['nombre_chofer'] as String? ??
        empleado?['nombre_completo'] as String?;

    return UserModel(
      idUsuario: json['id_usuario'] as int? ?? json['idUsuario'] as int? ?? 0,
      usuario: json['usuario'] as String? ?? '',
      email: json['email'] as String? ?? json['correo'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      token: token ?? json['token'] as String?,
      idChofer: idChoferParsed,
      nombreChofer: nombreChoferParsed,
    );
  }

  // Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'usuario': usuario,
      'email': email,
      'rol': rol,
      if (token != null) 'token': token,
      if (idChofer != null) 'id_chofer': idChofer,
      if (nombreChofer != null) 'nombre_chofer': nombreChofer,
    };
  }

  // copyWith para "modificar" campos de forma inmutable
  UserModel copyWith({
    int? idUsuario,
    String? usuario,
    String? email,
    String? rol,
    String? token,
    int? idChofer,
    String? nombreChofer,
  }) {
    return UserModel(
      idUsuario: idUsuario ?? this.idUsuario,
      usuario: usuario ?? this.usuario,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      token: token ?? this.token,
      idChofer: idChofer ?? this.idChofer,
      nombreChofer: nombreChofer ?? this.nombreChofer,
    );
  }
}
