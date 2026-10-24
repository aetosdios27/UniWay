import 'dart:async';

import 'package:flutter/material.dart';
import 'core/services/google_sign_in_service.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/theme/uniway_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    GoogleSignInService().ensureInitialized().catchError((Object error) {}),
  );
  final themeController = ThemeController();
  await themeController.load();
  runApp(UniWayApp(themeController: themeController));
}

class UniWayApp extends StatefulWidget {
  final ThemeController? themeController;
  final Widget? home;

  const UniWayApp({super.key, this.themeController, this.home});

  @override
  State<UniWayApp> createState() => _UniWayAppState();
}

class _UniWayAppState extends State<UniWayApp> {
  late ThemeController _controller;
  bool _createdLocalController = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.themeController != null) {
      _controller = widget.themeController!;
      _createdLocalController = false;
    } else {
      _controller = ThemeController();
      _createdLocalController = true;
      unawaited(_controller.load());
    }
  }

  @override
  void didUpdateWidget(UniWayApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeController != widget.themeController) {
      if (_createdLocalController) {
        _controller.dispose();
      }
      _initController();
    }
  }

  @override
  void dispose() {
    if (_createdLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'UniWay - MUJ Campus Navigation',
            debugShowCheckedModeBanner: false,
            theme: UniWayTheme.light(),
            darkTheme: UniWayTheme.dark(),
            themeMode: _controller.mode,
            home: widget.home ?? const MapScreen(),
          );
        },
      ),
    );
  }
}
