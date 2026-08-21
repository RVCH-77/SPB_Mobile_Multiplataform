import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/core/theme/app_theme.dart';
import 'package:first_app/features/auth/data/app_repository.dart';
import 'package:first_app/features/auth/presentation/auth_view_model.dart';
import 'package:first_app/features/auth/presentation/login_page.dart';
import 'package:first_app/core/services/location_service.dart';
import 'package:first_app/features/route/presentation/route_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRepository _repository;
  late final AuthViewModel _authViewModel;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _repository = AppRepository();
    _authViewModel = AuthViewModel(repository: _repository);
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      await _authViewModel.tryAutoLogin(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    LocationService.navigatorKey = navigatorKey;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SPB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ListenableBuilder(
        listenable: _authViewModel,
        builder: (context, _) {
          if (_authViewModel.isAuthenticated) {
            return MyHomePage(
              title: 'Panel Administrativo SPB',
              viewModel: _authViewModel,
            );
          } else {
            return LoginPage(viewModel: _authViewModel);
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final AuthViewModel viewModel;

  const MyHomePage({super.key, required this.title, required this.viewModel});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Iniciar tracking automático al entrar a la pantalla principal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intentarIniciarTracking();
    });
  }

  void _intentarIniciarTracking() {
    final user = widget.viewModel.currentUser;
    if (user != null) {
      LocationService.iniciarTrackingAutomatico(
        context,
        user.idUsuario,
        token: user.token,
      );
    }
  }

  @override
  void dispose() {
    // Detener tracking al salir
    LocationService.detenerTrackingAutomatico();
    super.dispose();
  }

  void _cerrarSesion() {
    LocationService.detenerTrackingAutomatico();
    widget.viewModel.logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesión cerrada'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.viewModel.currentUser;

    final tabs = [
      _buildHomeTab(user),
      RoutePage(authViewModel: widget.viewModel, showAppBar: false),
      _buildProfileTab(user),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F6),
      appBar: AppBar(
        title: const Text(
          'Panel Administrativo SPB',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: Colors.white),
        ),
        elevation: 2,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF7A1C2E),
                Color(0xFF82263E),
                Color(0xFF111111),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: const Color(0xFFE74361),
          unselectedItemColor: const Color(0xFF4B4A4A),
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping),
              label: 'Rutas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner/Tarjeta de Bienvenida
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A1C2E), Color(0xFFD33F58)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A1C2E).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (user?.nombreChofer ?? user?.usuario ?? "U")
                        .trim()
                        .split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¡Bienvenido!',
                        style: TextStyle(
                          fontSize: 13.0,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        user?.nombreChofer ?? user?.usuario ?? 'Usuario',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28.0),

          // Centro de Operaciones
          const Text(
            'CENTRO DE OPERACIONES',
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B4A4A),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12.0),
          Card(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16.0),
              onTap: () {
                setState(() {
                  _currentIndex = 1; // Cambiar a pestaña de Rutas
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFffdadb), // primary-fixed-dim
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Color(0xFF5b021a), // primary
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.rol == 'operador' ? 'Mis Rutas Asignadas' : 'Ver Control de Rutas',
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            user?.rol == 'operador'
                                ? 'Gestiona tus entregas y visitas.'
                                : 'Monitorea todas las rutas globales.',
                            style: const TextStyle(
                              fontSize: 12.0,
                              color: Color(0xFF4B4A4A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28.0),

          // Telemetría & GPS
          const Text(
            'TELEMETRÍA Y RASTREO GPS',
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B4A4A),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12.0),
          ValueListenableBuilder<bool>(
            valueListenable: LocationService.trackingActivoNotifier,
            builder: (context, trackingActivo, _) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: trackingActivo ? const Color(0xFFD4EDDA) : const Color(0xFFFFEDED),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: trackingActivo ? const Color(0xFFC3E6CB) : const Color(0xFFFFC0C0),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: trackingActivo ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sensors,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trackingActivo ? 'Rastreo Activo en Vivo' : 'Rastreo Inactivo',
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                  color: trackingActivo ? const Color(0xFF155724) : const Color(0xFF721C24),
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                trackingActivo
                                    ? 'Reportando coordenadas GPS de la ruta en segundo plano.'
                                    : 'El servidor no puede recibir tu telemetría de ruta.',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: trackingActivo ? const Color(0xFF155724) : const Color(0xFF721C24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!trackingActivo) ...[
                      const SizedBox(height: 16.0),
                      ElevatedButton.icon(
                        onPressed: _intentarIniciarTracking,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text(
                          'ACTIVAR RASTREO GPS',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              (user?.nombreChofer ?? user?.usuario ?? "U")
                  .trim()
                  .split(' ')
                  .map((e) => e.isNotEmpty ? e[0] : '')
                  .take(2)
                  .join()
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            user?.nombreChofer ?? user?.usuario ?? 'Usuario',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 4.0),
          Text(
            user?.email ?? 'Sin correo',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24.0),
          const Divider(),
          const SizedBox(height: 16.0),
          _buildProfileDetailRow('Rol:', user?.rol.toUpperCase() ?? 'OPERADOR', Icons.admin_panel_settings_outlined),
          _buildProfileDetailRow('ID Chofer:', user?.idChofer?.toString() ?? 'N/A', Icons.badge_outlined),
          _buildProfileDetailRow('ID Usuario:', user?.idUsuario.toString() ?? 'N/A', Icons.person_outline),
          const SizedBox(height: 40.0),
          ElevatedButton.icon(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            label: const Text('CERRAR SESIÓN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4B4A4A), size: 22),
          const SizedBox(width: 16.0),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B4A4A), fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
