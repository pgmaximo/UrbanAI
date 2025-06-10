import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';
import 'package:urbanai/pages/configPage.dart';
import 'package:urbanai/services/user_services.dart';
import 'package:urbanai/services/app_services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  // Serviços simplificados
  final UserServices _userServices = UserServices();
  final AppServices _appServices = AppServices();

  bool _isLoading = false;
  String _loadingMessage = "Assistente digitando...";

  @override
  void initState() {
    super.initState();
    // Adiciona o listener para atualizar o estado do botão de enviar
    _controller.addListener(() {
      setState(() {});
    });
    _carregarHistoricoDaUI();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Carrega o histórico de conversas do Firebase e atualiza a UI.
  Future<void> _carregarHistoricoDaUI() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = "Carregando histórico...";
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
          // A lógica para processar mensagens do histórico permanece a mesma
          List<Map<String, dynamic>> cardsNoHistorico = _userServices.extractImovelCards(item['content']!);
          String textoDoHistorico = _userServices.removeCardJsonFromString(item['content']!);

          if (textoDoHistorico.isNotEmpty && textoDoHistorico != "[CARD DO IMÓVEL]") {
             _messages.add({"text": textoDoHistorico, "isUser": false, "isCard": false});
          }
          for (var card in cardsNoHistorico) {
            _messages.add({"text": "", "isUser": false, "isCard": true, "cardData": card});
          }
        }
      }
      _isLoading = false;
    });
    _scrollToBottom();
  }

  /// Exibe a resposta da IA, separando o texto dos cards.
  void _exibirRespostaProcessada(Map<String, dynamic> respostaProcessada) {
    // Salva a resposta completa (com cards embutidos) no histórico
    // Usa 'conteudo_original' que foi adicionado em user_services
    final conteudoOriginal = respostaProcessada['conteudo_original'] as String?;
    if (conteudoOriginal != null) {
      _appServices.salvarMensagem('assistant', conteudoOriginal);
    }
    
    if (!mounted) return;
    setState(() {
      // Adiciona a mensagem de texto (já limpa)
      final texto = respostaProcessada['conteudo_texto'] as String?;
      if (texto != null && texto.isNotEmpty && texto != "[CARD DO IMÓVEL]") {
        _messages.add({"text": texto, "isUser": false, "isCard": false});
      }

      // Adiciona os cards extraídos
      final imoveis = respostaProcessada['imoveis'] as List<dynamic>?;
      if (imoveis != null && imoveis.isNotEmpty) {
        for (var imovelMap in imoveis) {
          _messages.add({
            "text": "", 
            "isUser": false,
            "isCard": true,
            "cardData": imovelMap as Map<String, dynamic>
          });
        }
      }
    });
    _scrollToBottom();
  }

  // REMOVIDO: O método _processarAcaoDoCliente não é mais necessário.

  /// Envia a mensagem do usuário para o N8N e lida com a resposta.
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = "Assistente pensando...";
      _messages.add({"text": text, "isUser": true, "isCard": false});
    });
    await _appServices.salvarMensagem('user', text);
    _controller.clear();
    _scrollToBottom();

    try {
      // Chama o único método de serviço
      final Map<String, dynamic> respostaN8N = await _userServices.enviarMensagem(text);

      if (!mounted) return;
      
      // A resposta é sempre processada da mesma forma
      _exibirRespostaProcessada(respostaN8N);

    } catch(e) {
      if (kDebugMode) print("HomePage: Erro ao chamar _sendMessage: $e");
      _exibirRespostaProcessada(_userServices.formatoErroPadrao("Ocorreu um erro. Tente novamente."));
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final isCard = message['isCard'] == true;

    if (isCard) {
      final cardData = message['cardData'] as Map<String, dynamic>;
      // TODO: Construir um widget de Card bonito para o imóvel.
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (cardData['imagem_url'] != null)
                  Image.network(
                    cardData['imagem_url'], 
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.house, color: AppColors.primary, size: 50),
                  ),
                SizedBox(height: 8),
                Text(cardData['titulo'] ?? 'Título indisponível', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text(cardData['endereco'] ?? 'Endereço indisponível', style: TextStyle(color: Colors.grey.shade700)),
                 SizedBox(height: 8),
                Text(cardData['descricao'] ?? ''),
            ],
          ),
        ),
      );
    }

    if (message['text'] == null || message['text'].toString().isEmpty) {
        return const SizedBox.shrink();
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: Offset(0, 1))]
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.settings, color: AppColors.secondary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ConfigPage()),
            ).then((_) {
              if (mounted) {
                _carregarHistoricoDaUI();
              }
            });
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
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
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.secondary)),
                    const SizedBox(width: 8),
                    Text(_loadingMessage, style: const TextStyle(fontSize: 14, color: AppColors.secondary)),
                  ],
                ),
              ),
            // Input field
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [BoxShadow(offset: const Offset(0, -2), blurRadius: 4, color: Colors.black.withOpacity(0.05))]
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => (_controller.text.trim().isNotEmpty && !_isLoading) ? _sendMessage() : null,
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
