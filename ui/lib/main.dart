import 'package:flutter/material.dart';
import 'db_service.dart';
import 'ui/app_root.dart';   


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBService.init();
  runApp(const AppRoot());
}
