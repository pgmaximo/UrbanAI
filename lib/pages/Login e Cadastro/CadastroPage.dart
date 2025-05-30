import 'package:flutter/material.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:urbanai/pages/HomePage.dart';
import 'package:urbanai/services/app_services.dart'; // Importar AppServices
import 'package:urbanai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirestoreService _firestoreService = FirestoreService(); // Instância do serviço
  final AppServices _appServices = AppServices(); // Instância do AppServices

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
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    autofillHints: const [AutofillHints.name],
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Email ---
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', filled: true, /* ... */),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Telefone ---
                  TextFormField(
                    controller: _telefoneController,
                    decoration: const InputDecoration(labelText: 'Telefone', filled: true, /* ... */),
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Senha ---
                  TextFormField(
                    controller: _senhaController,
                    decoration: const InputDecoration(labelText: 'Senha', filled: true, /* ... */),
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- TextFormField para Confirmar Senha ---
                  TextFormField(
                    controller: _confirmarSenhaController,
                    decoration: const InputDecoration(labelText: 'Confirmar senha', filled: true, /* ... */),
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
                    onPressed: _loading ? null : _performCadastro, // Chamada para o método de cadastro
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox( /* Indicador de loading */)
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

  // Método para executar o processo de cadastro
  Future<void> _performCadastro() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return; // Se o formulário não for válido, não faz nada.
    }

    // Garante que o widget ainda está montado antes de alterar o estado.
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // 1. Cria o usuário no Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      if (!mounted) return; // Checa novamente após o await

      User? user = userCredential.user; // Obtém o objeto User do Firebase Auth

      if (user != null) {
        // 2. Salva/Atualiza dados adicionais no Firestore usando o método do FirestoreService
        await _firestoreService.cadastrarOuAtualizarUsuario(
          uid: user.uid, // UID vindo do Firebase Auth
          email: user.email!, // Email vindo do Firebase Auth (mais confiável)
          nome: _nomeController.text.trim(),
          telefone: _telefoneController.text.trim().isNotEmpty ? _telefoneController.text.trim() : null,
        );

        if (!mounted) return;

        // 3. IMPORTANTE: Define o ID da conversa no AppServices com o UID do usuário.
        // Isso garante que o histórico de chat seja associado a este usuário.
        _appServices.setConversationId(user.uid);

        // Feedback de sucesso para o usuário
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Limpa os campos do formulário
        _nomeController.clear();
        _emailController.clear();
        _telefoneController.clear();
        _senhaController.clear();
        _confirmarSenhaController.clear();

        // Aguarda um instante antes de navegar para dar tempo ao usuário de ler o SnackBar
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        // Navega para a HomePage e remove todas as rotas anteriores da pilha
        // para que o usuário não possa voltar para a tela de cadastro/login.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (Route<dynamic> route) => false,
        );
      } else {
        // Caso raro onde userCredential não é nulo, mas user é nulo.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do usuário após cadastro.'), backgroundColor: Colors.red),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Tratamento específico para erros do Firebase Authentication
      String msg;
      if (e.code == 'email-already-in-use') {
        msg = 'Esse e-mail já está cadastrado.';
      } else if (e.code == 'weak-password') { // Firebase agora usa 'weak-password'
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
      // Tratamento para outros erros (ex: erro ao salvar no Firestore, se relançado)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro inesperado ao cadastrar: $e'), backgroundColor: Colors.red),
      );
    }

    // Garante que o estado de loading seja desativado ao final, mesmo se houver erro.
    if (!mounted) return;
    setState(() => _loading = false);
  }

  // Lembre-se de liberar os controllers no dispose
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