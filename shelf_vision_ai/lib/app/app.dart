import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../presentation/controllers/detection_controller.dart';
import '../presentation/controllers/theme_controller.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/live_detection_screen.dart';
import '../presentation/screens/capture_screen.dart';
import '../presentation/screens/result_screen.dart';

class ShelfVisionApp extends StatelessWidget {
  const ShelfVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()..loadTheme()),
        ChangeNotifierProvider(create: (_) => DetectionController()..initialize()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'ShelfVision AI',
            debugShowCheckedModeBanner: false,
            // Defaults to Light Theme; persists user preferences.
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeController.themeMode,
            // Honour the user's font size but cap extreme scales so fixed-size
            // controls (shutter, camera chrome, HUD) never overflow.
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
              child: child ?? const SizedBox.shrink(),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const HomeScreen(),
              // Camera screens stay dark in both modes (like the system camera).
              '/live': (context) => Theme(data: AppTheme.dark, child: const LiveDetectionScreen()),
              '/capture': (context) => Theme(data: AppTheme.dark, child: const CaptureScreen()),
              '/result': (context) => const ResultScreen(),
            },
          );
        },
      ),
    );
  }
}
