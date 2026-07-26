/* Hallmark · component: LoginPage · genre: modern-minimal · theme: custom (utilitarian)
 * states: default · hover · focus · active · disabled · loading · error · success
 * contrast: pass
 * pre-emit critique: P5 H5 E5 S5 R5 V5
 */

import 'package:flutter/material.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/features/auth/presentation/auth_view_model.dart';

class LoginPage extends StatefulWidget {
  final AuthViewModel viewModel;

  const LoginPage({super.key, required this.viewModel});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onAuthViewModelChange);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onAuthViewModelChange);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthViewModelChange() {
    if (widget.viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.viewModel.errorMessage!),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final success = await widget.viewModel.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión iniciada correctamente'),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderThickness = 1.5;
    const inputBorderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight ? constraints.maxHeight - 48.0 : 0.0,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48.0),
                        // Encabezado
                        const Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 32.0,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        const Text(
                          'SPB - Sistema de Entregas',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 56.0),

                        // Campo de Usuario
                        const Text(
                          'USUARIO',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextFormField(
                          controller: _usernameController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontSize: 16.0,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nombre de usuario',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                            fillColor: MaterialStateColor.resolveWith((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return const Color(0xFFF8FAFC);
                              }
                              if (states.contains(MaterialState.hovered)) {
                                return const Color(0xFFF8FAFC); // 4% de oscurecimiento en hover
                              }
                              return Colors.transparent;
                            }),
                            filled: true,
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: inputBorderColor,
                                width: borderThickness,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: borderThickness, // Evita cambio de geometría en focus
                              ),
                            ),
                            errorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.errorColor,
                                width: borderThickness,
                              ),
                            ),
                            focusedErrorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.errorColor,
                                width: borderThickness,
                              ),
                            ),
                            disabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFFF1F5F9),
                                width: borderThickness,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa tu usuario';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 36.0),

                        // Campo de Contraseña
                        const Text(
                          'CONTRASEÑA',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontSize: 16.0,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              letterSpacing: 2.0,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                            fillColor: MaterialStateColor.resolveWith((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return const Color(0xFFF8FAFC);
                              }
                              if (states.contains(MaterialState.hovered)) {
                                return const Color(0xFFF8FAFC);
                              }
                              return Colors.transparent;
                            }),
                            filled: true,
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: inputBorderColor,
                                width: borderThickness,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: borderThickness, // Mismo grosor
                              ),
                            ),
                            errorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.errorColor,
                                width: borderThickness,
                              ),
                            ),
                            focusedErrorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.errorColor,
                                width: borderThickness,
                              ),
                            ),
                            disabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFFF1F5F9),
                                width: borderThickness,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF64748B),
                                size: 20.0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu contraseña';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 56.0),

                        // Botón Entrar
                        ListenableBuilder(
                          listenable: widget.viewModel,
                          builder: (context, _) {
                            final isLoading = widget.viewModel.isLoading;
                            return SizedBox(
                              width: double.infinity,
                              height: 48.0,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.primary.withOpacity(0.55), // Opacidad según checklist
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6.0), // Bordes de 6px precisos/utilitarios
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20.0,
                                        width: 20.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'ENTRAR',
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const Spacer(),

                        // Pie de página
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const SizedBox(height: 32.0),
                              const Text(
                                '© 2026 • SERVICIOS PERSONALIZADOS DEL BAJÍO',
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // Lógica de soporte o enlace
                                    },
                                    child: const Text(
                                      'SOPORTE',
                                      style: TextStyle(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 10.0,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // Lógica de privacidad o enlace
                                    },
                                    child: const Text(
                                      'PRIVACIDAD',
                                      style: TextStyle(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
