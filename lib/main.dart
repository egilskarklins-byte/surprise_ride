import 'dart:ui';

import 'package:flutter/material.dart';

import 'services/app_language_service.dart';
import 'screens/new_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLanguageService.loadLanguage();

  runApp(const MyApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    AppLanguageService.language.addListener(
      _onLanguageChanged,
    );
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    AppLanguageService.language.removeListener(
      _onLanguageChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Surprise Ride',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const NewHomeScreen(),
    );
  }
}