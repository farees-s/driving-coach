import 'dart:io';
import 'package:flutter/material.dart';
import 'db_service.dart';
import 'app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBService.init();

  try {
    Process.start('bash', ['backend/start_backend.sh'], // starting backend
        mode: ProcessStartMode.detached);
  } catch (_) {}

  runApp(const _MyApp());
}

class _MyApp extends StatelessWidget {
  const _MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Coach',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AppRoot(),
    );
  }
}
