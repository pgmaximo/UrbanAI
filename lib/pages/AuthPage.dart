import 'package:flutter/material.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/CadastroPage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/LoginPage.dart';
import 'package:urbanai/widget/LoginButton.dart'; // Certifique-se que este widget existe e está correto
import 'package:urbanai/services/app_services.dart';     // Importar AppServices
import 'package:urbanai/services/firestore_service.dart'; // Importar FirestoreService
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  // Instâncias dos serviços
  // Como AuthPage é StatelessWidget, podemos instanciar aqui ou passar como parâmetro
  // se fosse um StatefulWidget. Para simplicidade, vamos instanciar dentro da função.
  // Ou, se preferir, pode fazer AppServices() e FirestoreService() diretamente.

  // Função utilitária para login/cadastro com Google (Web)
  Future<UserCredential?> _signInWithGoogle(BuildContext context) async {
    // Instanciar serviços aqui ou usar os globais se AppServices for um singleton
    final AppServices appServices = AppServices();
    final FirestoreService firestoreService = FirestoreService();

    try {
      final googleProvider = GoogleAuthProvider();
      // Para web, signInWithPopup é comum.
      final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);

      User? user = userCredential.user; // Obtém o objeto User

      if (user != null) {
        // 1. Salva/Atualiza dados do usuário do Google no Firestore
        // Isso garante que tenhamos um perfil no Firestore para o usuário do Google.
        await firestoreService.cadastrarOuAtualizarUsuario(
          uid: user.uid,
          email: user.email ?? 'no-email-provided@example.com', // Fornecer um fallback
          nome: user.displayName, // Nome vindo do perfil Google
          photoURL: user.photoURL, // Foto vinda do perfil Google
          // Telefone geralmente não é fornecido pelo Google Auth.
          // O usuário poderia adicioná-lo mais tarde no perfil do app.
        );

        // 2. IMPORTANTE: Define o ID da conversa no AppServices com o UID do usuário.
        appServices.setConversationId(user.uid);

        print("Login com Google bem-sucedido e dados salvos/atualizados para UID: ${user.uid}");
      }
      return userCredential; // Retorna para que o chamador possa navegar

    } on FirebaseAuthException catch (e) {
      // Tratar erros específicos do FirebaseAuth
      print('Erro FirebaseAuth no login/cadastro com Google: ${e.code} - ${e.message}');
      String errorMessage = "Não foi possível fazer login com Google. Tente novamente.";
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = "Já existe uma conta com este e-mail usando um método de login diferente.";
      } else if (e.code == 'popup-closed-by-user') {
        errorMessage = "O pop-up de login com Google foi fechado antes da conclusão.";
      }
      // Adicionar mais tratamentos de erro conforme necessário

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
      return null;
    } catch (e) {
      // Tratar outros erros genéricos
      print('Erro genérico no login/cadastro com Google: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ocorreu um erro inesperado com o login do Google."), backgroundColor: Colors.red),
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
                const Text('Conta', style: TextStyle(fontSize: 28, /* ... */)),
                const SizedBox(height: 16),
                const Text('Faça login para continuar...', style: TextStyle(fontSize: 16, /* ... */)),
                const SizedBox(height: 32),

                // --- Botão Google ---
                LoginButton( // Certifique-se que seu widget LoginButton está correto
                  icon: const FaIcon(FontAwesomeIcons.google, color: AppColors.primary, size: 22),
                  text: 'Continue com Google',
                  color: Colors.white,
                  textColor: Colors.black87,
                  onPressed: () async {
                    // Chama a função _signInWithGoogle atualizada
                    final userCredential = await _signInWithGoogle(context);

                    // Se o login/cadastro com Google for bem-sucedido e tivermos um usuário
                    if (userCredential != null && userCredential.user != null) {
                      if (!context.mounted) return; // Checa se o widget ainda está montado
                      // Navega para a HomePage e remove todas as rotas anteriores
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),
                        (route) => false,
                      );
                    }
                    // Se userCredential for null, a função _signInWithGoogle já mostrou o SnackBar de erro.
                  },
                ),
                const SizedBox(height: 20),
                // ... (Resto do seu layout com Divider, botão de Email/Telefone, Criar conta) ...
                // A navegação para LoginPage e CadastroPage está correta como você tinha.

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
                  icon: const FaIcon(FontAwesomeIcons.envelope,color: AppColors.primary ,size: 22,),
                  text: 'Login com Email', // Ajustado para refletir a LoginPage
                  color: Colors.white,
                  textColor: AppColors.secondary,
                  borderColor: AppColors.background, // Supondo que seja uma cor de borda sutil
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