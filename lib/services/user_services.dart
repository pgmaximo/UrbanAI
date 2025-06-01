import 'dart:convert'; // Para jsonEncode e jsonDecode
import 'package:http/http.dart' as http; // Para chamadas HTTP
import 'package:urbanai/scripts/secret.dart'; // Importa as URLs do N8N
import 'package:urbanai/services/app_services.dart'; // Para acessar o histórico de conversas
import 'package:flutter/foundation.dart'; // Para kDebugMode (logs de desenvolvimento)

class UserServices {
  final AppServices _appServices = AppServices();
  final Uri _urlN8NInteracao1 = Uri.parse(apiKeyN8N1); // Do seu secret.dart
  final Uri _urlN8NInteracao2 = Uri.parse(apiKeyN8N2); // Do seu secret.dart

  Future<Map<String, dynamic>> enviarMensagemParaN8NInteracao1(String mensagemUsuario) async {
    final List<Map<String, String>> historicoConversa = _appServices.getHistoricoConversaCache();
    
    if (kDebugMode) {
      print("UserServices: Enviando para N8N - Interação 1");
      print("URL: $_urlN8NInteracao1");
      print("Mensagem: $mensagemUsuario");
    }

    try {
      final response = await http.post(
        _urlN8NInteracao1,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'mensagem': mensagemUsuario, 'historico': historicoConversa}),
      ).timeout(const Duration(seconds: 45)); 

      if (kDebugMode) {
        print('N8N (Interação 1) Raw Response Status Code: ${response.statusCode}');
        print('N8N (Interação 1) Raw Response Body: ${response.body}');
      }

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final Map<String, dynamic> n8nResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          if (kDebugMode) print('N8N (Interação 1) Parsed n8nResponse: $n8nResponse');


          // Extrai os campos que podem ou não existir
          final String? actionTag = n8nResponse['action_tag'] as String?;
          final String? status = n8nResponse['status'] as String?;
          final dynamic messageField = n8nResponse['message']; // Pode ser string ou não existir
          final dynamic payloadField = n8nResponse['payload_criteria']; // Pode ser Map ou não existir

          // CASO 1: Formato ideal para ação do cliente (payload_criteria já é um Map)
          if (actionTag == 'ANALYZE_REGIONS_AND_SCRAPE_LISTINGS' &&
              status == 'action_required_client' &&
              payloadField is Map) {
            if (kDebugMode) print("UserServices (CASO 1): Recebida action_tag com payload_criteria objeto Map.");
            return n8nResponse; 
          } 
          // CASO 1.B: Formato atual do N8N (payload_criteria está dentro de 'message' como string JSON)
          else if (actionTag == 'ANALYZE_REGIONS_AND_SCRAPE_LISTINGS' &&
                     status == 'action_required_client' &&
                     messageField is String) {
            if (kDebugMode) print("UserServices (CASO 1.B): Recebida action_tag, payload_criteria está em 'message' como string.");
            try {
              final Map<String, dynamic> criteriosDecodificados = jsonDecode(messageField) as Map<String, dynamic>;
              return {
                "status": status, 
                "action_tag": actionTag, 
                "payload_criteria": criteriosDecodificados // Agora é um Map
              };
            } catch (e_parse_message) {
              print("UserServices (CASO 1.B - ERRO): Falha ao decodificar 'message' como JSON de payload_criteria: $e_parse_message");
              return formatoErroPadrao("Falha ao processar os critérios do assistente (ERR_CRITERIA_PARSE).");
            }
          }
          // CASO 2: Mensagem conversacional direta da IA (campo 'message' é string, sem action_tag específica)
          else if (messageField is String) {
            if (kDebugMode) print("UserServices (CASO 2): Recebida mensagem direta/conversacional do N8N (status: $status).");
            final String messageFromAI = messageField;
            
            List<Map<String, dynamic>> extractedImoveis = extractImovelCards(messageFromAI);
            String mainTextContent = removeCardJsonFromString(messageFromAI);

            return {
              'tipo_resposta': extractedImoveis.isNotEmpty ? 'lista_imoveis' : 'texto_simples',
              'conteudo_texto': mainTextContent,
              'imoveis': extractedImoveis,
              'pergunta_follow_up': '', 
              'action_tag': null, 
              'status_from_n8n': status ?? 'unknown'
            };
          } 
          // CASO 3: Formato de resposta realmente inesperado
          else {
            print("UserServices (CASO 3): Resposta da Interação 1 N8N com formato muito inesperado: $n8nResponse");
            return formatoErroPadrao("O assistente retornou uma resposta em formato desconhecido (ERR_UNEXPECTED_I1_FINAL).");
          }
        } catch (e, stackTrace) {
          print("UserServices: Erro GERAL ao processar JSON da Interação 1 N8N: ${response.body}");
          print("Exceção: $e\nStackTrace: $stackTrace");
          return formatoErroPadrao("Problema crítico ao processar resposta inicial do assistente (ERR_FATAL_PARSE_I1).");
        }
      } else { 
        print('UserServices: Erro na comunicação com N8N (Interação 1). Status: ${response.statusCode}, Body: ${response.body}');
        return formatoErroPadrao("Falha na comunicação inicial com o assistente (${response.statusCode}).");
      }
    } catch (e, stackTrace) { 
      print('UserServices: Exceção na requisição HTTP para N8N (Interação 1): $e');
      print("StackTrace: $stackTrace");
      return formatoErroPadrao("Erro de conexão ao contatar o assistente. Verifique sua internet (ERR_HTTP_I1).");
    }
  }

  // --- O resto da classe UserServices (formatarRespostaFinalComIA, formatoErroPadrao, extractImovelCards, removeCardJsonFromString) ---
  // (Copie o resto da classe da sua versão anterior ou da minha resposta anterior, pois não mudou)
  Future<Map<String, dynamic>> formatarRespostaFinalComIA({
    required List<Map<String, dynamic>> imoveisColetados, 
    required List<Map<String, dynamic>> regioesSugeridas, 
  }) async {
    if (kDebugMode) {
      print("UserServices: Enviando para N8N - Interação 2 (Formatar Resposta Final)");
      print("URL: $_urlN8NInteracao2");
      print("Imóveis Coletados: ${imoveisColetados.length}");
    }

    try {
      final response = await http.post(
        _urlN8NInteracao2,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'regioes_sugeridas_pelo_cliente': regioesSugeridas,
          'imoveis_encontrados': imoveisColetados
        }),
      ).timeout(const Duration(seconds: 90)); 

      if (kDebugMode) {
        print('N8N (Interação 2) Status Code: ${response.statusCode}');
        print('N8N (Interação 2) Response Body: ${response.body}');
      }
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final Map<String, dynamic> n8nResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final String? statusN8N = n8nResponse['status'] as String?;
          final String? messageFromAI = n8nResponse['message'] as String?;

          if (statusN8N == 'success' && messageFromAI != null) {
            List<Map<String, dynamic>> extractedImoveis = extractImovelCards(messageFromAI);
            String mainTextContent = removeCardJsonFromString(messageFromAI);
            return {
              'tipo_resposta': extractedImoveis.isNotEmpty ? 'lista_imoveis' : 'texto_simples',
              'conteudo_texto': mainTextContent,
              'imoveis': extractedImoveis,
              'pergunta_follow_up': '', 
              'action_tag': null, 
              'status_from_n8n': 'success'
            };
          } else {
            print("UserServices: Resposta da Interação 2 N8N não foi 'success' ou mensagem está vazia: $n8nResponse");
            return formatoErroPadrao(messageFromAI ?? "O assistente retornou uma resposta final inesperada.");
          }
        } catch (e, stackTrace) {
          print("UserServices: Erro ao decodificar JSON da Interação 2 N8N: ${response.body}");
          print("Exceção: $e\nStackTrace: $stackTrace");
          return formatoErroPadrao("Problema ao processar resposta final do assistente (ERR_PARSE_I2).");
        }
      } else {
        print('UserServices: Erro na comunicação com N8N (Interação 2). Status: ${response.statusCode}, Body: ${response.body}');
        return formatoErroPadrao("Falha na formatação final da resposta pelo assistente (${response.statusCode}).");
      }
    } catch (e, stackTrace) {
      print('UserServices: Exceção na requisição HTTP para N8N (Interação 2): $e');
      print("StackTrace: $stackTrace");
      return formatoErroPadrao("Erro de conexão ao finalizar com o assistente. Verifique sua internet (ERR_HTTP_I2).");
    }
  }

  Map<String, dynamic> formatoErroPadrao(String mensagemErro) { 
    return {
      'tipo_resposta': 'erro', 
      'conteudo_texto': mensagemErro,
      'imoveis': [],
      'pergunta_follow_up': '',
      'action_tag': null, 
      'status_from_n8n_error': true 
    };
  }

  List<Map<String, dynamic>> extractImovelCards(String messageFromAI) { 
    final List<Map<String, dynamic>> cards = [];
    final RegExp cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##", dotAll: true);
    Iterable<RegExpMatch> matches = cardRegExp.allMatches(messageFromAI);
    for (final match in matches) {
      final String jsonString = match.group(1) ?? "";
      if (jsonString.isNotEmpty) {
        try {
          final Map<String, dynamic> cardData = jsonDecode(jsonString) as Map<String, dynamic>;
          cards.add(cardData);
        } catch (e) {
          print("UserServices: Erro ao decodificar JSON de card embutido: '$jsonString' \nExceção: $e");
        }
      }
    }
    if (kDebugMode && cards.isNotEmpty) {
      print("UserServices: Cards extraídos da mensagem: ${cards.length}");
    }
    return cards;
  }

  String removeCardJsonFromString(String messageFromAI) { 
    final RegExp cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##", dotAll: true);
    String cleanedMessage = messageFromAI.replaceAll(cardRegExp, "\n[CARD DO IMÓVEL]\n"); 
    List<String> lines = cleanedMessage.split('\n');
    List<String> processedLines = [];
    for (String line in lines) {
      String trimmedLine = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      if (trimmedLine.isNotEmpty || (processedLines.isNotEmpty && processedLines.last.isNotEmpty)) {
          processedLines.add(trimmedLine);
      }
    }
    while (processedLines.isNotEmpty && processedLines.last.isEmpty) {
        processedLines.removeLast();
    }
    cleanedMessage = processedLines.join('\n').trim();
    cleanedMessage = cleanedMessage.replaceAll("[CARD DO IMÓVEL]", "\n[CARD DO IMÓVEL]\n")
                                   .replaceAll(RegExp(r'\n\n\n+'), '\n\n')
                                   .trim();
    return cleanedMessage;
  }
}