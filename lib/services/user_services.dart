import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import 'package:urbanai/scripts/secret.dart'; 
import 'package:urbanai/services/app_services.dart';
import 'package:flutter/foundation.dart';

// Classe responsável por se comunicar com a IA no N8N
class UserServices {
  // Cria uma instância de AppServices para poder pegar o histórico de mensagens
  final AppServices _appServices = AppServices();

  // Função principal que envia a mensagem do usuário para a IA e recebe a resposta
  // Retorna um Future<Map<String, dynamic>>, que é um mapa com os dados da resposta da IA
  Future<Map<String, dynamic>> enviarMensagemIA(String mensagem) async {
    // Pega o histórico de conversas armazenado no AppServices
    final List<Map<String, String>> historicoConversa = _appServices.getHistoricoConversaCache();

    // Pega a URL do N8N do arquivo secret.dart e a transforma em um objeto Uri
    final Uri url = Uri.parse(apiKeyN8N); // apiKeyN8N vem do seu arquivo secret.dart

    // Tenta fazer a chamada para a API. Se algo der errado (ex: sem internet), o catch lida com o erro.
    try {
      // Faz a chamada HTTP do tipo POST para a URL do N8N
      // 'await' faz o código esperar pela resposta da API antes de continuar
      final response = await http.post(
        url, // URL da API N8N
        headers: const {'Content-Type': 'application/json'}, // Avisa a API que estamos enviando JSON
        // Corpo da requisição: envia a mensagem atual e o histórico como um JSON string
        body: jsonEncode({'mensagem': mensagem, 'historico': historicoConversa}),
      );

      // Se o app estiver em modo de desenvolvimento (debug), mostra informações da resposta no console
      if (kDebugMode) {
        print('N8N Status Code: ${response.statusCode}'); // Ex: 200 significa OK
        print('N8N Response Body: ${response.body}');    // O que a API respondeu (o JSON como texto)
      }

      // Verifica se a chamada foi bem-sucedida (código 200) e se a resposta não está vazia
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        // Tenta processar a resposta JSON. Se o JSON estiver malformado, o catch lida com o erro.
        try {
          // Converte a resposta (que é um JSON string) para um Map (um objeto chave-valor)
          final Map<String, dynamic> n8nResponse = jsonDecode(response.body) as Map<String, dynamic>;

          // Pega os campos 'status' e 'message' da resposta do N8N
          final String? statusN8N = n8nResponse['status'] as String?;
          final String? messageFromAI = n8nResponse['message'] as String?;

          // Se o status da resposta do N8N for 'success' e a mensagem da IA existir
          if (statusN8N == 'success' && messageFromAI != null) {
            // Tenta extrair 'cards' de imóveis que podem estar embutidos na mensagem da IA
            List<Map<String, dynamic>> extractedImoveis = _extractImovelCards(messageFromAI);
            // Remove os JSONs dos cards da mensagem principal para ter um texto 'limpo'
            String mainTextContent = _removeCardJsonFromString(messageFromAI);

            // Retorna um Map formatado para a tela do chat (HomePage)
            return {
              'tipo_resposta': extractedImoveis.isNotEmpty ? 'lista_imoveis' : 'texto_simples', // Se tem imóveis, é 'lista_imoveis'
              'conteudo_texto': mainTextContent, // Texto principal da IA
              'imoveis': extractedImoveis,        // Lista de imóveis (cards)
              'pergunta_follow_up': '',           // Espaço para futuras perguntas de continuação
            };
          } else {
            // Se o status do N8N não for 'success' ou a mensagem da IA estiver faltando
            print("Resposta do N8N não foi 'success' ou mensagem está vazia: $n8nResponse");
            return { // Retorna um objeto de erro padronizado
              'tipo_resposta': 'erro',
              'conteudo_texto': messageFromAI ?? 'O assistente retornou uma resposta inesperada.',
              'imoveis': [],
              'pergunta_follow_up': '',
            };
          }
        } catch (e) {
          // Se deu erro ao tentar ler o JSON da resposta do N8N
          print("Erro ao decodificar JSON da resposta do N8N ou processar 'message': ${response.body} \nExceção: $e");
          return { // Retorna um objeto de erro padronizado
            'tipo_resposta': 'erro',
            'conteudo_texto': 'Desculpe, tive um problema ao processar a resposta do servidor. (ERR_PARSE)',
            'imoveis': [],
            'pergunta_follow_up': ''
          };
        }
      } else {
        // Se a chamada HTTP para o N8N não teve sucesso (ex: erro 404, 500)
        print('Erro na comunicação com o assistente. Status: ${response.statusCode}, body: ${response.body}');
        return { // Retorna um objeto de erro padronizado
          'tipo_resposta': 'erro',
          'conteudo_texto': 'Desculpe, não consegui me comunicar com o assistente (${response.statusCode}). Tente novamente.',
          'imoveis': [],
          'pergunta_follow_up': ''
        };
      }
    } catch (e) {
      // Se deu erro na chamada HTTP em si (ex: sem internet, URL errada)
      print('Erro na requisição HTTP para N8N: $e');
      return { // Retorna um objeto de erro padronizado
        'tipo_resposta': 'erro',
        'conteudo_texto': 'Parece que você está sem conexão ou o serviço está indisponível. Por favor, verifique e tente novamente. (ERR_HTTP)',
        'imoveis': [],
        'pergunta_follow_up': ''
      };
    }
  }

  // Função para encontrar e extrair JSONs de cards que estão embutidos na mensagem da IA
  List<Map<String, dynamic>> _extractImovelCards(String messageFromAI) {
    final List<Map<String, dynamic>> cards = []; // Lista para guardar os cards encontrados
    // Expressão regular para achar texto entre ##CARD_JSON_START## e ##CARD_JSON_END##
    final RegExp cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##", dotAll: true);
    // Procura todas as ocorrências na mensagem
    Iterable<RegExpMatch> matches = cardRegExp.allMatches(messageFromAI);

    // Para cada ocorrência encontrada
    for (final match in matches) {
      final String jsonString = match.group(1) ?? ""; // Pega o texto do JSON (que está entre os marcadores)
      if (jsonString.isNotEmpty) { // Se achou algum texto de JSON
        try {
          // Tenta converter o texto do JSON para um Map (objeto)
          final Map<String, dynamic> cardData = jsonDecode(jsonString) as Map<String, dynamic>;
          cards.add(cardData); // Adiciona o card na lista
        } catch (e) {
          // Se o JSON estiver malformatado, mostra um erro no console mas não quebra o app
          print("Erro ao decodificar JSON de card embutido: $jsonString \nExceção: $e");
        }
      }
    }
    // Se estiver em modo de desenvolvimento, mostra os cards que foram extraídos
    if (kDebugMode) {
      print("Cards extraídos: $cards");
    }
    return cards; // Retorna a lista de cards (pode estar vazia)
  }

  String _removeCardJsonFromString(String messageFromAI) {
    // RegExp para encontrar os cards e seus marcadores
    final RegExp cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##", dotAll: true);
    
    // 1. Remove os blocos de JSON dos cards (incluindo os marcadores) da mensagem
    String cleanedMessage = messageFromAI.replaceAll(cardRegExp, "");

    // 2. Lidar com espaços e preservar novas linhas:
    //    Primeiro, dividimos a mensagem em linhas individuais usando '\n' como delimitador.
    List<String> lines = cleanedMessage.split('\n');
    
    //    Para cada linha:
    //    - Removemos espaços e tabs múltiplos, substituindo-os por um único espaço.
    //    - Usamos trim() para remover espaços/tabs no início e no fim de CADA LINHA.
    for (int i = 0; i < lines.length; i++) {
      lines[i] = lines[i].replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    }
    
    // 3. Juntamos as linhas novamente com '\n'.
    //    Isso preserva as quebras de linha originais (incluindo linhas em branco se elas
    //    resultarem de "\n\n" após o trim de linhas vazias).
    cleanedMessage = lines.join('\n');

    // 4. Um trim() final na mensagem completa para remover quaisquer \n no início ou fim de toda a mensagem.
    cleanedMessage = cleanedMessage.trim();

    if (kDebugMode) {
      print("Mensagem limpa (sem JSONs de cards, newlines preservadas): '$cleanedMessage'");
    }
    return cleanedMessage;
  }
}