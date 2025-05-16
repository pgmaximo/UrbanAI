import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:urbanai/scripts/secret.dart';
import 'package:urbanai/services/app_services.dart';

class UserServices {
  static final UserServices _instance = UserServices._internal();
  factory UserServices() => _instance;
  UserServices._internal();

  final String _openAiUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = apiKeyOpenAI;

  static const _systemPrompt = '''
    Você é um assistente de inteligência artificial especializado em ajudar pessoas a encontrarem imóveis ideais na cidade de São Paulo. Seu papel é entender as necessidades dos usuários — como localização desejada, número de quartos, proximidade com metrô, escolas, segurança e outros critérios — e responder de forma amigável, clara e útil.

    Seu objetivo principal é tornar o processo de busca por imóveis mais rápido, eficiente e assertivo, sugerindo opções, dando dicas e tirando dúvidas relacionadas a imóveis residenciais. Esteja preparado para dialogar com usuários que estejam alugando ou comprando, mas nunca envolva questões bancárias ou de financiamento.

    Você não deve fornecer links ou efetuar compras. Use linguagem natural, empática e profissional, adaptando-se ao estilo do usuário. Quando apropriado, peça mais detalhes para melhorar a recomendação.

    Seu conhecimento é focado exclusivamente em imóveis da cidade de São Paulo, Brasil. Caso o usuário pergunte sobre outras cidades ou imóveis comerciais, informe gentilmente que o sistema está restrito à cidade de São Paulo e à busca residencial nesta fase do projeto.

    Você foi integrado em um aplicativo mobile desenvolvido com Flutter e Firebase, e responde às mensagens enviadas pelo usuário em tempo real como um bate-papo moderno. Responda com mensagens curtas, objetivas e úteis.
  ''';

  /// Envia a mensagem do usuário e retorna a resposta do assistant, mantendo o histórico.
  Future<String> enviarMensagemIA(String novaMensagem) async {
    final appServices = AppServices();

    // Garante que o system prompt esteja presente no histórico
    appServices.garantirSystemPrompt(_systemPrompt.trim());

    // Adiciona a nova mensagem do usuário ao histórico
    appServices.salvarMensagem('user', novaMensagem);

    final mensagens = appServices.getHistoricoConversa().map((msg) {
      return {
        'role': msg['role'],
        'content': msg['content'],
      };
    }).toList();

    try {
      final response = await http.post(
        Uri.parse(_openAiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4.1',
          'messages': mensagens,
          'temperature': 0.7,
          'top_p': 1.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final resposta = data['choices'][0]['message']['content']?.trim() ?? 'Resposta vazia da IA.';

        // Salva a resposta do assistant no histórico
        appServices.salvarMensagem('assistant', resposta);
        return resposta;
      } else {
        final error = jsonDecode(response.body);
        return 'Erro ${response.statusCode}: ${error['error']['message']}';
      }
    } catch (e) {
      return 'Erro na requisição: $e';
    }
  }
}
