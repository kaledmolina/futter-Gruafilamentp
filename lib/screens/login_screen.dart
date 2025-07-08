import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
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
      print("==> Login exitoso. Procediendo a solicitar permisos de notificación.");
      // CAMBIO: Capturamos el posible error de la solicitud de permisos.
      final String? error = await NotificationService.instance.requestPermissionAndRegisterToken();
      
      if (error != null && mounted) {
        // Si hay un error, lo mostramos en un SnackBar.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Atención: $error'),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
      
      // Navegamos a la pantalla principal independientemente del error de notificación.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas o error de conexión.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChip() {
    if (_isConnected == null) {
      return const Chip(
        avatar: SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión de Técnico')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusChip(),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      child: const Text('Ingresar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
