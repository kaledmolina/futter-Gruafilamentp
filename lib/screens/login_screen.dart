import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'preoperational_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _checkApiConnection();
  }

  Future<void> _checkApiConnection() async {
    final status = await ApiService().checkApiStatus();
    if (mounted) {
      setState(() {
        _isConnected = status;
      });
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final success = await AuthService.instance.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      await NotificationService.instance.requestPermissionAndRegisterToken();

      try {
        final completed = await ApiService().hasCompletedInspectionToday();
        if (completed) {
          // ✅ Ya hizo la inspección, va al Home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // 🚫 No la hizo, mandarlo primero a la Inspección
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PreoperationalScreen()),
          );
        }
      } catch (e) {
        // Si hay error, muestra aviso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error verificando inspección. Intenta nuevamente.'),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas o error de conexión.')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: 100, // Ajusta la altura según sea necesario
                          errorBuilder: (context, error, stackTrace) {
                             return const Icon(Icons.business, size: 80, color: Colors.white);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Bienvenido',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico',
                            border: UnderlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : FilledButton(
                                onPressed: _login,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 50,
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text('Ingresar'),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Footer
                const Text(
                  'Desarrollado por Kaled Molina',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    if (_isConnected == null) {
      return const Chip(
        avatar: SizedBox(
          height: 15,
          width: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Verificando conexión...'),
      );
    }
    if (_isConnected == true) {
      return const Chip(
        avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
        label: Text('Conectado al servidor'),
        backgroundColor: Color.fromARGB(255, 225, 245, 226),
      );
    } else {
      return const Chip(
        avatar: Icon(Icons.error, color: Colors.red, size: 18),
        label: Text('Error de conexión'),
        backgroundColor: Color.fromARGB(255, 255, 230, 228),
      );
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    return GlassCard(
      borderRadius: 24.0,
      child: child,
    );
  }
}
