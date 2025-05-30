import 'package:flutter/material.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:urbanai/services/firestore_service.dart';
import 'package:urbanai/services/user_data.dart'; // FirestoreService

class EditarPerfilPage extends StatefulWidget {
  final UserData currentUserData; // Recebe os dados atuais do usuário

  const EditarPerfilPage({super.key, required this.currentUserData});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _telefoneController;
  // Adicione controllers para outros campos editáveis (ex: photoURL se for um link)

  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Inicializa os controllers com os dados atuais do usuário
    _nomeController = TextEditingController(text: widget.currentUserData.nome);
    _telefoneController = TextEditingController(text: widget.currentUserData.telefone);
  }

  @override
  void dispose() {
    // Libera os controllers quando o widget for descartado
    _nomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _salvarAlteracoes() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Prepara os dados para atualização
      // Apenas envia os campos que podem ser alterados.
      // O email e UID não são alterados aqui.
      await _firestoreService.cadastrarOuAtualizarUsuario(
        uid: widget.currentUserData.uid, // UID é essencial e não muda
        nome: _nomeController.text.trim(),
        telefone: _telefoneController.text.trim(),
        // photoURL: se você tiver um campo para editar a URL da foto
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green),
      );
      // Retorna para a ConfigPage, passando 'true' para indicar que houve atualização
      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar perfil: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        actions: [
          // Botão de salvar na AppBar para um visual mais padrão
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _salvarAlteracoes,
            tooltip: 'Salvar Alterações',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // --- Campo Nome ---
                    TextFormField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome Completo',
                        hintText: 'Seu nome como será exibido',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.secondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira seu nome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- Campo Telefone ---
                    TextFormField(
                      controller: _telefoneController,
                      decoration: InputDecoration(
                        labelText: 'Telefone',
                        hintText: '(XX) XXXXX-XXXX',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.secondary),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        // Validação simples de telefone (pode ser mais robusta)
                        if (value != null && value.isNotEmpty && value.length < 10) {
                          return 'Telefone inválido.';
                        }
                        return null; // Permite telefone vazio se não for obrigatório
                      },
                    ),
                    const SizedBox(height: 32),

                    // --- Botão Salvar (alternativa ao da AppBar) ---
                    // Se preferir o botão no corpo da página:
                    /*
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_outlined, color: Colors.white),
                      label: const Text('Salvar Alterações', style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: _isLoading ? null : _salvarAlteracoes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    */
                  ],
                ),
              ),
            ),
    );
  }
}