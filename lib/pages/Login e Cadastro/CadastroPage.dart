import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbanai/theme/app_theme.dart'; // <-- IMPORTA NOSSO NOVO ARQUIVO DE ESTILO

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _loading = false;
  final FirestoreService _firestoreService = FirestoreService();
  final AppServices _appServices = AppServices();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Criar conta'),
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
                  // --- TextFormField para Nome ---
                  TextFormField(
                    controller: _nomeController,
                    // ESTILO ATUALIZADO
                    decoration: getStyledInputDecoration('Nome completo', icon: FontAwesomeIcons.user),
                    autofillHints: const [AutofillHints.name],
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

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

                  // --- TextFormField para Telefone ---
                  TextFormField(
                    controller: _telefoneController,
                    // ESTILO ATUALIZADO
                    decoration: getStyledInputDecoration('Telefone', icon: FontAwesomeIcons.phone),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Senha ---
                  TextFormField(
                    controller: _senhaController,
                    // ESTILO ATUALIZADO
                    decoration: getStyledInputDecoration('Senha', icon: FontAwesomeIcons.lock),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                       if (value == null || value.isEmpty) return 'Campo obrigatório';
                       if (value.length < 6) return 'A senha deve ter no mínimo 6 caracteres';
                       return null;
                    }
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Confirmar Senha ---
                  TextFormField(
                    controller: _confirmarSenhaController,
                    // ESTILO ATUALIZADO
                    decoration: getStyledInputDecoration('Confirmar senha', icon: FontAwesomeIcons.lock),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Campo obrigatório';
                      if (value != _senhaController.text) return 'As senhas não coincidem';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- Botão de Cadastrar ---
                  ElevatedButton(
                    onPressed: _loading ? null : _performCadastro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Cadastrar', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performCadastro() async {
    // ... seu código do _performCadastro (sem alterações) ...
     if (!_formKey.currentState!.validate()) {
      return; 
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
      if (!mounted) return; 
      User? user = userCredential.user; 
      if (user != null) {
        await _firestoreService.cadastrarOuAtualizarUsuario(
          uid: user.uid,
          email: user.email!, 
          nome: _nomeController.text.trim(),
          telefone: _telefoneController.text.trim().isNotEmpty ? _telefoneController.text.trim() : null,
        );
        if (!mounted) return;
        _appServices.setConversationId(user.uid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro realizado com sucesso!'), backgroundColor: Colors.green),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (Route<dynamic> route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do usuário após cadastro.'), backgroundColor: Colors.red),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      if (e.code == 'email-already-in-use') {
        msg = 'Esse e-mail já está cadastrado.';
      } else if (e.code == 'weak-password') {
        msg = 'A senha precisa ter pelo menos 6 caracteres.';
      } else if (e.code == 'invalid-email') {
        msg = 'E-mail inválido.';
      } else {
        msg = 'Erro no cadastro: ${e.message} (cód: ${e.code})';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado ao cadastrar: $e'), backgroundColor: Colors.red),
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }
}