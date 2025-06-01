import 'dart:convert'; // Para jsonEncode e jsonDecode
import 'dart:async';  // Para Future
import 'package:http/http.dart' as http; // Para chamadas HTTP
import 'package:urbanai/scripts/secret.dart'; // Importa suas chaves de API

// (A classe RegiaoSugerida permanece a mesma)
class RegiaoSugerida {
  final String nomeRegiao;
  final String cidadeRegiao;
  final double score;
  final String justificativaBase;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> detalhesScore;

  RegiaoSugerida({
    required this.nomeRegiao,
    required this.cidadeRegiao,
    required this.score,
    required this.justificativaBase,
    required this.latitude,
    required this.longitude,
    required this.detalhesScore,
  });

  Map<String, dynamic> toJson() => {
    'nome_regiao': nomeRegiao,
    'cidade_regiao': cidadeRegiao,
    'score': score,
    'justificativa_base': justificativaBase,
    'latitude': latitude,
    'longitude': longitude,
    'detalhes_score': detalhesScore,
  };
}


class RegionAnalysisService {
  final String _mapsApiKey = googleMapsApiKey; 
  final String _openAIApiKey = apiKeyOpenAI; 

  final Map<String, List<String>> _poiTypeMapping = {
    "parques_proximos": ["park"],
    "escolas_proximas": ["school", "primary_school", "secondary_school"],
    "universidades_faculdades": ["university"],
    "supermercados_proximos": ["supermarket", "grocery_or_supermarket"],
    "metro_proximo": ["subway_station", "light_rail_station", "transit_station"],
    "hospitais_clinicas_proximos": ["hospital", "doctor", "dentist", "pharmacy"],
    "restaurantes_cafes_proximos": ["restaurant", "cafe", "bar"],
    "academias_boas": ["gym"],
    "shopping_comercio_proximo": ["shopping_mall", "store"],
  };

  final int _poiSearchRadiusMeters = 2000; 
  final int _maxSuggestedRegions = 3;     
  final int _requestTimeoutSeconds = 15;  

  Future<List<RegiaoSugerida>> analisarRegioesComScoreIA({
    required Map<String, dynamic> criteriosGeraisUsuario,
  }) async {
    if (_mapsApiKey.startsWith('SUA_') || _mapsApiKey.isEmpty) {
      print("ALERTA (RegionAnalysisService): Chave API Google Maps não configurada!");
      return [];
    }
    if (_openAIApiKey.startsWith('SUA_') || _openAIApiKey.isEmpty) {
      print("ALERTA (RegionAnalysisService): Chave API OpenAI não configurada!");
      return []; // Retorna vazio se a chave da IA de score não estiver configurada
    }

    final List<dynamic> referenciasLocais = criteriosGeraisUsuario['referencias_locais'] as List<dynamic>? ?? [];
    final List<dynamic> prioridadesLifestyle = criteriosGeraisUsuario['prioridades_lifestyle'] as List<dynamic>? ?? [];
    final List<dynamic>? bairrosDesejados = criteriosGeraisUsuario['bairros_desejados'] as List<dynamic>?;
    
    List<Map<String, dynamic>> coordsReferencias = [];
    for (var ref in referenciasLocais) {
      if (ref is Map && ref['endereco'] is String) {
        final coords = await _geocodeAddress(ref['endereco']);
        if (coords != null) {
          coordsReferencias.add({...coords, 'tipo': ref['tipo'] ?? 'referencia'});
        }
      }
    }

    List<Map<String, dynamic>> regioesCandidatas = await _definirRegioesCandidatas(
      bairrosDesejados: bairrosDesejados?.map((e) => e.toString()).toList(),
      coordsReferencias: coordsReferencias,
      cidadeContexto: coordsReferencias.isNotEmpty && coordsReferencias.first['cidade'] != null 
                      ? coordsReferencias.first['cidade'] 
                      : "São Paulo", 
    );

    if (regioesCandidatas.isEmpty) {
      print("Nenhuma região candidata definida para análise.");
      return [];
    }
    
    print("Regiões candidatas para análise com IA: ${regioesCandidatas.map((r) => r['nome']).toList()}");

    List<RegiaoSugerida> regioesComScoreFinal = [];
    for (var regiao in regioesCandidatas) {
      Map<String, int> contagemPOIsDetalhada = {};
      for (String prioridade in prioridadesLifestyle.map((e) => e.toString())) {
        List<String>? tiposGoogle = _poiTypeMapping[prioridade];
        if (tiposGoogle != null) {
          int count = await _countNearbyPOIs(regiao['lat'], regiao['lng'], _poiSearchRadiusMeters, tiposGoogle);
          contagemPOIsDetalhada[prioridade] = count;
        }
      }

      Map<String, dynamic>? dadosDistancia;
      if (coordsReferencias.isNotEmpty) {
        dadosDistancia = await _getAverageDistanceDuration(regiao, coordsReferencias);
      }
      
      print("Chamando IA para score da região: ${regiao['nome']}");
      Map<String, dynamic> iaScoreResult = await _getScoreAndJustificationFromAI(
        regiaoNome: regiao['nome'],
        cidadeRegiao: regiao['cidade'] ?? "Cidade não especificada",
        dadosDistancia: dadosDistancia, 
        contagemPOIs: contagemPOIsDetalhada,
        criteriosGeraisUsuario: criteriosGeraisUsuario 
      );
      
      double scoreFinalIA = iaScoreResult['score'] ?? 0.0; 
      String justificativaIA = iaScoreResult['justificativa'] ?? "Não foi possível gerar uma justificativa detalhada.";

      regioesComScoreFinal.add(RegiaoSugerida(
        nomeRegiao: regiao['nome'],
        cidadeRegiao: regiao['cidade'] ?? "N/A",
        score: scoreFinalIA, 
        justificativaBase: justificativaIA, 
        latitude: regiao['lat'],
        longitude: regiao['lng'],
        detalhesScore: { 
          "distancia_media_km": dadosDistancia?['distancia_km'],
          "duracao_media_min": dadosDistancia?['duracao_min'],
          "contagem_pois_detalhada": contagemPOIsDetalhada,
          "score_atribuido_pela_ia": scoreFinalIA,
        }
      ));
    }

    regioesComScoreFinal.sort((a, b) => b.score.compareTo(a.score));
    return regioesComScoreFinal.take(_maxSuggestedRegions).toList();
  }

  // --- Funções Auxiliares para Google Maps APIs (geocode, Define Regiões, POIs, Distância) ---
  // (Estas funções _geocodeAddress, _definirRegioesCandidatas, _countNearbyPOIs, 
  //  _getAverageDistanceDuration permanecem como na sua última versão postada,
  //  com as correções e logs que já fizemos)
  Future<Map<String, dynamic>?> _geocodeAddress(String address) async { /* ...sua implementação completa... */ 
    if (_mapsApiKey.isEmpty || _mapsApiKey.startsWith('SUA_')) { print("ERRO (geocode_address): Maps_API_KEY não está disponível."); return null; }
    String url = "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_mapsApiKey&language=pt-BR&region=BR";
    try {
      final response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'}).timeout(Duration(seconds: _requestTimeoutSeconds));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final res = data['results'][0];
          final loc = res['geometry']['location'];
          String? bairro, cidade;
          for (var component in res['address_components']) {
             final types = component['types'] as List;
             if (types.contains('sublocality_level_1')) bairro = component['long_name'];
             else if (types.contains('locality') && bairro == null) bairro = component['long_name'];
             if (types.contains('administrative_area_level_2')) cidade = component['long_name'];
             else if (types.contains('locality') && cidade == null) cidade = component['long_name'];
          }
          return {'lat': loc['lat'], 'lng': loc['lng'], 'bairro': bairro, 'cidade': cidade, 'endereco_formatado': res['formatted_address']};
        } else { print("Erro Geocoding API: ${data['status']} - ${data.containsKey('error_message') ? data['error_message'] : 'Sem mensagem'} (End: $address)"); }
      } else { print("Erro HTTP Geocoding ($address): ${response.statusCode}"); }
    } catch (e) { print("Exceção Geocoding ($address): $e"); }
    return null;
  }

  Future<List<Map<String, dynamic>>> _definirRegioesCandidatas({
      List<String>? bairrosDesejados,
      required List<Map<String, dynamic>> coordsReferencias,
      String cidadeContexto = "São Paulo",
  }) async { /* ...sua implementação completa... */ 
      List<Map<String, dynamic>> regioes = [];
      Set<String> nomesUnicosNormalizados = {}; 
      if (bairrosDesejados != null && bairrosDesejados.isNotEmpty) {
          for (String nomeBairro in bairrosDesejados) {
              if (nomeBairro.trim().isEmpty) continue;
              final coordsBairro = await _geocodeAddress("${nomeBairro.trim()}, $cidadeContexto");
              if (coordsBairro != null) {
                  String nomeFinal = coordsBairro['bairro'] ?? nomeBairro.trim();
                  String cidadeFinal = coordsBairro['cidade'] ?? cidadeContexto;
                  String chaveUnica = "${nomeFinal.toLowerCase()}_${cidadeFinal.toLowerCase()}";
                  if (nomesUnicosNormalizados.add(chaveUnica)) {
                      regioes.add({'nome': nomeFinal, 'cidade': cidadeFinal, 'lat': coordsBairro['lat'], 'lng': coordsBairro['lng']});
                  }
              }
          }
      }
      if (coordsReferencias.isNotEmpty) {
          for (var ref in coordsReferencias) {
              if (ref['bairro'] != null) {
                  String nomeFinal = ref['bairro'];
                  String cidadeFinal = ref['cidade'] ?? cidadeContexto;
                   String chaveUnica = "${nomeFinal.toLowerCase()}_${cidadeFinal.toLowerCase()}";
                  if (nomesUnicosNormalizados.add(chaveUnica)) {
                       regioes.add({'nome': nomeFinal, 'cidade': cidadeFinal, 'lat': ref['lat'], 'lng': ref['lng']});
                   }
              }
          }
      }
      if (regioes.isEmpty && coordsReferencias.isNotEmpty) {
          final primeiraRef = coordsReferencias.first;
          regioes.add({
              'nome': "Área próxima a ${primeiraRef['endereco_formatado']}",
              'cidade': primeiraRef['cidade'] ?? cidadeContexto,
              'lat': primeiraRef['lat'],
              'lng': primeiraRef['lng']
          });
      }
      return regioes;
  }

  Future<int> _countNearbyPOIs(double lat, double lng, int radiusMeters, List<String> poiTypesGoogle) async { /* ...sua implementação completa... */ 
      if (poiTypesGoogle.isEmpty) return 0;
      int totalCount = 0;
      for (String type in poiTypesGoogle) { 
          String url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radiusMeters&type=$type&key=$_mapsApiKey&language=pt-BR";
          try { 
            final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: _requestTimeoutSeconds));
            if (response.statusCode == 200) {
                final data = json.decode(response.body);
                if (data['status'] == 'OK') totalCount += (data['results'] as List).length;
                else if (data['status'] != 'ZERO_RESULTS') { print("AVISO Places API ($type @ $lat,$lng): ${data['status']}");}
            } else { print("Erro HTTP Places API ($type @ $lat,$lng): ${response.statusCode}");}
          } catch(e) {print("Exceção POI ($type @ $lat,$lng): $e");}
      }
      return totalCount;
  }

  Future<Map<String, dynamic>?> _getAverageDistanceDuration(Map<String, dynamic> originCoord, List<Map<String, dynamic>> destinationCoordsList) async { /* ...sua implementação completa... */ 
      if (destinationCoordsList.isEmpty) return null;
      String origins = "${originCoord['lat']},${originCoord['lng']}";
      String destinations = destinationCoordsList.map((d) => "${d['lat']},${d['lng']}").join('|');
      String url = "https://maps.googleapis.com/maps/api/distancematrix/json?origins=$origins&destinations=$destinations&key=$_mapsApiKey&language=pt-BR&units=metric&mode=driving";
      try { 
          final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: _requestTimeoutSeconds));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['rows'] != null && (data['rows'] as List).isNotEmpty) {
                int totalDuration = 0, totalDistance = 0, validElements = 0;
                for (var element in data['rows'][0]['elements']) {
                    if (element['status'] == 'OK') {
                        totalDuration += element['duration']['value'] as int; 
                        totalDistance += element['distance']['value'] as int; 
                        validElements++;
                    }
                }
                if (validElements > 0) return {'distancia_km': double.parse((totalDistance / validElements / 1000).toStringAsFixed(1)), 'duracao_min': (totalDuration / validElements / 60).round()};
            } else { print("Erro Distance Matrix API: ${data['status']}"); }
          } else { print("Erro HTTP Distance Matrix: ${response.statusCode}"); }
      } catch (e) { print("Exceção Distance Matrix: $e"); }
      return null;
  }

  // --- ATUALIZADO: Função para Chamar IA (ChatGPT/OpenAI) para Score e Justificativa ---
  Future<Map<String, dynamic>> _getScoreAndJustificationFromAI({
    required String regiaoNome,
    required String cidadeRegiao,
    required Map<String, dynamic>? dadosDistancia, 
    required Map<String, int> contagemPOIs, 
    required Map<String, dynamic> criteriosGeraisUsuario,
  }) async {
    if (_openAIApiKey.isEmpty || _openAIApiKey.startsWith('SUA_')) {
        print("ALERTA (_getScoreAndJustificationFromAI): OpenAI API Key não configurada! Retornando score e justificativa padrão.");
        return {"score": 5.0, "justificativa": "Score padrão aplicado (chave IA não configurada)."}; 
    }

    // String para representar os dados coletados de forma legível para a IA
    String dadosColetadosParaPrompt = "- Proximidade aos locais de referência do usuário: ";
    if (dadosDistancia != null && dadosDistancia['duracao_min'] != null) {
      dadosColetadosParaPrompt += "Tempo médio de deslocamento de ${dadosDistancia['duracao_min']} minutos (distância média ${dadosDistancia['distancia_km']}km).\n";
    } else if (criteriosGeraisUsuario['referencias_locais'] != null && (criteriosGeraisUsuario['referencias_locais'] as List).isNotEmpty) {
      dadosColetadosParaPrompt += "Não foi possível calcular o tempo/distância para os locais de referência.\n";
    } else {
      dadosColetadosParaPrompt += "Nenhum local de referência principal fornecido pelo usuário para cálculo de distância.\n";
    }

    dadosColetadosParaPrompt += "- Pontos de Interesse encontrados na região (contagem baseada nas prioridades do usuário):\n";
    if (contagemPOIs.isNotEmpty) {
      contagemPOIs.forEach((key, value) {
        dadosColetadosParaPrompt += "  - ${key.replaceAll('_', ' ')}: $value\n";
      });
    } else {
      dadosColetadosParaPrompt += "  Nenhum Ponto de Interesse específico (baseado nas prioridades) foi encontrado em grande quantidade ou contado para esta região.\n";
    }

    // **NOVO: System Prompt para definir o papel e o formato da resposta da IA**
    String systemPromptString = """
    Você é um especialista em avaliação imobiliária e análise urbana no Brasil. Sua função é analisar dados de uma região candidata e os critérios de um usuário para determinar o quão adequada essa região é para ele.

    Você deve atribuir um score numérico de 0.0 a 10.0, onde 10.0 é perfeitamente adequado e 0.0 é completamente inadequado.
    Além do score, forneça uma justificativa CURTA, OBJETIVA e PERSONALIZADA (1-2 frases) para o score, mencionando os pontos positivos e/ou negativos mais relevantes da região em relação às necessidades específicas do usuário.

    Considere TODOS os critérios do usuário fornecidos (como prioridades de estilo de vida, locais de referência, orçamento, tipo de imóvel e objetivo) e os dados coletados sobre a região (como proximidade a referências e disponibilidade de Pontos de Interesse).

    Sua resposta DEVE SER ESTRITAMENTE um objeto JSON no seguinte formato:
    {
      "score_atribuido": valor_decimal_entre_0_e_10,
      "justificativa_score": "sua justificativa aqui."
    }
    Não inclua nenhum outro texto ou formatação fora deste objeto JSON.
    """;

    // **NOVO: User Prompt (agora mais focado nos dados variáveis)**
    String userPromptString = """
    Por favor, avalie a região "$regiaoNome, $cidadeRegiao" para o usuário com os seguintes critérios e dados:

    **1. Critérios Gerais do Usuário (extraídos de uma conversa anterior):**
    ```json
    ${json.encode(criteriosGeraisUsuario)}
    ```

    **2. Dados Coletados para a Região Candidata "$regiaoNome, $cidadeRegiao":**
    ${dadosColetadosParaPrompt.trim()}

    Forneça sua avaliação (score e justificativa) no formato JSON especificado.
    """;
    
    print("--- USER PROMPT PARA IA DE SCORE (Região: $regiaoNome) ---");
    print(userPromptString); // O System Prompt não é impresso aqui, mas será enviado na API
    print("--------------------------------------------------------");

    try {
      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"), 
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_openAIApiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini", // Verifique o nome exato do modelo se "4.1 mini" for específico
          "messages": [
            {"role": "system", "content": systemPromptString}, // MENSAGEM DE SISTEMA
            {"role": "user", "content": userPromptString}      // MENSAGEM DO USUÁRIO COM OS DADOS
          ],
          "temperature": 0.3, 
          "response_format": {"type": "json_object"} 
        }),
      ).timeout(Duration(seconds: _requestTimeoutSeconds + 10)); // Timeout maior para IA

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes); 
        final responseData = json.decode(responseBody);
        
        final String? aiContentString = responseData['choices']?[0]?['message']?['content'];
        if (aiContentString != null) {
          try {
            print("Resposta da IA de Score (string JSON): $aiContentString");
            final Map<String, dynamic> aiJson = json.decode(aiContentString);
            double score = (aiJson['score_atribuido'] as num?)?.toDouble() ?? 0.0;
            score = score.clamp(0.0, 10.0); 
            
            return {
              "score": score,
              "justificativa": aiJson['justificativa_score'] as String? ?? "IA não forneceu justificativa clara."
            };
          } catch (e) {
            print("Erro ao decodificar JSON da resposta da IA de score: $aiContentString \nExceção: $e");
          }
        } else {
          print("Conteúdo da mensagem da IA de score está nulo. Resposta Completa: $responseData");
        }
      } else {
        print("Erro da API OpenAI (Score Região $regiaoNome): ${response.statusCode} - ${utf8.decode(response.bodyBytes)}");
      }
    } catch (e, s) {
      print("Exceção ao chamar API OpenAI (Score Região $regiaoNome): $e\nStackTrace: $s");
    }
    return {"score": 0.0, "justificativa": "Não foi possível obter score da IA para esta região."}; // Fallback
  }
}