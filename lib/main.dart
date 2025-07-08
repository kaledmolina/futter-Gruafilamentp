import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart'; 


void main() async {
   // Asegura que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase usando las opciones para la plataforma actual
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Inicializa nuestro servicio de notificaciones.
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App para Técnicos',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      // Determina la pantalla inicial basada en si el usuario ya ha iniciado sesión.
      home: FutureBuilder<bool>(
        future: AuthService.instance.isLoggedIn(),
        builder: (context, snapshot) {
          // Muestra un indicador de carga mientras se verifica el estado de la sesión.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // Si el usuario está logueado, lo lleva a la pantalla principal.
          if (snapshot.hasData && snapshot.data == true) {
            return const HomeScreen();
          }
          // Si no, lo lleva a la pantalla de login.
          return const LoginScreen();
        },
      ),
    );
  }
}
