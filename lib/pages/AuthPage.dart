import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/CadastroPage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/LoginPage.dart';
import 'package:urbanai/widget/LoginButton.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  // Função utilitária para login/cadastro com Google (Web)
  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      return userCredential;
    } catch (e) {
      print('Erro no login/cadastro com Google: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível fazer login com Google.")),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Conta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Faça login para continuar e acessar suas conversas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                // Botão Google
                LoginButton(
                  icon: FaIcon(FontAwesomeIcons.google, color: Colors.red,size: 22,),
                  text: 'Continue com Google',
                  color: Colors.white,
                  textColor: Colors.black87,
                  onPressed: () async {
                    final userCredential = await signInWithGoogle(context);
                    if (userCredential != null) {
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("ou", style: TextStyle(color: AppColors.primary)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                LoginButton(
                  icon: FaIcon(FontAwesomeIcons.envelope,color: Colors.grey,size: 22,),
                  text: 'Login com Email ou Telefone',
                  color: Colors.white,
                  textColor: AppColors.secondary,
                  borderColor: AppColors.background,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
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
                    "Criar conta",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
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
