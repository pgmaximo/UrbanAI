import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:urbanai/main.dart'; // Para AppColors
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
  final List<Map<String, dynamic>> _messages = []; // Lista para a UI
  final UserServices _userServices = UserServices();
  final AppServices _appServices = AppServices();
  bool _isLoading = false; // Para feedback de carregamento

  @override
  void initState() {
    super.initState();
    _carregarHistoricoDaUI();
  }

  Future<void> _carregarHistoricoDaUI() async {
    setState(() => _isLoading = true);
    // Carrega do Firebase através do AppServices
    await _appServices.carregarHistoricoDoFirebase();
    final historicoCache = _appServices.getHistoricoConversaCache();
    setState(() {
      _messages.clear();
      for (final item in historicoCache) {
        if (item['role'] == 'user') {
          _messages.add({"text": item['content']!, "isUser": true, "isCard": false});
        } else if (item['role'] == 'assistant') {
          // Aqui, precisaríamos de uma forma de saber se a mensagem do assistente era um card ou texto.
          // Por simplicidade, vamos assumir que tudo no histórico é texto por enquanto.
          // Uma solução mais robusta salvaria o tipo de mensagem no Firebase.
          _messages.add({"text": item['content']!, "isUser": false, "isCard": false});
        }
      }
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _messages.add({"text": text, "isUser": true, "isCard": false});
    });
    // Salva a mensagem do usuário no histórico (local e Firebase)
    await _appServices.salvarMensagem('user', text);
    _controller.clear();
    _scrollToBottom();

    final Map<String, dynamic> respostaCompletaIA = await _userServices.enviarMensagemIA(text);

    String mensagemPrincipal = "";
    List<dynamic> imoveisData = [];
    String perguntaFollowUp = "";

    if (respostaCompletaIA['tipo_resposta'] == 'erro') {
      mensagemPrincipal = respostaCompletaIA['conteudo_texto'] as String? ?? "Ocorreu um erro desconhecido.";
    } else {
      mensagemPrincipal = respostaCompletaIA['conteudo_texto'] as String? ?? "";
      imoveisData = respostaCompletaIA['imoveis'] as List<dynamic>? ?? [];
      perguntaFollowUp = respostaCompletaIA['pergunta_follow_up'] as String? ?? "";
    }

    String textoParaExibirNaBolhaDeChat = (mensagemPrincipal + (perguntaFollowUp.isNotEmpty ? " $perguntaFollowUp" : "")).trim();

    // Salva a resposta textual da IA (parte principal)
    if (textoParaExibirNaBolhaDeChat.isNotEmpty) {
      await _appServices.salvarMensagem('assistant', textoParaExibirNaBolhaDeChat);
       setState(() {
        _messages.add({"text": textoParaExibirNaBolhaDeChat, "isUser": false, "isCard": false});
      });
    }

    // Processa e adiciona os cards de imóveis, se houver
    if (imoveisData.isNotEmpty) {
      for (var imovelMap in imoveisData) {
        // Salva uma representação do card no histórico (opcional, ou apenas o texto)
        // String cardRepresentationForHistory = "Card do imóvel: ${imovelMap['nome']}";
        // await _appServices.salvarMensagem('assistant', cardRepresentationForHistory);

        setState(() {
          _messages.add({
            "text": "", // O texto virá do cardData
            "isUser": false,
            "isCard": true,
            "cardData": imovelMap as Map<String, dynamic> // Cast para tipo correto
          });
        });
      }
    }
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

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final isCard = message['isCard'] == true;

    if (isCard) {
      final cardData = message['cardData'] as Map<String, dynamic>;
      return Align(
        alignment: Alignment.centerLeft,
        child: Card(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cardData['nome']?.toString() ?? 'Nome não disponível',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)),
                const SizedBox(height: 6),
                if (cardData['imagem_url'] != null && cardData['imagem_url'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        cardData['imagem_url'].toString(),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                             height: 180,
                             width: double.infinity,
                             color: Colors.grey[300],
                             child: Center(
                               child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                               ),
                             ),
                          );
                        },
                      ),
                    ),
                  ),
                if (cardData['endereco'] != null)
                  Text('Endereço: ${cardData['endereco']}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                if (cardData['preco'] != null)
                  Text('Preço: ${cardData['preco']}', style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                if (cardData['quartos'] != null)
                  Text('Quartos: ${cardData['quartos']}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                if (cardData['area'] != null) Text('Área: ${cardData['area']}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                // Adicione mais campos e estilize conforme necessário
                // Ex: Botões de ação, mais detalhes, etc.
              ],
            ),
          ),
        ),
      );
    }

    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isUser ? AppColors.secondary // Verde escuro para usuário
                  : const Color(0xFFE9E9EB); // Um cinza claro para o agente
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
        title: Image.asset('asset/logos/logo_nome.png', height: 120), // Ajuste a altura
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: AppColors.secondary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ConfigPage()),
            ).then((_) { // Este callback é executado quando ConfigPage é "popada"
              // Garante que o widget ainda está no árvore antes de chamar setState ou métodos que o fazem.
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
              child: _isLoading && _messages.isEmpty // Mostra loading apenas se não houver mensagens
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessage(_messages[index]),
                    ),
            ),
            if (_isLoading && _messages.isNotEmpty) // Indicador sutil de "digitando"
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0, color: AppColors.secondary,)),
                    SizedBox(width: 8),
                    Text("Assistente digitando...", style: TextStyle(fontSize: 14, color: AppColors.secondary)),
                  ],
                ),
              ),
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        minLines: 1,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Digite sua mensagem...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
                          ),
                        ),
                        onChanged: (text) => setState(() {}), // Para habilitar/desabilitar botão de envio
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    mini: true,
                    elevation: 1,
                    backgroundColor: _controller.text.trim().isEmpty || _isLoading ? Colors.grey : AppColors.secondary,
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