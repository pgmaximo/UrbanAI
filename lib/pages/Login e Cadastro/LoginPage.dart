import 'package:flutter/material.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/services/app_services.dart'; // Importar AppServices
import 'package:urbanai/services/firestore_service.dart'; // Opcional, para atualizar dados do usuário

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController(); // Renomeado para clareza
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  final AppServices _appServices = AppServices(); // Instância do AppServices
  final FirestoreService _firestoreService = FirestoreService(); // Instância para atualizar dados do usuário

  // // Método para exibir diálogo de redefinição de senha
  // Future<void> _showResetPasswordDialog() async {
  //   final dialogEmailController = TextEditingController();
  //   // ... (código do diálogo de redefinição de senha - mantido como no seu original) ...
  //   // Certifique-se que a lógica de envio de email e feedback está correta
  //   await showDialog( /* ... seu código de diálogo ... */ );
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TextFormField para Email ---
                  TextFormField(
                    controller: _emailController, // Usando _emailController
                    decoration: const InputDecoration(labelText: 'Email', filled: true, /* ... */),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Senha ---
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha', filled: true, /* ... */),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                     validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 4),

                  // --- Botão "Esqueceu sua senha?" ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      // onPressed: _showResetPasswordDialog,
                      onPressed: null,
                      child: const Text("Esqueceu sua senha?", /* ... estilo ... */),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Botão de Entrar ---
                  ElevatedButton(
                    onPressed: _loading ? null : _performLogin, // Chamada para o método de login
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox( /* Indicador de loading */)
                        : const Text('Entrar', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Método para executar o processo de login
  Future<void> _performLogin() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final senha = _passwordController.text.trim();

      // 1. Faz o login com Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      if (!mounted) return;

      User? user = userCredential.user;

      if (user != null) {
        // 2. OPCIONAL, mas recomendado: Atualizar dados no Firestore (ex: ultimoLogin)
        // Isso também garante que o documento do usuário exista na coleção 'usuarios'
        // e que o documento de conversa seja criado se não existir.
        await _firestoreService.cadastrarOuAtualizarUsuario(
          uid: user.uid,
          email: user.email!, // Passar o email para garantir que está atualizado
          // Não precisa passar nome, telefone, etc., a menos que queira atualizá-los aqui.
          // O `merge: true` no método do FirestoreService cuidará de atualizar apenas os campos fornecidos.
        );

        if (!mounted) return;

        // 3. IMPORTANTE: Define o ID da conversa no AppServices com o UID do usuário.
        _appServices.setConversationId(user.uid);

        // Feedback e navegação
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do usuário após login.'), backgroundColor: Colors.red),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      // Seu switch case para tratamento de erros do FirebaseAuthException está bom.
      // Apenas certifique-se que os códigos de erro estão atualizados.
      // 'invalid-credential' é um código comum para email/senha errados.
      switch (e.code) {
        case 'user-not-found':
          msg = 'Usuário não encontrado. Verifique o email digitado.';
          break;
        case 'wrong-password': // Comum para senha incorreta
        case 'invalid-credential': // Também usado para credenciais inválidas
          msg = 'Senha incorreta. Tente novamente.';
          break;
        case 'invalid-email':
          msg = 'O e-mail digitado não é válido.';
          break;
        // ... (outros casos que você já tem) ...
        default:
          msg = 'Erro no login: ${e.message} (cód: ${e.code})';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado ao fazer login: $e'), backgroundColor: Colors.red),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  // Lembre-se de liberar os controllers no dispose
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}