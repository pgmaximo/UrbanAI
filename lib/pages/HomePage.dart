import 'package:flutter/material.dart';
import 'package:urbanai/main.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controlador para gerenciar o campo de entrada de texto
  final TextEditingController _controller = TextEditingController();
  
  // Lista que armazena as mensagens enviadas pelo usuário e as respostas da IA
  final List<Map<String, dynamic>> _messages = [];

  // Função para enviar a mensagem do usuário e gerar uma resposta da IA
  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        // Adiciona a mensagem do usuário à lista
        _messages.add({'text': _controller.text, 'isUser': true});
        
        // Simula uma resposta da IA
        _messages.add({'text': 'Aqui será a resposta da IA...', 'isUser': false});
      });
      
      // Limpa o campo de entrada após o envio
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: AppColors.tertiary), // Ícone de configurações à esquerda
          onPressed: () {
            // Implementar ação para abrir configurações
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: message['isUser']
                        ? BoxDecoration(
                            color: AppColors.secondary, // Mensagem do usuário dentro de um balão colorido
                            borderRadius: BorderRadius.circular(15),
                          )
                        : null, // Mensagem da IA sem balão, apenas texto solto
                    child: Text(
                      message['text'],
                      style: TextStyle(
                        color: message['isUser'] ? Colors.white : Colors.black87, // Cor do texto
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (value) => _sendMessage(), // Permite envio com Enter
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15), // Bordas arredondadas
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200], // Cor de fundo do campo de entrada
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Reduzindo o espaçamento interno
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Espaço entre o campo de texto e o botão de envio
                SizedBox(
                  width: 50, // Defina a largura desejada
                  height: 50, // Defina a altura desejada
                  child: FloatingActionButton(
                    backgroundColor: AppColors.tertiary, // Cor do botão de envio
                    onPressed: _sendMessage,
                    child: const Icon(Icons.send, color: Colors.white, size: 20), // Ícone menor
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
