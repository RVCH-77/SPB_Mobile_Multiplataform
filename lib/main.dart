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
    return MaterialApp(
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

  @override
  Widget build(BuildContext context) {
    final user = widget.viewModel.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Primero detenemos el rastreo antes de cerrar la sesión
              LocationService.detenerTrackingAutomatico();
              widget.viewModel.logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sesión cerrada'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Bienvenido, ${user?.usuario ?? "Usuario"}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Email: ${user?.email ?? "Sin correo"}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4.0),
                Container(
                  margin: const EdgeInsets.only(top: 8.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Text(
                    'Rol: ${user?.rol.toUpperCase() ?? "Ninguno"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 40.0),
                
                // Card indicadora de estado de rastreo en tiempo real
                ValueListenableBuilder<bool>(
                  valueListenable: LocationService.trackingActivoNotifier,
                  builder: (context, trackingActivo, _) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: trackingActivo
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: trackingActivo
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                trackingActivo
                                    ? Icons.sensors
                                    : Icons.sensors_off,
                                color: trackingActivo
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                trackingActivo
                                    ? 'Rastreo Automático Activo'
                                    : 'Rastreo Automático Inactivo',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                  color: trackingActivo
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            trackingActivo
                                ? 'Tu ubicación se está reportando automáticamente en segundo plano cada 20 metros.'
                                : 'Activa el rastreo para que el panel administrativo pueda rastrear tu ruta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: trackingActivo
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                          if (!trackingActivo) ...[
                            const SizedBox(height: 12.0),
                            ElevatedButton(
                              onPressed: _intentarIniciarTracking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: const Text('Activar Rastreo'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24.0),
                
                // Botón/Tarjeta premium para acceder a las Rutas
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoutePage(authViewModel: widget.viewModel),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.route_outlined,
                              color: AppColors.primary,
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
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  user?.rol == 'operador'
                                      ? 'Consulta tus entregas, destino y choferes de apoyo.'
                                      : 'Monitorea todas las rutas globales del sistema.',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
