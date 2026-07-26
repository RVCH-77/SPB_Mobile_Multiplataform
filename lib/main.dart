import 'package:flutter/material.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/core/theme/app_theme.dart';
import 'package:first_app/features/auth/data/app_repository.dart';
import 'package:first_app/features/auth/presentation/auth_view_model.dart';
import 'package:first_app/features/auth/presentation/login_page.dart';

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

class MyHomePage extends StatelessWidget {
  final String title;
  final AuthViewModel viewModel;

  const MyHomePage({super.key, required this.title, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final user = viewModel.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () {
              viewModel.logout();
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
            ],
          ),
        ),
      ),
    );
  }
}
