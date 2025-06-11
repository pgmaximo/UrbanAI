import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/configPage.dart';
import 'package:urbanai/pages/favoritosPage.dart';
import 'package:urbanai/services/user_services.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbanai/services/user_data.dart';
import 'package:urbanai/widget/imovel_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final UserServices _userServices = UserServices();
  final AppServices _appServices = AppServices();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserData? _userDataDrawer;
  bool _isLoadingUserDataDrawer = true;
  String? _userDataDrawerError;
  bool _isLoading = false;
  final String _loadingMessage = "Assistente está pesquisando...";

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _appServices.setConversationId(currentUser.uid);
    }

    _carregarHistoricoDaUI();
    _fetchUserDataDrawer();
  }

  Future<void> _fetchUserDataDrawer() async {
    setState(() {
      _isLoadingUserDataDrawer = true;
      _userDataDrawerError = null;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        UserData? firestoreData = await _firestoreService.getUserData(currentUser.uid);
        _userDataDrawer = firestoreData ?? UserData(
          uid: currentUser.uid,
          email: currentUser.email ?? 'Email não disponível',
          nome: currentUser.displayName,
          photoURL: currentUser.photoURL,
        );
      } catch (e) {
        _userDataDrawerError = "Não foi possível carregar o usuário.";
      }
    } else {
      _userDataDrawerError = "Nenhum usuário logado.";
    }

    if (mounted) {
      setState(() => _isLoadingUserDataDrawer = false);
    }
  }

  Future<void> _carregarHistoricoDaUI() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    await _appServices.carregarHistoricoDoFirebase();
    final historicoCache = _appServices.getHistoricoConversaCache();

    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (final item in historicoCache) {
        if (item['role'] == 'user') {
          _messages.add({"text": item['content']!, "isUser": true, "isCard": false});
        } else if (item['role'] == 'assistant') {
          _exibirRespostaNaUI(item['content']!);
        }
      }
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _exibirRespostaNaUI(String mensagemOriginal) {
    List<Map<String, dynamic>> cards = _userServices.extractImovelCards(mensagemOriginal);
    String texto = _userServices.removeCardJsonFromString(mensagemOriginal);

    if (!mounted) return;
    
    setState(() {
      if (texto.isNotEmpty && texto != "[CARD DO IMÓVEL]") {
        _messages.add({"text": texto, "isUser": false, "isCard": false});
      }
      for (var cardData in cards) {
        _messages.add({"text": "", "isUser": false, "isCard": true, "cardData": cardData});
      }
    });
    _scrollToBottom();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _messages.add({"text": text, "isUser": true, "isCard": false});
    });
    _controller.clear();
    _scrollToBottom();

    await _appServices.salvarMensagem('user', text);
    final Map<String, dynamic> respostaN8N = await _userServices.enviarMensagem(text);

    if (!mounted) {
      setState(() => _isLoading = false);
      return;
    }

    final String conteudoOriginalAssistente = respostaN8N['conteudo_original'] ?? '';
    if (conteudoOriginalAssistente.isNotEmpty) {
      await _appServices.salvarMensagem('assistant', conteudoOriginalAssistente);
    }
    
    if (respostaN8N['tipo_resposta'] != 'erro') {
      _exibirRespostaNaUI(conteudoOriginalAssistente);
    } else {
       _messages.add({
         "text": respostaN8N['conteudo_texto'], 
         "isUser": false, 
         "isCard": false
        });
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildImovelCard(Map<String, dynamic> cardData) {
    return ImovelCard(cardData: cardData);
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final isCard = message['isCard'] == true;

    if (isCard) {
      final cardData = message['cardData'] as Map<String, dynamic>;
      return _buildImovelCard(cardData);
    }

    if (message['text'] == null || message['text'].toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
            color: isUser ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: Offset(0, 1))]),
        child: SelectableText(
          message['text'].toString(),
          style: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black87, height: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Image.asset('asset/logos/logo_nome.png', height: 120),
        centerTitle: true,
      ),
      drawer: Drawer(
         child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ... (código do seu UserAccountsDrawerHeader, que está correto) ...
           _isLoadingUserDataDrawer
              ? DrawerHeader(
                  decoration: BoxDecoration(color: AppColors.primary),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : (_userDataDrawerError != null
                  ? DrawerHeader(
                      decoration: BoxDecoration(color: AppColors.primary),
                      child: Center(
                        child: Text(
                          _userDataDrawerError!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : UserAccountsDrawerHeader(
                      decoration: BoxDecoration(color: AppColors.primary),
                      currentAccountPicture: CircleAvatar(
                        radius: 34,
                        backgroundImage: (_userDataDrawer != null &&
                                _userDataDrawer!.photoURL != null &&
                                _userDataDrawer!.photoURL!.isNotEmpty)
                            ? NetworkImage(_userDataDrawer!.photoURL!)
                            : const AssetImage("asset/avatar/default_avatar.jpg") as ImageProvider,
                        backgroundColor: Colors.white,
                      ),
                      accountName: Text(
                        _userDataDrawer?.displayName ?? "Usuário",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      accountEmail: Text(
                        _userDataDrawer?.email ?? "",
                        style: const TextStyle(fontSize: 15),
                      ),
                    )),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.secondary),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfigPage()),
              ).then((_) {
                // ############ CORREÇÃO APLICADA AQUI ############
                if (mounted) {
                  // Atualiza tanto os dados do drawer QUANTO o chat
                  _fetchUserDataDrawer();
                  _carregarHistoricoDaUI(); 
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: AppColors.secondary),
            title: const Text('Favoritos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritosPage()),
              );
            },
          ),
        ],
      ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty && _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessage(_messages[index]),
                  ),
            ),
            if (_isLoading && _messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(fontSize: 14, color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
            Container(
                 decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.05),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ).copyWith(
                bottom: MediaQuery.of(context).padding.bottom / 2 + 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Digite sua mensagem...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        onChanged: (text) => setState(() {}),
                        onSubmitted: (_) => (_controller.text.trim().isNotEmpty && !_isLoading) ? _sendMessage() : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    elevation: 1,
                    backgroundColor: _controller.text.trim().isEmpty || _isLoading ? Colors.grey : AppColors.primary,
                    onPressed: _controller.text.trim().isEmpty || _isLoading ? null : _sendMessage,
                    child: const Icon(Icons.send, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}