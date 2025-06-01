import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ScrapeScript.dart'; // seu arquivo com a classe ScrapeService
import 'package:flutter/foundation.dart';
import 'secret.dart' as secret;

class ScriptTestPage extends StatefulWidget {
  @override
  _ScriptTestPageState createState() => _ScriptTestPageState();
}

class _ScriptTestPageState extends State<ScriptTestPage> {
  final TextEditingController _controller = TextEditingController();
  String resultText = "";

  Future<void> handleScraping() async {
    final apiKey = kIsWeb ? secret.apiKeySerpApi : dotenv.env['API_KEY'] ?? '';
    final service = ScrapeService(apiKey: apiKey);

    final query = _controller.text;
    if (query.isEmpty) return;

    final links = await service.getGoogleLinks(query);

    if (links.isNotEmpty) {
      final firstLink = links[0];
      final data = await service.scrapeWebsite(firstLink);

      setState(() {
        resultText =
            '🔗 $firstLink\n\n📄 ${data['title']}\n\n📝 ${(data['paragraphs'] as List).take(3).join("\n\n")}';
      });
    } else {
      setState(() {
        resultText = "Nenhum resultado encontrado";
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scraper Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Digite sua pesquisa'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleScraping,
              child: Text('Buscar'),
            ),
            SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: Text(resultText))),
          ],
        ),
      ),
    );
  }
}
