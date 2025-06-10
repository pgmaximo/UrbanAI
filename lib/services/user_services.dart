import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Importações cruciais para a integração
import 'package:urbanai/scripts/ScrapeScript.dart'; // Importa a classe ScrapeService
import 'package:urbanai/scripts/secret.dart';      // Importa as chaves de API
import 'package:urbanai/services/app_services.dart';

class UserServices {
  final AppServices _appServices = AppServices();

  // --- PONTO CHAVE DA INTEGRAÇÃO ---
  // Cria uma instância real do ScrapeService, passando a chave da API da SerpAPI.
  final ScrapeService _scrapeService = ScrapeService(apiKey: apiKeySerpApi);

  // URLs para a comunicação em duas fases com o N8N
  final Uri _urlN8N_InteracaoInicial = Uri.parse(apiKeyN8N_InteracaoInicial);
  final Uri _urlN8N_ReceberDadosScraping = Uri.parse(apiKeyN8N_ReceberDadosScraping);

  /// Envia a mensagem inicial para o N8N e orquestra as ações.
  Future<Map<String, dynamic>> enviarMensagem(String mensagemUsuario) async {
    if (kDebugMode) print("[UserSvc] Iniciando Interação 1 com N8N.");
    
    try {
      // --- CHAMADA PARA O WEBHOOK 1 (INICIAL) ---
      final responseInicial = await http.post(
        _urlN8N_InteracaoInicial,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'mensagem': mensagemUsuario,
          'historico': _appServices.getHistoricoConversaCache(),
        }),
      ).timeout(const Duration(seconds: 45));

      if (responseInicial.statusCode != 200 || responseInicial.body.isEmpty) {
        return formatoErroPadrao("Falha na comunicação inicial com o assistente (${responseInicial.statusCode}).");
      }

      final n8nResponse = jsonDecode(utf8.decode(responseInicial.bodyBytes));
      
      // VERIFICA SE O N8N PEDIU UMA TAREFA DE SCRAPING
      if (n8nResponse['action_tag'] == 'EXECUTE_SCRAPING_TASK' && n8nResponse['serp_api_query'] is String) {
        if (kDebugMode) print("[UserSvc] N8N solicitou tarefa de scraping.");
        final String query = n8nResponse['serp_api_query'];

        // --- A INTEGRAÇÃO ACONTECE AQUI ---
        // Chama o método do ScrapeService para executar a tarefa completa.
        final List<Map<String, String>> dadosColetados = 
            await _scrapeService.executarBuscaEExtrairConteudos(
                querySerpApi: query, 
                totalAnuncios: 3
            );

        if (dadosColetados.isEmpty) {
          return formatoErroPadrao("Não consegui encontrar imóveis com os critérios fornecidos.");
        }

        // --- CHAMADA PARA O WEBHOOK 2 (ENVIAR DADOS COLETADOS) ---
        if (kDebugMode) print("[UserSvc] Enviando dados coletados para o Webhook 2 do N8N.");
        return await _enviarDadosScrapingParaN8N(dadosColetados);

      } else {
        // Se não for uma tarefa, é uma resposta final (texto ou card)
        if (kDebugMode) print("[UserSvc] N8N retornou uma resposta direta.");
        return _processarRespostaFinal(n8nResponse);
      }

    } catch (e, stackTrace) {
      print('[UserSvc] Exceção geral: $e\n$stackTrace');
      return formatoErroPadrao("Erro de conexão. Verifique sua internet.");
    }
  }

  /// Envia os dados coletados para o segundo webhook do N8N e retorna a resposta final.
  Future<Map<String, dynamic>> _enviarDadosScrapingParaN8N(List<Map<String, String>> dados) async {
    try {
      final responseFinal = await http.post(
        _urlN8N_ReceberDadosScraping,
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'dados_coletados': dados, 'historico': _appServices.getHistoricoConversaCache()}),
      ).timeout(const Duration(seconds: 90));

      if (responseFinal.statusCode != 200 || responseFinal.body.isEmpty) {
        return formatoErroPadrao("O assistente falhou ao analisar os imóveis encontrados (${responseFinal.statusCode}).");
      }

      final n8nResponseFinal = jsonDecode(utf8.decode(responseFinal.bodyBytes));
      return _processarRespostaFinal(n8nResponseFinal);

    } catch (e) {
      return formatoErroPadrao("Erro ao enviar dados para análise final.");
    }
  }

  /// Processa uma resposta do N8N que contém a mensagem final para o usuário.
  Map<String, dynamic> _processarRespostaFinal(Map<String, dynamic> n8nResponse) {
      final String messageFromAI = n8nResponse['message'] as String? ?? "Ocorreu um erro inesperado.";
      final List<Map<String, dynamic>> extractedImoveis = extractImovelCards(messageFromAI);
      final String mainTextContent = removeCardJsonFromString(messageFromAI);

      return {
        'tipo_resposta': extractedImoveis.isNotEmpty ? 'lista_imoveis' : 'texto_simples',
        'conteudo_texto': mainTextContent,
        'conteudo_original': messageFromAI,
        'imoveis': extractedImoveis,
      };
  }

  // Funções auxiliares (formatoErroPadrao, extractImovelCards, removeCardJsonFromString)
  // O código delas permanece o mesmo.
  Map<String, dynamic> formatoErroPadrao(String mensagemErro) => {'tipo_resposta': 'erro', 'conteudo_texto': mensagemErro, 'conteudo_original': mensagemErro, 'imoveis': []};
  
  List<Map<String, dynamic>> extractImovelCards(String messageFromAI) { 
    final cards = <Map<String, dynamic>>[];
    final cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##", dotAll: true);
    cardRegExp.allMatches(messageFromAI).forEach((match) {
      final jsonString = match.group(1) ?? "";
      if (jsonString.isNotEmpty) {
        try {
          cards.add(jsonDecode(jsonString) as Map<String, dynamic>);
        } catch (e) {
          if (kDebugMode) print("[UserSvc] Erro ao decodificar JSON de card embutido: $e");
        }
      }
    });
    return cards;
  }
  
  String removeCardJsonFromString(String messageFromAI) { 
    final cardRegExp = RegExp(r"##CARD_JSON_START##(.*?)##CARD_JSON_END##\s*", dotAll: true);
    return messageFromAI.replaceAll(cardRegExp, "\n[CARD DO IMÓVEL]\n").trim();
  }
}