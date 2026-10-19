import 'dart:async';

import 'package:flutter/material.dart';
import 'core/services/google_sign_in_service.dart';
import 'presentation/screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    GoogleSignInService().ensureInitialized().catchError((Object error) {}),
  );
  runApp(const UniWayApp());
}

class UniWayApp extends StatelessWidget {
  const UniWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniWay - MUJ Campus Navigation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MapScreen(),
    );
  }
}
