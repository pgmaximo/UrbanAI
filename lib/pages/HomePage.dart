import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/MapPage.dart';
import 'package:urbanai/pages/configPage.dart';
import 'package:urbanai/pages/favoritosPage.dart';
// REMOVIDO: Estes serviços não são mais necessários diretamente na HomePage
// import 'package:urbanai/services/scrape_service.dart';
// import 'package:urbanai/services/analise_regional_service.dart';
import 'package:urbanai/services/user_services.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urbanai/services/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  // ATUALIZADO: Serviços necessários foram simplificados
  final UserServices _userServices = UserServices();
  final AppServices _appServices = AppServices();
  // REMOVIDO: Não precisamos mais desses serviços aqui
  // final RegionAnalysisService _regionService = RegionAnalysisService();
  // final ScrapeService _scrapeService = ScrapeService();

  // --------- Drawer User Data ---------
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserData? _userDataDrawer;
  bool _isLoadingUserDataDrawer = true;
  String? _userDataDrawerError;

  // --------- Chat States -----------
  bool _isLoading = false;
  // ATUALIZADO: Mensagem de loading agora é única e mais simples
  final String _loadingMessage = "Assistente está digitando...";

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    
    // ATUALIZADO: Define o ID da conversa com base no UID do usuário logado
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
        if (firestoreData != null) {
          _userDataDrawer = firestoreData;
        } else {
          _userDataDrawer = UserData(
            uid: currentUser.uid,
            email: currentUser.email ?? 'Email não disponível',
            nome: currentUser.displayName,
            photoURL: currentUser.photoURL,
          );
        }
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
      // _loadingMessage = "Carregando histórico..."; // Não precisa mais
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
          // A lógica de extrair cards do histórico continua válida e importante
          _exibirRespostaNaUI(item['content']!);
        }
      }
      _isLoading = false;
    });
    _scrollToBottom();
  }

  /// ATUALIZADO: Função renomeada e simplificada para apenas exibir dados na UI.
  /// Recebe a mensagem *original* do assistente e a processa para exibição.
  void _exibirRespostaNaUI(String mensagemOriginal) {
    List<Map<String, dynamic>> cards = _userServices.extractImovelCards(mensagemOriginal);
    String texto = _userServices.removeCardJsonFromString(mensagemOriginal);

    if (!mounted) return;
    
    setState(() {
      // Adiciona a parte de texto da mensagem, se houver
      if (texto.isNotEmpty && texto != "[CARD DO IMÓVEL]") {
        _messages.add({"text": texto, "isUser": false, "isCard": false});
      }

      // Adiciona os cards de imóveis, se houver
      for (var cardData in cards) {
        _messages.add({"text": "", "isUser": false, "isCard": true, "cardData": cardData});
      }
    });

    _scrollToBottom();
  }


  // REMOVIDO: Toda esta função é obsoleta, pois a lógica agora está no N8N.
  // Future<void> _processarAcaoDoCliente(Map<String, dynamic> criterios) async { ... }


  /// ### FUNÇÃO PRINCIPAL ATUALIZADA ###
  /// Lógica de envio de mensagem drasticamente simplificada.
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 1. Atualiza a UI com a mensagem do usuário
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _messages.add({"text": text, "isUser": true, "isCard": false});
    });
    _controller.clear();
    _scrollToBottom();

    // 2. Salva a mensagem do usuário no histórico do Firebase
    await _appServices.salvarMensagem('user', text);

    // 3. Envia a mensagem para o serviço e aguarda a resposta final
    final Map<String, dynamic> respostaN8N = await _userServices.enviarMensagem(text);

    if (!mounted) {
      setState(() => _isLoading = false);
      return;
    }

    // 4. Salva a resposta COMPLETA do assistente no histórico do Firebase
    // Usamos 'conteudo_original' que contém o texto e os marcadores de card
    final String conteudoOriginalAssistente = respostaN8N['conteudo_original'] ?? '';
    if (conteudoOriginalAssistente.isNotEmpty) {
      await _appServices.salvarMensagem('assistant', conteudoOriginalAssistente);
    }
    
    // 5. Exibe a resposta processada (texto e/ou cards) na UI
    // A função _exibirRespostaNaUI vai separar o texto dos cards para nós
    if (respostaN8N['tipo_resposta'] != 'erro') {
      _exibirRespostaNaUI(conteudoOriginalAssistente);
    } else {
      // Exibe a mensagem de erro formatada
       _messages.add({
         "text": respostaN8N['conteudo_texto'], 
         "isUser": false, 
         "isCard": false
        });
    }

    // 6. Finaliza o carregamento
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // O resto do arquivo (widgets de build, drawer, etc.) permanece o mesmo.
  // ... cole o resto do seu arquivo original a partir daqui ...
  // (Widget _buildImovelCard, Widget _buildMessage, Widget build(BuildContext context), etc.)


  // -------------------- CARD DE IMÓVEL COM FAVORITAR --------------------
  Widget _buildImovelCard(Map<String, dynamic> cardData) {
    // IMPORTANTE: Adicionei uma verificação de UID para evitar crash
    String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      // Não mostra o card se o usuário não estiver logado, pois não pode favoritar
      return const SizedBox.shrink();
    }
    return _ImovelCard(cardData: cardData);
  }

  // -------------------- MENSAGEM CHAT --------------------
  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final isCard = message['isCard'] == true;

    if (isCard) {
      final cardData = message['cardData'] as Map<String, dynamic>;
      return _buildImovelCard(cardData);
    }

    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isUser ? AppColors.secondary : Colors.white70;
    final textColor = isUser ? Colors.white : Colors.black87;

    if (message['text'] == null || message['text'].toString().isEmpty && !isCard) {
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
                  if (mounted) _carregarHistoricoDaUI();
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
              child: _isLoading && _messages.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
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
                      constraints: const BoxConstraints(
                        maxHeight: 120,
                      ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
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
                    child: const Icon(
                      Icons.send,
                      size: 20,
                      color: Colors.white,
                    ),
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

// ================== Card Widget ==================

class _ImovelCard extends StatefulWidget {
  final Map<String, dynamic> cardData;
  const _ImovelCard({Key? key, required this.cardData}) : super(key: key);

  @override
  State<_ImovelCard> createState() => __ImovelCardState();
}

class __ImovelCardState extends State<_ImovelCard> {
  bool _favoritado = false;
  // TODO: Adicionar lógica para verificar se o imóvel já é favorito ao construir o widget.

  Future<void> _adicionarAosFavoritos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para favoritar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Usando o link do imóvel como ID para evitar duplicatas, se disponível
      final docId = widget.cardData['link'] != null ? Uri.parse(widget.cardData['link']).host + Uri.parse(widget.cardData['link']).path : widget.cardData['nome'];

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('Favoritos')
          .doc(docId.replaceAll('/', '_')) // Firestore não aceita '/' em IDs
          .set(widget.cardData); // Usando .set() para criar ou sobrescrever

      if (!mounted) return;
      setState(() => _favoritado = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imóvel adicionado aos favoritos!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
       if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao favoritar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(
          widget.cardData['nome'] ?? 'Imóvel sem nome',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(widget.cardData['link'] ?? 'Link não disponível', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: Icon(
            _favoritado ? Icons.favorite : Icons.favorite_border,
            color: _favoritado ? Colors.red : Colors.grey,
          ),
          onPressed: _favoritado ? null : _adicionarAosFavoritos,
          tooltip: 'Favoritar',
        ),
        onTap: () {
            // Adicionando um botão para o mapa no card
            if (widget.cardData['endereco'] != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MapPage(address: widget.cardData['endereco'])));
            }
        },
      ),
    );
  }
}