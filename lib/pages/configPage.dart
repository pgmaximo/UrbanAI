import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/AuthPage.dart';
import 'package:urbanai/pages/Login%20e%20Cadastro/EditarPage.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbanai/services/user_data.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final AppServices _appServices = AppServices();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService(); // Instância do FirestoreService

  UserData? _userData; // Armazena os dados do perfil do usuário
  bool _isLoadingUserData = true; // Controla o estado de carregamento dos dados do perfil
  String? _loadingError; // Armazena mensagens de erro, se houver

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Carrega os dados do usuário ao iniciar a tela
  }

  /// Busca os dados do usuário logado (do Auth e do Firestore).
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoadingUserData = true; // Inicia o carregamento
      _loadingError = null;      // Limpa erros anteriores
    });

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        // Busca dados complementares do Firestore
        UserData? firestoreData = await _firestoreService.getUserData(currentUser.uid);

        if (firestoreData != null) {
          _userData = firestoreData; // Usa dados do Firestore (mais completos)
        } else {
          // Se não encontrar no Firestore, usa os dados básicos do FirebaseAuth
          // e talvez indique que o perfil pode estar incompleto.
          _userData = UserData(
            uid: currentUser.uid,
            email: currentUser.email ?? 'Email não disponível',
            nome: currentUser.displayName, // Pode ser nulo
            photoURL: currentUser.photoURL,
            // Telefone não viria daqui
          );
          print("Dados do usuário não encontrados no Firestore, usando dados básicos do Auth.");
        }
      } catch (e) {
        print("Exceção ao buscar dados do usuário: $e");
        _loadingError = "Não foi possível carregar os dados do perfil.";
      }
    } else {
      _loadingError = "Nenhum usuário logado.";
    }

    // Atualiza o estado da UI após o carregamento (ou erro)
    if (mounted) {
      setState(() => _isLoadingUserData = false);
    }
  }

  /// Realiza o logout do usuário.
  Future<void> _performLogout() async {
    try {
      await _auth.signOut();
      _appServices.setConversationId(''); // Limpa o ID da conversa no AppServices
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Erro ao fazer logout: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Limpa o histórico de conversas do usuário.
  Future<void> _limparHistoricoConversa() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) { // Usar dialogContext para clareza
        return AlertDialog(
          title: const Text('Limpar Histórico?'),
          content: const Text(
              'Todas as suas mensagens de conversa com a IA serão permanentemente apagadas. Esta ação não pode ser desfeita.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Limpar', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _appServices.limparHistorico();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Histórico de conversa limpo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao limpar histórico: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
      ),
      body: _buildBody(), // Chama um método para construir o corpo da tela
    );
  }

  /// Constrói o corpo da tela com base no estado de carregamento dos dados.
  Widget _buildBody() {
    if (_isLoadingUserData) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _loadingError!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_userData == null) {
      // Caso de usuário não logado ou dados não puderam ser construídos (improvável se _loadingError for null)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Não foi possível carregar as informações do usuário.",
            style: TextStyle(color: AppColors.secondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Se os dados foram carregados com sucesso, constrói a UI principal
    return _buildProfileView();
  }

  /// Constrói a visualização principal do perfil e as opções.
  Widget _buildProfileView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              _buildUserProfileHeader(_userData!), // Passa os dados do usuário
              const SizedBox(height: 32),
              _buildActionButtons(), // Botões de ação
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói o cabeçalho do perfil do usuário (Avatar, Nome, Email, Telefone).
  Widget _buildUserProfileHeader(UserData user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
              ? NetworkImage(user.photoURL!)
              : const AssetImage("asset/avatar/default_avatar.jpg") as ImageProvider,
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 24),
        Text(
          user.displayName, // Usa o getter do UserData
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "${user.email}\nTelefone: ${user.telefone ?? 'Não informado'}",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.secondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Constrói a seção de botões de ação.
  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // Faz os botões ocuparem a largura
      children: [
        _buildConfigButton(
          icon: Icons.edit,
          text: 'Editar Perfil',
          onPressed: () {
            if (_userData != null) { // Garante que temos os dados do usuário para passar
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditarPerfilPage(currentUserData: _userData!),
                ),
              ).then((dadosForamAtualizados) {
                // Este callback é executado quando EditarPerfilPage é "popada"
                if (dadosForamAtualizados == true) {
                  // Se EditarPerfilPage retornou true, significa que as alterações foram salvas.
                  // Recarregamos os dados do usuário na ConfigPage para exibir as informações atualizadas.
                  print("Perfil atualizado, recarregando dados na ConfigPage.");
                  _fetchUserData(); // O método que você usa para carregar dados do usuário na ConfigPage
                }
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dados do usuário ainda não carregados.')),
              );
            }
          },
          backgroundColor: AppColors.secondary,
        ),
        const SizedBox(height: 16),
        _buildConfigButton(
          icon: Icons.delete_sweep_outlined,
          text: 'Limpar Histórico',
          onPressed: _limparHistoricoConversa,
          backgroundColor: Colors.orange.shade700,
        ),
        const SizedBox(height: 16),
        _buildConfigButton(
          icon: Icons.logout,
          text: 'Sair da Conta',
          onPressed: _performLogout,
          backgroundColor: Colors.redAccent,
        ),
      ],
    );
  }

  /// Widget auxiliar para criar botões de configuração padronizados.
  Widget _buildConfigButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(text, style: const TextStyle(fontSize: 16, color: Colors.white)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        minimumSize: const Size(double.infinity, 50), // Ocupa largura total
      ),
    );
  }
}