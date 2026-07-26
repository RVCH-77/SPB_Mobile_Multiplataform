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
}
