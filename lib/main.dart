import 'package:flutter/material.dart';
import 'screens/surprise/input_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Surprise Ride',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const SurpriseInputScreen(),
    );
  }
}