import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:urbanai/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/services/firestore_service.dart';
import 'package:urbanai/theme/app_theme.dart'; // <-- IMPORTA NOSSO NOVO ARQUIVO DE ESTILO

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  final AppServices _appServices = AppServices();
  final FirestoreService _firestoreService = FirestoreService();

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
                    controller: _emailController,
                    // ESTILO ATUALIZADO
                    decoration: getStyledInputDecoration('Email', icon: FontAwesomeIcons.envelope),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Senha ---
                  TextFormField(
                    controller: _passwordController,
                    // ESTILO ATUALIZADO
                    decoration: getStyledInputDecoration('Senha', icon: FontAwesomeIcons.lock),
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
                      onPressed: () { /* Adicionar lógica de redefinir senha aqui */ },
                      child: const Text("Esqueceu sua senha?", style: TextStyle(color: AppColors.secondary)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Botão de Entrar ---
                  ElevatedButton(
                    onPressed: _loading ? null : _performLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
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

  Future<void> _performLogin() async {
    // ... seu código do _performLogin (sem alterações) ...
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final senha = _passwordController.text.trim();
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      if (!mounted) return;
      User? user = userCredential.user;
      if (user != null) {
        await _firestoreService.cadastrarOuAtualizarUsuario(
          uid: user.uid,
          email: user.email!,
        );
        if (!mounted) return;
        _appServices.setConversationId(user.uid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login realizado com sucesso!'), backgroundColor: Colors.green),
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
      switch (e.code) {
        case 'user-not-found':
          msg = 'Usuário não encontrado. Verifique o email digitado.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Senha incorreta. Tente novamente.';
          break;
        case 'invalid-email':
          msg = 'O e-mail digitado não é válido.';
          break;
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}