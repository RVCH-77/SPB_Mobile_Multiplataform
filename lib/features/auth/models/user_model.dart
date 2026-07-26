// Estructura inmutable para representar un usuario

class UserModel {
  final int idUsuario;
  final String usuario;
  final String email;
  final String rol;
  final String? token;

  //Constructor
  const UserModel({
    required this.idUsuario,
    required this.usuario,
    required this.email,
    required this.rol,
    this.token,
  });

  // Constructor factory para crear una instancia desde el JSON de la API
  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      idUsuario: json['id_usuario'] as int? ?? json['idUsuario'] as int,
      usuario: json['usuario'] as String,
      email: json['email'] as String? ?? json['correo'] as String? ?? '',
      rol: json['rol'] as String,
      token: token ?? json['token'] as String?,
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
    };
  }

  // copyWith para "modificar" campos de forma inmutable
  UserModel copyWith({
    int? idUsuario,
    String? usuario,
    String? email,
    String? rol,
    String? token,
  }) {
    return UserModel(
      idUsuario: idUsuario ?? this.idUsuario,
      usuario: usuario ?? this.usuario,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      token: token ?? this.token,
    );
  }
}
