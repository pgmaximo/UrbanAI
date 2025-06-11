// lib/pages/AuthPage.dart

import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/CadastroPage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/LoginPage.dart';
import 'package:urbanai/services/auth_service.dart'; // IMPORTA O NOVO SERVIÇO
import 'package:urbanai/widget/LoginButton.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Instância do nosso novo serviço de autenticação
    final AuthService authService = AuthService();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                const Text('Bem-vindo ao UrbanAI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 16),
                const Text('Sua jornada para o imóvel ideal começa aqui.', style: TextStyle(fontSize: 16, color: AppColors.secondary)),
                const SizedBox(height: 32),

                // --- Botão Google ---
                LoginButton(
                  icon: const FaIcon(FontAwesomeIcons.google, color: AppColors.primary, size: 22),
                  text: 'Continuar com Google',
                  color: Colors.white,
                  textColor: Colors.black87,
                  onPressed: () async {
                    // CHAMA O MÉTODO UNIFICADO DO NOSSO SERVIÇO
                    final UserCredential? userCredential = await authService.signInWithGoogle(context);

                    // Se o login foi bem-sucedido, navega para a HomePage
                    if (userCredential != null && context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),
                        (route) => false,
                      );
                    }
                    // Se falhou, o próprio AuthService já mostrou o SnackBar de erro.
                  },
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("ou", style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                LoginButton(
                  icon: const FaIcon(FontAwesomeIcons.envelope, color: AppColors.primary, size: 22),
                  text: 'Entrar com Email',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  }, color: Colors.white, textColor: Colors.black87,
                ),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CadastroPage()),
                    );
                  },
                  child: const Text(
                    "Não tem uma conta? Crie uma agora",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}