import 'package:flutter/material.dart';
import 'package:urbanai/pages/WelcomePage.dart';

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
      home: WelcomePage(),
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


