import 'package:flutter/material.dart';
import 'db_service.dart';
import 'ui/app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await DBService.init();
    print('Database initialized successfully');
  } catch (e) {
    print('Error initializing database: $e');
  }
  
  runApp(const AppRoot());
}