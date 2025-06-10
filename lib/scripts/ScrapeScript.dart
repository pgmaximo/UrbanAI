import 'dart:convert';
import 'dart:collection'; // Para usar o HashSet, que evita duplicatas
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
// Removido o import do secret.dart daqui, pois a chave agora é recebida pelo construtor.

class ScrapeService {
  final String apiKey;

  ScrapeService({required this.apiKey});

  /// PASSO 1: Busca no Google usando a query cirúrgica da IA.
  Future<List<String>> getGoogleLinks(String query, {int numResults = 1}) async {
    if (apiKey.isEmpty) {
      throw Exception("API_KEY da SerpAPI está vazia.");
    }
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
        "https://serpapi.com/search.json?q=$encodedQuery&api_key=$apiKey&num=$numResults&hl=pt-BR&gl=br");

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception("Erro na requisição à SerpAPI: ${response.statusCode}");
      }
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

  /// PASSO 2: Extrai os links dos anúncios individuais de uma página de resultados.
  Future<List<String>> _extrairLinksDeAnunciosDaPagina(String urlPaginaResultados) async {
    print("🔎 Visitando a página de resultados: $urlPaginaResultados");
    try {
      final response = await http.get(Uri.parse(urlPaginaResultados));
      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);
      final Set<String> linksDeAnuncios = HashSet();

      List<dom.Element> linkElements = document.querySelectorAll('a');

      for (var linkElement in linkElements) {
        final href = linkElement.attributes['href'];
        if (href == null || href.isEmpty) continue;

        if (urlPaginaResultados.contains('quintoandar.com.br')) {
          if (href.startsWith('/imovel/')) {
            linksDeAnuncios.add('https://www.quintoandar.com.br$href');
          }
        } else if (urlPaginaResultados.contains('zapimoveis.com.br')) {
          if (href.contains('/imovel/')) {
            if (href.startsWith('http')) linksDeAnuncios.add(href);
          }
        }
      }
      
      print("✅ Extraídos ${linksDeAnuncios.length} links de anúncios da página.");
      return linksDeAnuncios.toList();
    } catch (e) {
      print("❌ Erro ao extrair links da página $urlPaginaResultados: $e");
      return [];
    }
  }

  /// PASSO 3: Extrai todo o texto de uma única página de anúncio.
  Future<String> _extrairTodoTextoDoSite(String url) async {
    print(" Ganhando o texto de: $url");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return "Erro ao acessar a página (Status: ${response.statusCode})";
      }
      final document = parser.parse(response.body);
      final texto = document.body?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      print("  -> Texto extraído com ${texto.length} caracteres.");
      return texto;
    } catch (e) {
      print("❌ Erro ao extrair texto de $url: $e");
      return "Exceção ao tentar extrair texto da página.";
    }
  }

  /// --- FUNÇÃO "MESTRE" ---
  /// Orquestra o fluxo completo: recebe a query da IA e retorna os conteúdos dos anúncios.
  Future<List<Map<String, String>>> executarBuscaEExtrairConteudos({
    required String querySerpApi,
    int totalAnuncios = 3,
  }) async {
    print("--- Iniciando processo completo de busca e extração ---");
    print("  Query da IA: $querySerpApi");

    // 1. Usa a query da IA para encontrar a página de resultados correta.
    final paginasDeResultados = await getGoogleLinks(querySerpApi, numResults: 1);
    if (paginasDeResultados.isEmpty) {
      print("Nenhuma página de resultados encontrada no Google para esta query.");
      return [];
    }

    // 2. Extrai os links dos anúncios individuais dessa página.
    final Set<String> linksDeAnuncios = HashSet();
    for (String urlPagina in paginasDeResultados) {
      final linksDaPagina = await _extrairLinksDeAnunciosDaPagina(urlPagina);
      linksDeAnuncios.addAll(linksDaPagina);
    }
    
    if (linksDeAnuncios.isEmpty) {
        print("Nenhum link de anúncio específico foi extraído da página de resultados.");
        return [];
    }

    // 3. Pega o número desejado de anúncios e extrai o conteúdo de cada um.
    final List<Map<String, String>> resultadosFinais = [];
    final linksParaProcessar = linksDeAnuncios.take(totalAnuncios).toList();
    
    print("\nProcessando ${linksParaProcessar.length} anúncios para extração de conteúdo...");
    for (String linkAnuncio in linksParaProcessar) {
      final textoAnuncio = await _extrairTodoTextoDoSite(linkAnuncio);
      resultadosFinais.add({
        'link': linkAnuncio,
        'texto': textoAnuncio,
      });
      await Future.delayed(const Duration(milliseconds: 500)); 
    }

    print("🎉 Extração de conteúdo finalizada!");
    return resultadosFinais;
  }
}