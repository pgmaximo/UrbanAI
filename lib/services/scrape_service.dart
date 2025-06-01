import 'dart:convert'; // Para jsonEncode e jsonDecode
import 'package:http/http.dart' as http; // Para chamadas HTTP
import 'package:urbanai/scripts/secret.dart'; // Para googleMapsApiKey, serpApiKey, openAIApiKey
import 'package:html/parser.dart' as parser; // Para analisar HTML
import 'package:flutter/foundation.dart'; // Para kDebugMode

class ScrapeService {
  final String serpApiKeyForService = apiKeySerpApi;
  final String _googleMapsApiKeyForService = googleMapsApiKey;
  final String _openAIApiKeyForService = apiKeyOpenAI; // Chave para ChatGPT/Gemini

  static const int _requestTimeoutSeconds = 25;
  static const int _scrapeDelaySeconds = 1;

  final Map<String, String> _scrapeHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  // --- FUNÇÕES PARA SERPAPI (permanecem como antes) ---
  String construirQuerySerpApi({
    required String? templateQuery,
    required String nomeRegiaoSugerida,
    required Map<String, dynamic> criteriosIA1,
  }) {
    // ... (código de construirQuerySerpApi como na resposta anterior) ...
    if (kDebugMode) print("ScrapeService: Iniciando construção da query SerpApi...");
    String queryBase = templateQuery ?? "{TIPO_IMOVEL_PLACEHOLDER} {OBJETIVO_PLACEHOLDER} em {REGIAO_PLACEHOLDER} {QUARTOS_PLACEHOLDER} {CARACTERISTICAS_PLACEHOLDER}";
    String tipoImovel = (criteriosIA1['tipo_imovel'] as List?)?.isNotEmpty == true ? (criteriosIA1['tipo_imovel'] as List).join(' ou ') : 'imóvel';
    String objetivo = criteriosIA1['objetivo'] as String? ?? 'para morar';
    String quartos = criteriosIA1['quartos_min'] != null ? "${criteriosIA1['quartos_min']} quartos" : "";
    String caracteristicasString = "";
    if (criteriosIA1['caracteristicas_desejadas'] is List && (criteriosIA1['caracteristicas_desejadas'] as List).isNotEmpty) {
        caracteristicasString = (criteriosIA1['caracteristicas_desejadas'] as List).join(' e ');
    } else if (criteriosIA1['outros_detalhes_importantes'] is String && (criteriosIA1['outros_detalhes_importantes'] as String).isNotEmpty) {
        caracteristicasString = criteriosIA1['outros_detalhes_importantes'];
    }
    String portaisFoco = "site:quintoandar.com.br OR site:imovelweb.com.br OR site:zapimoveis.com.br OR site:vivareal.com.br";
    String queryFinal = queryBase
        .replaceAll('{REGIAO_PLACEHOLDER}', nomeRegiaoSugerida)
        .replaceAll('{TIPO_IMOVEL_PLACEHOLDER}', tipoImovel)
        .replaceAll('{OBJETIVO_PLACEHOLDER}', objetivo)
        .replaceAll('{QUARTOS_PLACEHOLDER}', quartos)
        .replaceAll('{CARACTERISTICAS_PLACEHOLDER}', caracteristicasString);
    queryFinal = "$queryFinal $portaisFoco";
    queryFinal = queryFinal.replaceAll(RegExp(r'\{\w.*?_PLACEHOLDER\}'), '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (kDebugMode) print("ScrapeService: Query SerpApi construída: $queryFinal");
    return queryFinal;
  }

  Future<List<String>> getGoogleLinks(String query, {int numResults = 3}) async {
    // ... (código de getGoogleLinks como na resposta anterior, com verificações de chave e logs) ...
    if (kDebugMode) print("ScrapeService: Buscando links na SerpApi para query: $query");
    if (serpApiKeyForService.isEmpty || serpApiKeyForService.startsWith('SUA_API_KEY_SERPAPI_AQUI') || serpApiKeyForService == "COLOQUE_SUA_CHAVE_SERPAPI_REAL_AQUI_OU_NO_SECRET.DART") {
      print("ERRO CRÍTICO (ScrapeService - SerpApi): Chave da API SerpApi NÃO ESTÁ CONFIGURADA CORRETAMENTE!");
      return [];
    }
    final uri = Uri(scheme: 'https', host: 'serpapi.com', path: '/search.json', queryParameters: {
        'q': query, 'api_key': serpApiKeyForService, 'num': numResults.toString(), 'hl': 'pt-BR', 'gl': 'br', 'engine': 'google'});
    try {
      if (kDebugMode) print("ScrapeService: Chamando URL SerpApi: $uri");
      final response = await http.get(uri, headers: {'Accept-Language': 'pt-BR,pt;q=0.9','User-Agent': _scrapeHeaders['User-Agent']!,}).timeout(const Duration(seconds: _requestTimeoutSeconds));
      if (kDebugMode) print("ScrapeService: SerpApi Status Code: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        List<String> links = [];
        if (data is Map && data.containsKey('error')) {
            print("ERRO (ScrapeService - SerpApi): A API da SerpApi retornou um erro: ${data['error']}");
            return [];
        }
        if (data["organic_results"] != null && data["organic_results"] is List) {
          for (var item in (data["organic_results"] as List)) {
            if (item is Map && item["link"] is String) {
              String link = item["link"];
              if (link.contains("quintoandar.com.br/imovel") || link.contains("imovelweb.com.br/propriedades") || link.contains("zapimoveis.com.br/imovel") || link.contains("vivareal.com.br/imovel")) {
                 links.add(link);
              }
            }
          }
        } else { print("ScrapeService: Nenhum 'organic_results' encontrado ou formato inesperado. Resposta SerpApi: ${data.toString().substring(0, (data.toString().length > 300 ? 300 : data.toString().length))}"); }
        return links.take(numResults).toList();
      } else { print("ERRO (ScrapeService - SerpApi HTTP): Status ${response.statusCode} - Resposta: ${response.body.substring(0, (response.body.length > 500 ? 500 : response.body.length))}"); return []; }
    } catch (e, s) { print("ERRO CRÍTICO (ScrapeService - SerpApi) na requisição: $e\nStackTrace: $s"); return []; }
  }


  // --- MÉTODO PRINCIPAL DE SCRAPE ATUALIZADO ---
  Future<Map<String, dynamic>?> scrapeEDetalhaImovel(String url) async {
    if (kDebugMode) print("ScrapeService: Iniciando coleta de blocos de texto para URL: $url");
    Map<String, String>? textBlocks; // Mapa para { "titulo_pagina": "...", "descricao_principal": "...", "caracteristicas_texto": "..." }
    String portalNome = _inferFonteDaUrl(url);

    await Future.delayed(const Duration(seconds: _scrapeDelaySeconds));

    try {
      // 1. Coleta blocos de texto importantes específicos do portal
      if (portalNome == "QuintoAndar") {
        textBlocks = await _scrapeQuintoAndarTextBlocks(url);
      } else if (portalNome == "ImovelWeb") {
        textBlocks = await _scrapeImovelWebTextBlocks(url);
      } else if (portalNome == "Zap Imóveis") {
        textBlocks = await _scrapeZapImoveisTextBlocks(url);
      } // Adicionar outros portais
      else {
        print("AVISO (ScrapeService): Coletor de blocos de texto não implementado para o portal: $portalNome ($url)");
        // Poderia tentar um _scrapeGenericTextBlocks(url) como fallback
        return null; // Ou retornar um erro/mapa vazio
      }

      if (textBlocks == null || textBlocks.values.every((text) => text == null || text.isEmpty)) {
        print("ScrapeService: Nenhum bloco de texto relevante coletado de $url.");
        return null;
      }

      // 2. Enviar blocos de texto para a IA estruturar o JSON do card
      if (kDebugMode) print("ScrapeService: Enviando blocos de texto para IA estruturar dados do imóvel de $url");
      Map<String, dynamic>? imovelDataIA = await _structurePropertyDataWithAI(
          originalUrl: url,
          portalName: portalNome,
          textBlocks: textBlocks);

      if (imovelDataIA == null) {
        print("ScrapeService: IA falhou ao estruturar dados para $url.");
        return null;
      }
      
      // Adiciona campos que a IA pode não ter gerado ou que queremos garantir
      imovelDataIA['link_anuncio'] = url;
      imovelDataIA['fonte'] = portalNome;

      // 3. Buscar POIs próximos se tivermos coordenadas ou endereço
      double? lat = (imovelDataIA['latitude'] as num?)?.toDouble();
      double? lng = (imovelDataIA['longitude'] as num?)?.toDouble();
      String? enderecoImovel = imovelDataIA['endereco'] as String?;

      if ((lat == null || lng == null) && (enderecoImovel != null && enderecoImovel.isNotEmpty)) {
        if (kDebugMode) print("ScrapeService: Imóvel (IA) sem coordenadas, geocodificando: $enderecoImovel");
        Map<String, dynamic>? coordsImovel = await _geocodeAddressInterna(enderecoImovel);
        if (coordsImovel != null) {
          lat = coordsImovel['lat'] as double?;
          lng = coordsImovel['lng'] as double?;
          imovelDataIA['latitude'] = lat; 
          imovelDataIA['longitude'] = lng;
        } else {
           if (kDebugMode) print("ScrapeService: Falha ao geocodificar endereço do imóvel (IA): $enderecoImovel");
        }
      }

      if (lat != null && lng != null) {
        if (kDebugMode) print("ScrapeService: Buscando POIs próximos para o imóvel (IA) em ($lat, $lng)");
        List<Map<String, String>> poisDoImovel = await getPOIsProximosAoImovel(
          lat: lat, lng: lng,
          tiposPOI: ["grocery_or_supermarket", "pharmacy", "restaurant", "park", "subway_station", "bus_station", "school", "hospital"],
        );
        imovelDataIA['pois_proximos'] = poisDoImovel;
      } else {
        imovelDataIA['pois_proximos'] = [];
      }
      
      if (kDebugMode) print("ScrapeService: Dados finais do imóvel (IA + POIs): ${imovelDataIA['titulo'] ?? 'Sem título da IA'}");
      return imovelDataIA;

    } catch (e, s) {
        print("ERRO CRÍTICO (ScrapeService - scrapeEDetalhaImovel) para $url: $e");
        print("StackTrace (scrapeEDetalhaImovel): $s");
        return null;
    }
  }

  String _inferFonteDaUrl(String url) {
    if (url.contains("quintoandar.com.br")) return "QuintoAndar";
    if (url.contains("imovelweb.com.br")) return "ImovelWeb";
    if (url.contains("zapimoveis.com.br")) return "Zap Imóveis";
    if (url.contains("vivareal.com.br")) return "Viva Real";
    try { return Uri.parse(url).host; } catch (_) { return "Portal Desconhecido"; }
  }

  // --- NOVOS MÉTODOS DE SCRAPING PARA "BLOCOS DE TEXTO" (ESQUELETOS) ---
  // !!! VOCÊ PRECISA IMPLEMENTAR A LÓGICA DE EXTRAÇÃO DE BLOCOS DE TEXTO AQUI !!!
  
  Future<Map<String, String>?> _scrapeQuintoAndarTextBlocks(String url) async {
    if (kDebugMode) print("INFO (ScrapeService): Coletando blocos de texto de QuintoAndar: $url");
    try {
      final response = await http.get(Uri.parse(url), headers: _scrapeHeaders).timeout(const Duration(seconds: _requestTimeoutSeconds));
      if (response.statusCode == 200) {
        final document = parser.parse(utf8.decode(response.bodyBytes));
        
        // TODO: Identifique e extraia blocos de texto relevantes do QuintoAndar
        // Exemplo: título, descrição principal, seção de características, etc.
        String? tituloPagina = document.querySelector('title')?.text.trim();
        String? h1 = document.querySelector('h1')?.text.trim(); // Pode ser o título do anúncio

        // Tenta pegar o bloco de descrição principal
        // Os seletores são fictícios! Você precisa encontrar os reais.
        String? descricaoPrincipal = document.querySelector('div.property-description-content')?.text.trim() ??
                                   document.querySelector('div[data-testid="property-description"]')?.text.trim();
        
        // Tenta pegar uma seção de características
        String? caracteristicasTexto = document.querySelector('ul.property-features')?.text.trim() ??
                                     document.querySelector('div.amenities-section')?.text.trim();

        // Coleta todos os parágrafos como um fallback ou texto adicional
        // List<String> paragraphs = document.getElementsByTagName('p').map((p) => p.text.trim()).where((t) => t.isNotEmpty).toList();
        // String allParagraphsText = paragraphs.join('\n\n');


        if (kDebugMode) print("SUCESSO (Placeholder): Blocos de texto do QuintoAndar coletados para $url.");
        return {
            "url": url, // Sempre bom manter a URL original
            "titulo_pagina": tituloPagina ?? h1 ?? "Título não encontrado",
            "descricao_principal": descricaoPrincipal ?? "",
            "caracteristicas_texto": caracteristicasTexto ?? "",
            // "paragrafos_gerais": allParagraphsText, // Opcional
            // Adicione outros blocos que julgar importantes
        };
      } else {
        print("ERRO (_scrapeQuintoAndarTextBlocks): Status ${response.statusCode} para $url");
        return null;
      }
    } catch (e,s) {
      print("EXCEÇÃO (_scrapeQuintoAndarTextBlocks) para $url: $e\nStackTrace: $s");
      return null;
    }
  }

  Future<Map<String, String>?> _scrapeImovelWebTextBlocks(String url) async {
    if (kDebugMode) print("INFO (ScrapeService): Coletando blocos de texto de ImovelWeb: $url");
    // TODO: Implementar a lógica de extração de blocos de texto para ImovelWeb
    await Future.delayed(const Duration(milliseconds: 100));
    return {"url": url, "titulo_pagina": "Título ImovelWeb (a extrair)", "descricao_principal": "Descrição ImovelWeb (a extrair)"};
  }

  Future<Map<String, String>?> _scrapeZapImoveisTextBlocks(String url) async {
     if (kDebugMode) print("INFO (ScrapeService): Coletando blocos de texto de Zap Imóveis: $url");
    // TODO: Implementar a lógica de extração de blocos de texto para Zap Imóveis
    await Future.delayed(const Duration(milliseconds: 100));
    return {"url": url, "titulo_pagina": "Título Zap (a extrair)", "descricao_principal": "Descrição Zap (a extrair)"};
  }
  // Adicione mais funções como _scrapeVivaRealTextBlocks, etc.


  // --- NOVA FUNÇÃO: Usar IA para Estruturar Dados do Imóvel ---
  Future<Map<String, dynamic>?> _structurePropertyDataWithAI({
    required String originalUrl,
    required String portalName,
    required Map<String, String> textBlocks, // Ex: {"titulo_pagina": "...", "descricao_principal": "..."}
    String? initialTitleGuess, // Pode vir da SerpApi ou do scraper de blocos
  }) async {
    if (_openAIApiKeyForService.isEmpty || _openAIApiKeyForService.startsWith('SUA_')) {
      print("ALERTA (_structurePropertyDataWithAI): OpenAI API Key não configurada! Impossível estruturar dados com IA.");
      return null;
    }

    // Constrói o prompt para a IA
    String systemPrompt = """
    Você é um especialista em analisar textos de anúncios imobiliários e extrair informações estruturadas.
    Sua tarefa é preencher um objeto JSON com os detalhes do imóvel, baseado nos blocos de texto fornecidos.
    Campos a serem extraídos:
    - titulo (string): Um título conciso e informativo para o anúncio.
    - endereco (string): O endereço completo do imóvel, incluindo rua, número, bairro, cidade e estado. Se não houver completo, o máximo que puder.
    - preco (string): O valor do imóvel (ex: "R\$ 2.500/mês", "R\$ 650.000"). Indique se é aluguel ou venda.
    - quartos (integer | null): Número de quartos.
    - banheiros (integer | null): Número de banheiros.
    - vagas_garagem (integer | null): Número de vagas de garagem.
    - area_m2 (string | null): A área do imóvel em metros quadrados (ex: "75m²").
    - descricao_detalhada (string): Uma descrição mais completa do imóvel.
    - imagem_url (string | null): A URL da imagem principal do anúncio, se puder ser inferida ou encontrada.
    - latitude (float | null): Latitude estimada do imóvel, se puder inferir do endereço ou de dados da página.
    - longitude (float | null): Longitude estimada.

    Se uma informação não for encontrada nos textos, use o valor null para o campo correspondente.
    Retorne APENAS o objeto JSON.
    """;

    String userPrompt = """
    Analise os seguintes blocos de texto extraídos da página de um anúncio imobiliário do portal '$portalName' (URL: $originalUrl) e preencha o JSON com os detalhes do imóvel.
    Título Inicial (se houver): ${initialTitleGuess ?? textBlocks["titulo_pagina"] ?? "Não fornecido"}

    Blocos de Texto Coletados:
    ${textBlocks.entries.map((e) => "BLOCO '${e.key.replaceAll('_',' ')}':\n${e.value}\n---").join("\n")}

    Por favor, gere o JSON com os detalhes do imóvel.
    """;

    if (kDebugMode) {
      print("--- PROMPT PARA IA ESTRUTURAR DADOS (URL: $originalUrl) ---");
      // print("SYSTEM: $systemPrompt"); // System prompt é longo, opcional para log
      print("USER: $userPrompt");
      print("----------------------------------------------------------");
    }

    try {
      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_openAIApiKeyForService',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini", // Ou "gpt-3.5-turbo" para uma opção mais barata, mas menos capaz
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt}
          ],
          "temperature": 0.2, // Baixa temperatura para extração mais factual
          "response_format": {"type": "json_object"} // Solicita saída JSON
        }),
      ).timeout(const Duration(seconds: _requestTimeoutSeconds + 15)); // Timeout maior para IA

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final responseData = json.decode(responseBody);
        final String? aiContentString = responseData['choices']?[0]?['message']?['content'];

        if (aiContentString != null) {
          try {
            if (kDebugMode) print("ScrapeService: Resposta da IA para estruturação (string JSON): $aiContentString");
            Map<String, dynamic> structuredData = json.decode(aiContentString) as Map<String, dynamic>;
            // Validação básica dos campos esperados
            if (structuredData.containsKey('titulo') && structuredData.containsKey('preco')) {
               print("ScrapeService: Dados estruturados pela IA para $originalUrl: ${structuredData['titulo']}");
               return structuredData;
            } else {
               print("ERRO (ScrapeService): IA não retornou JSON com campos mínimos esperados (titulo, preco) para $originalUrl. Resposta: $aiContentString");
               return null;
            }
          } catch (e) {
            print("ERRO (ScrapeService): Falha ao decodificar JSON da resposta da IA para $originalUrl: $aiContentString \nExceção: $e");
            return null;
          }
        } else {
           print("ERRO (ScrapeService): Conteúdo da mensagem da IA para $originalUrl está nulo. Resposta Completa: $responseData");
           return null;
        }
      } else {
        print("ERRO (ScrapeService): API OpenAI para $originalUrl retornou status ${response.statusCode} - ${utf8.decode(response.bodyBytes)}");
        return null;
      }
    } catch (e, s) {
      print("EXCEÇÃO (ScrapeService) ao chamar API OpenAI para $originalUrl: $e\nStackTrace: $s");
      return null;
    }
  }

  // --- FUNÇÕES AUXILIARES (Geocodificação interna, POIs próximos ao imóvel) ---
  Future<Map<String, dynamic>?> _geocodeAddressInterna(String address) async {
    // ... (implementação como na resposta anterior) ...
    if (_googleMapsApiKeyForService.isEmpty || _googleMapsApiKeyForService.startsWith('SUA_')) { return null; }
    String url = "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleMapsApiKeyForService&language=pt-BR&region=BR";
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return {'lat': loc['lat'], 'lng': loc['lng']};
        } else {if (kDebugMode) print("AVISO Geocoding Interno para '$address': ${data['status']}");}
      } else {if (kDebugMode) print("Erro HTTP Geocoding Interno para '$address': ${response.statusCode}");}
    } catch (e) {if (kDebugMode) print("Exceção Geocoding Interno para '$address': $e");}
    return null;
  }

  Future<List<Map<String, String>>> getPOIsProximosAoImovel({
    required double lat, required double lng, required List<String> tiposPOI, int raioMetros = 750,
  }) async {
    // ... (implementação como na resposta anterior, com logs e verificações) ...
    if (_googleMapsApiKeyForService.isEmpty || _googleMapsApiKeyForService.startsWith('SUA_')) { return []; }
    List<Map<String, String>> poisEncontrados = [];
    Set<String> nomesPoisUnicos = {}; 
    int maxPoisPorTipo = 3; 
    int totalPoisGlobal = 0;
    const int maxTotalPoisGlobal = 10;
    for (String tipo in tiposPOI) {
      if (totalPoisGlobal >= maxTotalPoisGlobal) break;
      String url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$raioMetros&type=$tipo&key=$_googleMapsApiKeyForService&language=pt-BR";
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: _requestTimeoutSeconds - 10));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data['status'] == 'OK' && data['results'] != null) {
            int countPorTipo = 0;
            for (var poi in data['results']) {
              if (countPorTipo >= maxPoisPorTipo || totalPoisGlobal >= maxTotalPoisGlobal) break;
              String nomePoi = poi['name'] as String? ?? 'Nome indisponível';
              if (nomesPoisUnicos.add(nomePoi.toLowerCase())) { 
                String tipoPoiExibicao = (poi['types'] as List<dynamic>?)?.isNotEmpty == true 
                                      ? (poi['types'] as List<dynamic>).first.toString().replaceAll('_', ' ')
                                      : tipo.replaceAll('_', ' ');
                tipoPoiExibicao = tipoPoiExibicao.isNotEmpty ? tipoPoiExibicao[0].toUpperCase() + tipoPoiExibicao.substring(1) : "";
                poisEncontrados.add({"nome": nomePoi, "tipo": tipoPoiExibicao });
                countPorTipo++;
                totalPoisGlobal++;
              }
            }
          } else if (data['status'] != 'ZERO_RESULTS'){
             if (kDebugMode) print("AVISO Places API (POIs Imóvel - $tipo @ $lat,$lng): ${data['status']} - ${data['error_message'] ?? ''}");
          }
        } else {
          if (kDebugMode) print("Erro HTTP Places API (POIs Imóvel - $tipo @ $lat,$lng): ${response.statusCode}");
        }
      } catch (e) {
        if (kDebugMode) print("Exceção POIs Próximos ao Imóvel ($tipo @ $lat,$lng): $e");
      }
    }
    return poisEncontrados;
  }
}