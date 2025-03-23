import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/web_view_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置应用仅支持竖屏模式
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 设置状态栏风格
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const VoiceprintBusinessApp());
}

class VoiceprintBusinessApp extends StatelessWidget {
  const VoiceprintBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '声纹通',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // 深蓝色作为主题色
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'PingFang SC',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}
