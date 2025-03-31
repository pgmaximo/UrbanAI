import 'package:flutter/material.dart';
import 'pages/HomePage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban.AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
      ),
      home: HomePage(),
    );
  }
}

class AppColors {
  /// Cor Primária (60%) – Azul Escuro
  /// Transmite confiança, estabilidade e modernidade.
  static const Color primary = Color(0xFF1A237E);

  /// Cor Secundária (30%) – Verde Vibrante
  /// Remete a crescimento, equilíbrio e harmonia.
  static const Color secondary = Color(0xFF43A047);

  /// Cor Terciária (10%) – Laranja Vibrante
  /// Chama atenção para ações, botões de CTA e alertas.
  static const Color tertiary = Color(0xFFFB8C00);

  /// Fundo off-white, suave e agradável aos olhos.
  static const Color background = Color(0xFFF5F5F5);
}
