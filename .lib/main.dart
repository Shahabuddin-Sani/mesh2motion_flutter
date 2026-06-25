import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/editor_screen.dart';
import 'theme/app_theme.dart';
import 'models/editor_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  M2MLogger.info('Starting Mesh2Motion application...');
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EditorProvider()),
      ],
      child: const Mesh2MotionApp(),
    ),
  );
}

class Mesh2MotionApp extends StatelessWidget {
  const Mesh2MotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh2Motion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const EditorScreen(),
    );
  }
}
