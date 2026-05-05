import 'package:flutter/material.dart';
import 'services/user_session.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/beranda.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOEIC Prep',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BerandaScreen(userName: "Jesika Rika"),
    );
  }
}
