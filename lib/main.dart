import 'package:flutter/material.dart';
import 'package:urbanai/pages/WelcomePage.dart';
import 'package:urbanai/scripts/ScriptTestPage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: 'lib/Scripts/.env');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
      ),
      home: WelcomePage(),
      // Para testar ScriptTestPage, basta trocar aqui:
      // home: ScriptTestPage(),
    );
  }
}

class AppColors {
  /// Cor de fundo principal – Bege claro/rosado.
  static const Color background = Color(0xFFF6F0E8);

  /// Cor principal – Verde acinzentado escuro.
  static const Color primary = Color(0xFF43523D);

  /// Cor secundária – Verde escuro elegante (botões principais).
  static const Color secondary = Color(0xFF223E2D);
}
