import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'services/upload_service.dart';
import 'services/sync_service.dart';
import 'widgets/app_background.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('es_CO', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.initialize();
  UploadService.instance.start();
  SyncService.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      title: 'App para Técnicos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue.shade300,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(textTheme).copyWith(
          bodyMedium: GoogleFonts.poppins(textStyle: textTheme.bodyMedium),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: AuthService.instance.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(child: CircularProgressIndicator())
              )
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const SplashScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}