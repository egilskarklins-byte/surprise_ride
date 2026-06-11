import 'dart:ui';

import 'package:flutter/material.dart';
import 'screens/surprise/input_screen.dart';

void main() {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Surprise Ride',
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const SurpriseInputScreen(),
    );
  }
}