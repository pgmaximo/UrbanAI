import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

class ScrapeService {
  final String apiKey;

  ScrapeService({required this.apiKey});

  Future<List<String>> getGoogleLinks(String query, {int numResults = 5}) async {
    if (apiKey.isEmpty) {
      throw Exception("API_KEY está vazia");
    }

    // Add hl=pt-BR and gl=br to prioritize Brazilian Portuguese results
    final url = Uri.parse(
        "https://serpapi.com/search.json?q=$query&api_key=$apiKey&num=$numResults&hl=pt-BR&gl=br");

    try {
      final response = await http.get(url, headers: {
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      });

      if (response.statusCode != 200) {
        throw Exception("Erro na requisição: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (data.containsKey("organic_results")) {
        final List links = data["organic_results"];
        return links
            .map<String>((item) => item["link"].toString())
            .take(numResults)
            .toList();
      } else if (data.containsKey("knowledge_graph")) {
        final kg = data["knowledge_graph"];
        List<String> links = [];

        if (kg.containsKey("web_results")) {
          links.addAll(
              (kg["web_results"] as List).map((e) => e["link"].toString()));
        }
        if (kg.containsKey("designed_by_links")) {
          links.addAll(
              (kg["designed_by_links"] as List).map((e) => e["link"].toString()));
        }

        return links.take(numResults).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Erro na requisição: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> scrapeWebsite(String url) async {
    try {
      // Use a persistent HTTP client to handle cookies
      final client = http.Client();

      // Enhanced headers with pt-BR language preference
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://www.google.com.br/',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      };

      final response = await client.get(
        Uri.parse(url),
        headers: headers,
      );

      // Log response details for debugging
      if (response.statusCode != 200) {
        print("Erro ao buscar $url: ${response.statusCode}");
        print("Headers: ${response.headers}");
        print("Body: ${response.body.substring(0, 500)}...");
        throw Exception("Erro ao buscar o site: ${response.statusCode}");
      }

      // Parse with UTF-8 to handle Portuguese characters correctly
      final document = parser.parse(response.body, encoding: 'utf-8');
      final title =
          document.head?.getElementsByTagName('title').first.text ?? "Sem título";

      final paragraphs = document
          .getElementsByTagName('p')
          .map((p) => p.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      client.close();
      return {
        "title": title,
        "paragraphs": paragraphs,
      };
    } catch (e) {
      print("Erro ao fazer scraping de $url: $e");
      return {
        "title": null,
        "paragraphs": [],
      };
    }
  }

  // Utility method to scrape multiple URLs with rate limiting
  Future<List<Map<String, dynamic>>> scrapeMultipleWebsites(List<String> urls,
      {int delaySeconds = 2}) async {
    final results = <Map<String, dynamic>>[];

    for (var url in urls) {
      final result = await scrapeWebsite(url);
      results.add(result);
      // Add delay to avoid rate limiting
      await Future.delayed(Duration(seconds: delaySeconds));
    }

    return results;
  }
}