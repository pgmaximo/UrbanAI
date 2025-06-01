import 'package:flutter/material.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:urbanai/pages/MapPage.dart';
import 'package:urbanai/pages/configPage.dart';
import 'package:urbanai/services/scrape_service.dart';
import 'package:urbanai/services/analise_regional_service.dart';
import 'package:urbanai/services/user_services.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/scripts/secret.dart'; // Para apiKeySerpApi (ou onde quer que esteja)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = []; // Lista para a UI

  // Serviços
  final UserServices _userServices = UserServices();
  final AppServices _appServices = AppServices();
  final RegionAnalysisService _regionService =
      RegionAnalysisService(); // Instanciar
  final ScrapeService _scrapeService =
      ScrapeService(); // Instanciar com a chave da SerpApi

  bool _isLoading = false; // Feedback de carregamento geral
  String _loadingMessage = "Assistente digitando..."; // Mensagem de loading

  @override
  void initState() {
    super.initState();
    _carregarHistoricoDaUI();
  }

  Future<void> _carregarHistoricoDaUI() async {
    // Mantém a lógica de isLoading para o carregamento inicial do histórico
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
          // Para o histórico, precisamos de uma forma melhor de saber se era card ou texto.
          // Por agora, vamos processar com as funções de extração para tentar identificar.
          // Uma melhoria futura: salvar o tipo de mensagem 'isCard' e 'cardData' no Firebase.
          List<Map<String, dynamic>> cardsNoHistorico = _userServices
              .extractImovelCards(item['content']!);
          String textoDoHistorico = _userServices.removeCardJsonFromString(
            item['content']!,
          );

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

  // Função para exibir a resposta processada da IA (texto e/ou cards)
  void _exibirRespostaProcessada(Map<String, dynamic> respostaProcessada) {
    // Salva a parte textual da resposta da IA no histórico global
    // Apenas se houver texto e não for apenas um placeholder de card
    if (respostaProcessada['conteudo_texto'] != null &&
        (respostaProcessada['conteudo_texto'] as String).isNotEmpty &&
        (respostaProcessada['conteudo_texto'] as String) !=
            "[CARD DO IMÓVEL]") {
      _appServices.salvarMensagem(
        'assistant',
        respostaProcessada['conteudo_texto']!,
      );
    }

    // Se houver cards, também precisamos de uma representação textual para o histórico,
    // ou uma forma de salvar os cards de forma estruturada no histórico.
    // Por agora, a IA Final gera um texto que *inclui* os cards.
    // Se o texto principal já foi salvo, e os cards são parte dele (embutidos),
    // o AppServices já tem a mensagem completa.
    // Para a UI, adicionamos separadamente:

    if (!mounted) return;
    setState(() {
      // Adiciona a mensagem de texto principal da IA (já limpa dos JSONs brutos)
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

      // Adiciona os cards extraídos à UI
      if (respostaProcessada['imoveis'] != null &&
          (respostaProcessada['imoveis'] as List).isNotEmpty) {
        for (var imovelMap
            in (respostaProcessada['imoveis'] as List<dynamic>)) {
          // Antes de adicionar à UI, salva uma representação do card no histórico do AppServices.
          // Ex: "Card do imóvel: Nome do Imóvel" ou o JSON string do card.
          // Isso é importante se _carregarHistoricoDaUI precisar remontar os cards.
          // Por simplicidade, a IA Final já embutiu os cards na mensagem principal salva.
          // Se não, faríamos: _appServices.salvarMensagem('assistant', "##CARD_JSON_START##${jsonEncode(imovelMap)}##CARD_JSON_END##");
          _messages.add({
            "text":
                "", // O texto visual do card é construído pelo _buildMessage
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
      // Adiciona uma mensagem de feedback para o usuário
      _messages.add({
        "text": _loadingMessage,
        "isUser": false,
        "isCard": false,
      });
    });
    _scrollToBottom();

    try {
      // 1. Chamar RegionAnalysisService
      List<RegiaoSugerida>
      regioesSugeridas = await _regionService.analisarRegioesComScoreIA(
        criteriosGeraisUsuario: criterios,
        // Os parâmetros individuais são extraídos de 'criterios' dentro de analisarRegioesComScoreIA
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

      // Informa o usuário sobre as regiões encontradas antes de buscar imóveis
      String regioesTexto = regioesSugeridas
          .map((r) => r.nomeRegiao)
          .join(', ');
      setState(() {
        _loadingMessage =
            "Regiões promissoras encontradas: $regioesTexto. Buscando imóveis...";
        final ultimaMsgIndex =
            _messages.length - 1; // Atualiza a última mensagem de loading
        if (_messages[ultimaMsgIndex]["text"].toString().contains(
          "Analisando as melhores regiões",
        )) {
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

      // 2. Chamar ScrapeService (iterando sobre regioesSugeridas)
      List<Map<String, dynamic>> todosOsImoveisColetados = [];
      int numLinksPorRegiao =
          3; // Quantos links da SerpApi processar por região
      int maxImoveisPorRegiao =
          2; // Quantos imóveis tentar extrair com sucesso por região
      int totalImoveisDesejados = 3; // Máximo de imóveis para mostrar no total

      for (RegiaoSugerida regiao in regioesSugeridas) {
        if (todosOsImoveisColetados.length >= totalImoveisDesejados) break;

        String nomeCompletoRegiao =
            "${regiao.nomeRegiao}, ${regiao.cidadeRegiao}";

        // Construir query para SerpApi
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
              imoveisColetadosNestaRegiao >= maxImoveisPorRegiao)
            break;

          Map<String, dynamic>? dadosImovel = await _scrapeService
              .scrapeEDetalhaImovel(linkImovel);

          if (dadosImovel != null) {
            // POIs próximos ao IMÓVEL (já é feito dentro de scrapeEDetalhaImovel na última versão)
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
          if (_messages[ultimaMsgIndex]["text"].toString().contains(
            "Buscando imóveis",
          )) {
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
        if (_messages[ultimaMsgIndex]["text"].toString().contains(
          "Buscando imóveis",
        )) {
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

      // 3. Enviar os imóveis coletados para a IA Final no N8N para formatação
      final Map<String, dynamic> respostaFormatadaFinal = await _userServices
          .formatarRespostaFinalComIA(
            imoveisColetados: todosOsImoveisColetados,
            regioesSugeridas: regioesSugeridas.map((r) => r.toJson()).toList(),
          );

      // Remove a última mensagem de "loading" antes de adicionar a resposta final
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty &&
              _messages.last["text"].toString().contains(
                "Formatando as melhores opções",
              )) {
            _messages.removeLast();
          }
        });
      }
      _exibirRespostaProcessada(respostaFormatadaFinal);
    } catch (e, stackTrace) {
      print("Erro durante _processarAcaoDoCliente: $e\n$stackTrace");
      if (!mounted) return;
      // Remove a última mensagem de "loading"
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

    // Adiciona mensagem do usuário à UI e salva no histórico
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Inicia o loading geral
      _loadingMessage = "Assistente digitando..."; // Mensagem padrão de loading
      _messages.add({"text": text, "isUser": true, "isCard": false});
    });
    await _appServices.salvarMensagem('user', text);
    _controller.clear();
    _scrollToBottom();

    // Interação 1 com N8N: Obter critérios ou resposta conversacional
    final Map<String, dynamic> respostaN8NInteracao1 = await _userServices
        .enviarMensagemParaN8NInteracao1(text);

    if (!mounted) {
      setState(() => _isLoading = false);
      return;
    }
    // Verifica se o N8N pediu para o cliente agir (análise regional e scrape)
    // Verifica se o N8N pediu para o cliente agir
    if (respostaN8NInteracao1['action_tag'] ==
            'ANALYZE_REGIONS_AND_SCRAPE_LISTINGS' &&
        respostaN8NInteracao1['status'] == 'action_required_client' &&
        respostaN8NInteracao1['payload_criteria'] is Map) {
      // <--- ESTA CONDIÇÃO AGORA DEVE SER VERDADEIRA!
      // Chama a função que faz a análise e scrape no lado do cliente/backend auxiliar
      // Esta função é async mas não precisamos dar await aqui se o _isLoading já está true
      // e ela vai atualizar a UI internamente.
      _processarAcaoDoCliente(
        respostaN8NInteracao1['payload_criteria'] as Map<String, dynamic>,
      );
      // _isLoading será definido como false dentro de _processarAcaoDoCliente
    } else if (respostaN8NInteracao1['message'] != null) {
      // É uma resposta direta para exibir (conversacional, erro da Interação 1, ou cards se N8N mandou)
      _exibirRespostaProcessada(respostaN8NInteracao1);
      setState(() => _isLoading = false); // Termina o loading
    } else {
      // Formato completamente inesperado da Interação 1
      print(
        "HomePage: Formato de resposta N8N Interação 1 inesperado: $respostaN8NInteracao1",
      );
      _exibirRespostaProcessada(
        _userServices.formatoErroPadrao(
          "Recebi uma resposta inesperada do assistente.",
        ),
      );
      setState(() => _isLoading = false); // Termina o loading
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

  Widget _buildMessage(Map<String, dynamic> message) {
    // ... (Seu método _buildMessage atualizado, que já lida com 'isCard' e 'cardData') ...
    // Certifique-se que ele usa AppColors.chatBubbleUser, AppColors.chatBubbleAgent, etc.
    // como na sua versão anterior que você disse estar mais bonita.
    final isUser = message['isUser'] == true;
    final isCard = message['isCard'] == true;

    if (isCard) {
      final cardData = message['cardData'] as Map<String, dynamic>;
      // Seu widget Card aqui (como na sua versão anterior)
      return Align(/* ... Seu widget Card ... */);
    }

    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    // Use as cores do seu AppColors que você definiu no main.dart
    final bgColor = isUser ? AppColors.secondary : Colors.white70;
    final textColor =
        isUser
            ? Colors
                .white // Defina textUser
            : Colors.black87; // Defina textAgent

    // Se o texto da mensagem estiver vazio (pode acontecer se for um card placeholder no histórico mal carregado)
    // não renderiza a bolha de texto.
    if (message['text'] == null ||
        message['text'].toString().isEmpty && !isCard) {
      return const SizedBox.shrink(); // Não renderiza nada
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
        leading: IconButton(
          icon: const Icon(Icons.settings, color: AppColors.secondary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ConfigPage()),
            ).then((_) {
              if (mounted) {
                _carregarHistoricoDaUI(); // Recarrega histórico se algo mudou na ConfigPage
              }
            });
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _isLoading && _messages.isEmpty
                      ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder:
                            (context, index) => _buildMessage(_messages[index]),
                      ),
            ),
            if (_isLoading && _messages.isNotEmpty) // Indicador "digitando..."
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
            // Input field
            Container(
              decoration: BoxDecoration(
                color:
                    AppColors
                        .background, // Ou Theme.of(context).cardColor para contraste
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
              ), // Padding seguro inferior
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 120,
                      ), // Limita altura do campo de texto
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Digite sua mensagem...',
                          filled: true,
                          fillColor: Colors.white, // Ou uma cor de tema
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
                        onSubmitted:
                            (_) =>
                                (_controller.text.trim().isNotEmpty &&
                                        !_isLoading)
                                    ? _sendMessage()
                                    : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    elevation: 1,
                    backgroundColor:
                        _controller.text.trim().isEmpty || _isLoading
                            ? Colors.grey
                            : AppColors.primary, // Cor primária para o botão
                    onPressed:
                        _controller.text.trim().isEmpty || _isLoading
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
                          builder:
                              (context) =>
                                  MapPage(address: "Avenida Paulista, 1578, São Paulo"),
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
