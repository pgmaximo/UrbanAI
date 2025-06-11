import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

class ScrapeService {
  final String apiKey;

  ScrapeService({required this.apiKey});
  
  // --- NOVA FUNÇÃO AUXILIAR ---
  /// Normaliza uma URL, removendo parâmetros de query (tudo após o '?').
  /// Isso garante que URLs como ".../imovel/123" e ".../imovel/123?source=google"
  /// sejam tratadas como a mesma.
  String _normalizarLink(String url) {
    final questionMarkIndex = url.indexOf('?');
    if (questionMarkIndex != -1) {
      return url.substring(0, questionMarkIndex);
    }
    return url;
  }

  Future<List<String>> getGoogleLinks(String query, {int numResults = 1}) async {
    if (apiKey.isEmpty) throw Exception("API_KEY da SerpAPI está vazia.");
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse("https://serpapi.com/search.json?q=$encodedQuery&api_key=$apiKey&num=$numResults&hl=pt-BR&gl=br");
    try {
      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception("Erro na requisição à SerpAPI: ${response.statusCode}");
      final data = jsonDecode(response.body);
      if (data.containsKey("organic_results")) {
        return (data["organic_results"] as List).map<String>((item) => item["link"].toString()).toList();
      }
      return [];
    } catch (e) {
      print("Erro em getGoogleLinks: $e");
      return [];
    }
  }

  // --- FUNÇÃO ATUALIZADA ---
  Future<List<String>> _extrairLinksDeAnunciosDaPagina(String urlPaginaResultados) async {
    print("🔎 Visitando a página de resultados: $urlPaginaResultados");
    try {
      final response = await http.get(Uri.parse(urlPaginaResultados));
      if (response.statusCode != 200) return [];
      final document = parser.parse(response.body);
      final Set<String> linksDeAnuncios = HashSet();
      
      document.querySelectorAll('a').forEach((element) {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) {
          String? linkCompleto;
          if (urlPaginaResultados.contains('quintoandar.com.br') && href.startsWith('/imovel/')) {
            linkCompleto = 'https://www.quintoandar.com.br$href';
          } else if (urlPaginaResultados.contains('zapimoveis.com.br') && href.contains('/imovel/')) {
            if (href.startsWith('http')) linkCompleto = href;
          }

          if (linkCompleto != null) {
            // Adiciona a versão NORMALIZADA do link ao Set
            linksDeAnuncios.add(_normalizarLink(linkCompleto));
          }
        }
      });
      
      print("✅ Extraídos ${linksDeAnuncios.length} links de anúncios únicos da página.");
      return linksDeAnuncios.toList();
    } catch (e) {
      print("❌ Erro ao extrair links da página $urlPaginaResultados: $e");
      return [];
    }
  }
  
  Future<Map<String, dynamic>> _extrairDadosEstruturados(String url) async {
    print(" Ganhando dados estruturados de: $url");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return {"erro": "Erro ao acessar a página (Status: ${response.statusCode})"};
      
      final document = parser.parse(response.body);
      final scripts = document.querySelectorAll('script[type="application/ld+json"]');
      
      for (var script in scripts) {
        final jsonString = script.text;
        if (jsonString.contains('"@type":"Apartment"') || jsonString.contains('"@type":"House"') || jsonString.contains('"@type":"SingleFamilyResidence"') || jsonString.contains('"@type":"Product"')) {
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          print("  -> JSON Estruturado encontrado!");
          return jsonData;
        }
      }
      print("  -> Nenhum JSON-LD de imóvel encontrado. Usando texto bruto como fallback.");
      return {"texto_bruto": document.body?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? ''};
    } catch (e) {
      print("❌ Erro ao extrair JSON-LD de $url: $e");
      return {"erro": "Exceção ao tentar extrair dados estruturados."};
    }
  }
  
  Map<String, dynamic> _limparEProcessarDados(Map<String, dynamic> dadosBrutos, {int maxPalavras = 400}) {
    if (dadosBrutos.containsKey('erro') || dadosBrutos.containsKey('texto_bruto')) {
      return dadosBrutos;
    }
    
    String descricaoOriginal = dadosBrutos['description'] as String? ?? '';
    String descricaoResumida = descricaoOriginal.split(RegExp(r'\s+')).take(maxPalavras).join(' ');
    
    final dadosLimpos = {
      'link_original': dadosBrutos['link_original'],
      'name': dadosBrutos['name'],
      'description': descricaoResumida,
      'offers': dadosBrutos['offers'],
    };

    print("  -> Dados limpos e descrição truncada para ${maxPalavras} palavras.");
    return dadosLimpos;
  }

  Future<List<Map<String, dynamic>>> executarBuscaEExtrairConteudos({
    required String querySerpApi,
    int totalAnuncios = 5,
    int maxPalavras = 400,
  }) async {
    print("--- Iniciando processo completo de busca e extração ---");
    
    final paginasDeResultados = await getGoogleLinks(querySerpApi, numResults: 1);
    if (paginasDeResultados.isEmpty) return [];

    final Set<String> linksDeAnuncios = HashSet();
    for (String urlPagina in paginasDeResultados) {
      linksDeAnuncios.addAll(await _extrairLinksDeAnunciosDaPagina(urlPagina));
    }
    if (linksDeAnuncios.isEmpty) return [];

    final List<Map<String, dynamic>> resultadosFinais = [];
    final linksParaProcessar = linksDeAnuncios.take(totalAnuncios).toList();
    
    print("\nProcessando ${linksParaProcessar.length} anúncios para extração e limpeza...");
    for (String linkAnuncio in linksParaProcessar) {
      final dadosEstruturadosBrutos = await _extrairDadosEstruturados(linkAnuncio);
      dadosEstruturadosBrutos['link_original'] = linkAnuncio;
      final dadosLimpos = _limparEProcessarDados(dadosEstruturadosBrutos, maxPalavras: maxPalavras);
      resultadosFinais.add(dadosLimpos);
      await Future.delayed(const Duration(milliseconds: 200)); 
    }

    print("🎉 Extração e limpeza de dados finalizada!");
    return resultadosFinais;
  }
}