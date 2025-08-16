import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'preoperational_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInspectionStatus();
  }

  Future<void> _checkInspectionStatus() async {
    // Pequeña demora para que la transición no sea tan abrupta
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final completed = await ApiService().hasCompletedInspectionToday();
      if (mounted) {
        if (completed) {
          // Si ya completó la inspección, va a la pantalla principal.
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else {
          // Si no, va a la pantalla de inspección.
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PreoperationalScreen()));
        }
      }
    } catch (e) {
      // Si hay un error (ej. token inválido), lo mandamos al login.
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
