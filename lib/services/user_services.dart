import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:urbanai/scripts/secret.dart'; // Importa a URL do N8N
import 'package:urbanai/services/app_services.dart'; // Para acessar o histórico
import 'package:flutter/foundation.dart'; // Para kDebugMode

/// Serviço simplificado para interagir com o backend único do N8N.
class UserServices {
  final AppServices _appServices = AppServices();
  // AGORA SÓ EXISTE UMA URL DE WEBHOOK
  final Uri _urlN8N = Uri.parse(apiKeyN8N); // Usando a primeira chave ou uma nova URL única

  /// Envia a mensagem do usuário e o histórico para o webhook do N8N.
  /// Lida com os dois tipos de resposta: pergunta de follow-up ou resultado final com card.
  Future<Map<String, dynamic>> enviarMensagem(String mensagemUsuario) async {
    final List<Map<String, String>> historicoConversa = _appServices.getHistoricoConversaCache();
    
    if (kDebugMode) {
      print("[UserSvc] Enviando para N8N: '$mensagemUsuario'");
      print("[UserSvc] URL: $_urlN8N");
    }

    try {
      final response = await http.post(
        _urlN8N,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'mensagem': mensagemUsuario, 'historico': historicoConversa}),
      ).timeout(const Duration(seconds: 90)); // Timeout maior para permitir o scraping

      if (kDebugMode) {
        print('[UserSvc] N8N Raw Response Status: ${response.statusCode}');
        print('[UserSvc] N8N Raw Response Body: ${response.body}');
      }

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> n8nResponse = jsonDecode(utf8.decode(response.bodyBytes));
        
        // A resposta do N8N sempre terá um campo 'message'.
        final String messageFromAI = n8nResponse['message'] as String? ?? "O assistente não enviou uma mensagem.";

        // Processa a mensagem para extrair texto e cards, se existirem.
        final List<Map<String, dynamic>> extractedImoveis = extractImovelCards(messageFromAI);
        final String mainTextContent = removeCardJsonFromString(messageFromAI);

        // Retorna um mapa padronizado para a HomePage.
        return {
          'tipo_resposta': extractedImoveis.isNotEmpty ? 'lista_imoveis' : 'texto_simples',
          'conteudo_texto': mainTextContent,
          'conteudo_original': messageFromAI, // Preserva a mensagem original para salvar no histórico
          'imoveis': extractedImoveis,
        };

      } else { 
        print('[UserSvc] Erro na comunicação com N8N. Status: ${response.statusCode}');
        return formatoErroPadrao("Falha na comunicação com o assistente (${response.statusCode}).");
      }
    } catch (e, stackTrace) { 
      print('[UserSvc] Exceção na requisição HTTP para N8N: $e\n$stackTrace');
      return formatoErroPadrao("Erro de conexão ao contatar o assistente. Verifique sua internet.");
    }
  }

  /// Cria um mapa de erro padronizado para ser exibido na UI.
  Map<String, dynamic> formatoErroPadrao(String mensagemErro) { 
    return {
      'tipo_resposta': 'erro', 
      'conteudo_texto': mensagemErro,
      'conteudo_original': mensagemErro,
      'imoveis': [],
    };
  }

  /// Extrai os JSONs de cards de imóveis de uma string, usando os marcadores ##CARD_JSON_...##.
  List<Map<String, dynamic>> extractImovelCards(String messageFromAI) { 
    final List<Map<String, dynamic>> cards = [];
    final RegExp cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##", dotAll: true);
    
    cardRegExp.allMatches(messageFromAI).forEach((match) {
      final String jsonString = match.group(1) ?? "";
      if (jsonString.isNotEmpty) {
        try {
          cards.add(jsonDecode(jsonString) as Map<String, dynamic>);
        } catch (e) {
          print("[UserSvc] Erro ao decodificar JSON de card embutido: $e");
        }
      }
    });
    return cards;
  }

  /// Remove os blocos de JSON de cards da string, deixando apenas o texto conversacional.
  String removeCardJsonFromString(String messageFromAI) { 
    final RegExp cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##\s*", dotAll: true);
    String cleanedMessage = messageFromAI.replaceAll(cardRegExp, "\n[CARD DO IMÓVEL]\n");
    return cleanedMessage.trim();
  }
}
