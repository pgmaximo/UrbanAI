import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/MapPage.dart';
import 'package:urbanai/pages/configPage.dart';
import 'package:urbanai/pages/favoritosPage.dart';
import 'package:urbanai/services/scrape_service.dart';
import 'package:urbanai/services/analise_regional_service.dart';
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

  final UserServices _userServices = UserServices();
  final AppServices _appServices = AppServices();
  final RegionAnalysisService _regionService = RegionAnalysisService();
  final ScrapeService _scrapeService = ScrapeService();

  // --------- Drawer User Data ---------
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  UserData? _userDataDrawer;
  bool _isLoadingUserDataDrawer = true;
  String? _userDataDrawerError;

  // --------- Chat States -----------
  bool _isLoading = false;
  String _loadingMessage = "Assistente digitando...";

  @override
  void initState() {
    super.initState();
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
        UserData? firestoreData =
            await _firestoreService.getUserData(currentUser.uid);
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
        _userDataDrawerError = "Não foi possível carregar o usuário do Drawer.";
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
    setState(() => _isLoading = true);
    _loadingMessage = "Carregando histórico...";

    await _appServices.carregarHistoricoDoFirebase();
    final historicoCache = _appServices.getHistoricoConversaCache();

    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (final item in historicoCache) {
        if (item['role'] == 'user') {
          _messages.add({
            "text": item['content']!,
            "isUser": true,
            "isCard": false,
          });
        } else if (item['role'] == 'assistant') {
          List<Map<String, dynamic>> cardsNoHistorico =
              _userServices.extractImovelCards(item['content']!);
          String textoDoHistorico =
              _userServices.removeCardJsonFromString(item['content']!);

          if (textoDoHistorico.isNotEmpty &&
              textoDoHistorico != "[CARD DO IMÓVEL]") {
            _messages.add({
              "text": textoDoHistorico,
              "isUser": false,
              "isCard": false,
            });
          }
          for (var card in cardsNoHistorico) {
            _messages.add({
              "text": "",
              "isUser": false,
              "isCard": true,
              "cardData": card,
            });
          }
        }
      }
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _exibirRespostaProcessada(Map<String, dynamic> respostaProcessada) {
    if (respostaProcessada['conteudo_texto'] != null &&
        (respostaProcessada['conteudo_texto'] as String).isNotEmpty &&
        (respostaProcessada['conteudo_texto'] as String) !=
            "[CARD DO IMÓVEL]") {
      _appServices.salvarMensagem(
        'assistant',
        respostaProcessada['conteudo_texto']!,
      );
    }

    if (!mounted) return;
    setState(() {
      if (respostaProcessada['conteudo_texto'] != null &&
          (respostaProcessada['conteudo_texto'] as String).isNotEmpty &&
          (respostaProcessada['conteudo_texto'] as String) !=
              "[CARD DO IMÓVEL]") {
        _messages.add({
          "text": respostaProcessada['conteudo_texto']!,
          "isUser": false,
          "isCard": false,
        });
      }

      if (respostaProcessada['imoveis'] != null &&
          (respostaProcessada['imoveis'] as List).isNotEmpty) {
        for (var imovelMap in (respostaProcessada['imoveis'] as List<dynamic>)) {
          _messages.add({
            "text": "",
            "isUser": false,
            "isCard": true,
            "cardData": imovelMap as Map<String, dynamic>,
          });
        }
      }
    });
    _scrollToBottom();
  }

  Future<void> _processarAcaoDoCliente(Map<String, dynamic> criterios) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = "Analisando as melhores regiões para você...";
      _messages.add({
        "text": _loadingMessage,
        "isUser": false,
        "isCard": false,
      });
    });
    _scrollToBottom();

    try {
      List<RegiaoSugerida> regioesSugeridas =
          await _regionService.analisarRegioesComScoreIA(
        criteriosGeraisUsuario: criterios,
      );

      if (!mounted) return;
      if (regioesSugeridas.isEmpty) {
        setState(() {
          _messages.add({
            "text":
                "Não consegui encontrar regiões adequadas com os critérios atuais. Que tal tentarmos outros?",
            "isUser": false,
            "isCard": false,
          });
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      String regioesTexto = regioesSugeridas.map((r) => r.nomeRegiao).join(', ');
      setState(() {
        _loadingMessage =
            "Regiões promissoras encontradas: $regioesTexto. Buscando imóveis...";
        final ultimaMsgIndex = _messages.length - 1;
        if (_messages[ultimaMsgIndex]["text"]
            .toString()
            .contains("Analisando as melhores regiões")) {
          _messages[ultimaMsgIndex] = {
            "text": _loadingMessage,
            "isUser": false,
            "isCard": false,
          };
        } else {
          _messages.add({
            "text": _loadingMessage,
            "isUser": false,
            "isCard": false,
          });
        }
      });
      _scrollToBottom();

      List<Map<String, dynamic>> todosOsImoveisColetados = [];
      int numLinksPorRegiao = 3;
      int maxImoveisPorRegiao = 2;
      int totalImoveisDesejados = 3;

      for (RegiaoSugerida regiao in regioesSugeridas) {
        if (todosOsImoveisColetados.length >= totalImoveisDesejados) break;

        String nomeCompletoRegiao =
            "${regiao.nomeRegiao}, ${regiao.cidadeRegiao}";

        String querySerpApi = _scrapeService.construirQuerySerpApi(
          templateQuery:
              criterios['template_query_serpapi'] as String? ??
                  "{REGIAO_PLACEHOLDER} {TIPO_IMOVEL_PLACEHOLDER} {OBJETIVO_PLACEHOLDER}",
          nomeRegiaoSugerida: nomeCompletoRegiao,
          criteriosIA1: criterios,
        );

        List<String> linksImoveis = await _scrapeService.getGoogleLinks(
          querySerpApi,
          numResults: numLinksPorRegiao,
        );

        int imoveisColetadosNestaRegiao = 0;
        for (String linkImovel in linksImoveis) {
          if (todosOsImoveisColetados.length >= totalImoveisDesejados ||
              imoveisColetadosNestaRegiao >= maxImoveisPorRegiao) break;

          Map<String, dynamic>? dadosImovel =
              await _scrapeService.scrapeEDetalhaImovel(linkImovel);

          if (dadosImovel != null) {
            todosOsImoveisColetados.add(dadosImovel);
            imoveisColetadosNestaRegiao++;
          }
        }
      }

      if (!mounted) return;
      if (todosOsImoveisColetados.isEmpty) {
        setState(() {
          _loadingMessage =
              "Encontrei algumas regiões interessantes, mas não consegui listar imóveis específicos no momento. Poderia tentar refinar sua busca?";
          final ultimaMsgIndex = _messages.length - 1;
          if (_messages[ultimaMsgIndex]["text"]
              .toString()
              .contains("Buscando imóveis")) {
            _messages[ultimaMsgIndex] = {
              "text": _loadingMessage,
              "isUser": false,
              "isCard": false,
            };
          } else {
            _messages.add({
              "text": _loadingMessage,
              "isUser": false,
              "isCard": false,
            });
          }
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      }

      setState(() {
        _loadingMessage = "Formatando as melhores opções para você...";
        final ultimaMsgIndex = _messages.length - 1;
        if (_messages[ultimaMsgIndex]["text"]
            .toString()
            .contains("Buscando imóveis")) {
          _messages[ultimaMsgIndex] = {
            "text": _loadingMessage,
            "isUser": false,
            "isCard": false,
          };
        } else {
          _messages.add({
            "text": _loadingMessage,
            "isUser": false,
            "isCard": false,
          });
        }
      });
      _scrollToBottom();

      final Map<String, dynamic> respostaFormatadaFinal =
          await _userServices.formatarRespostaFinalComIA(
        imoveisColetados: todosOsImoveisColetados,
        regioesSugeridas: regioesSugeridas.map((r) => r.toJson()).toList(),
      );

      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty &&
              _messages.last["text"]
                  .toString()
                  .contains("Formatando as melhores opções")) {
            _messages.removeLast();
          }
        });
      }
      _exibirRespostaProcessada(respostaFormatadaFinal);
    } catch (e, stackTrace) {
      print("Erro durante _processarAcaoDoCliente: $e\n$stackTrace");
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty &&
                _messages.last["text"].toString().contains("Analisando") ||
            _messages.last["text"].toString().contains("Buscando") ||
            _messages.last["text"].toString().contains("Formatando")) {
          _messages.removeLast();
        }
      });
      _exibirRespostaProcessada(
        _userServices.formatoErroPadrao(
          "Ocorreu um problema durante a busca detalhada de imóveis. Tente novamente ou com outros critérios.",
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendMessage() async {
  final text = _controller.text.trim();
  if (text.isEmpty || _isLoading) return;

  // Comando especial para teste: adiciona um card de imóvel manualmente
  if (text == 'teste_card') {
    setState(() {
      _messages.add({
        'isUser': false,
        'isCard': true,
        'cardData': {'nome': 'Imóvel Teste do Chat'},
      });
    });
    _controller.clear();
    _scrollToBottom();
    return;
  }

  // --- código normal da função ---
  if (!mounted) return;
  setState(() {
    _isLoading = true;
    _loadingMessage = "Assistente digitando...";
    _messages.add({"text": text, "isUser": true, "isCard": false});
  });
  await _appServices.salvarMensagem('user', text);
  _controller.clear();
  _scrollToBottom();

  final Map<String, dynamic> respostaN8NInteracao1 =
      await _userServices.enviarMensagemParaN8NInteracao1(text);

  if (!mounted) {
    setState(() => _isLoading = false);
    return;
  }

  if (respostaN8NInteracao1['action_tag'] ==
          'ANALYZE_REGIONS_AND_SCRAPE_LISTINGS' &&
      respostaN8NInteracao1['status'] == 'action_required_client' &&
      respostaN8NInteracao1['payload_criteria'] is Map) {
    _processarAcaoDoCliente(
      respostaN8NInteracao1['payload_criteria'] as Map<String, dynamic>,
    );
  } else if (respostaN8NInteracao1['message'] != null) {
    _exibirRespostaProcessada(respostaN8NInteracao1);
    setState(() => _isLoading = false);
  } else {
    print(
        "HomePage: Formato de resposta N8N Interação 1 inesperado: $respostaN8NInteracao1");
    _exibirRespostaProcessada(
      _userServices.formatoErroPadrao(
        "Recebi uma resposta inesperada do assistente.",
      ),
    );
    setState(() => _isLoading = false);
  }
}


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -------------------- CARD DE IMÓVEL COM FAVORITAR --------------------
  Widget _buildImovelCard(Map<String, dynamic> cardData) {
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

    if (message['text'] == null ||
        message['text'].toString().isEmpty && !isCard) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(
          message['text'].toString(),
          style: TextStyle(fontSize: 16, color: textColor, height: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                              : const AssetImage(
                                      "asset/avatar/default_avatar.jpg")
                                  as ImageProvider,
                          backgroundColor: Colors.white,
                        ),
                        accountName: Text(
                          _userDataDrawer?.displayName ?? "Usuário",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
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
              onTap: () 
              {Navigator.pop(context);
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
                      itemBuilder: (context, index) =>
                          _buildMessage(_messages[index]),
                    ),
            ),
            if (_isLoading && _messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
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
                        onSubmitted: (_) =>
                            (_controller.text.trim().isNotEmpty && !_isLoading)
                                ? _sendMessage()
                                : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    elevation: 1,
                    backgroundColor: _controller.text.trim().isEmpty || _isLoading
                        ? Colors.grey
                        : AppColors.primary,
                    onPressed: _controller.text.trim().isEmpty || _isLoading
                        ? null
                        : _sendMessage,
                    child: const Icon(
                      Icons.send,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPage(
                              address: "Avenida Paulista, 1578, São Paulo"),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Ver Endereço no Mapa'),
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
  State<_ImovelCard> createState() => _ImovelCardState();
}

class _ImovelCardState extends State<_ImovelCard> {
  bool _favoritado = false;

  Future<void> _adicionarAosFavoritos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('Favoritos')
          .add({'nome': widget.cardData['nome']});

      setState(() {
        _favoritado = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imóvel adicionado aos favoritos!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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
        trailing: IconButton(
          icon: Icon(
            _favoritado ? Icons.favorite : Icons.favorite_border,
            color: _favoritado ? Colors.red : Colors.grey,
          ),
          onPressed: _favoritado ? null : _adicionarAosFavoritos,
          tooltip: 'Favoritar',
        ),
      ),
    );
  }
}
