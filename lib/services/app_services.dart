import 'package:urbanai/services/firestore_service.dart';

class AppServices {
  static final AppServices _instance = AppServices._internal();
  factory AppServices() => _instance;
  AppServices._internal();

  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, String>> _historicoConversaLocalCache = [];
  bool _historicoCarregado = false;

  void setConversationId(String id) {
    _firestoreService.setConversationId(id);
    _historicoConversaLocalCache.clear(); // Limpa o cache ao mudar de conversa
    _historicoCarregado = false; // Força recarregar
  }

  String getConversationId() => _firestoreService.getConversationId();

  Future<void> salvarMensagem(String role, String content) async {
    final mensagem = {
      'role': role,
      'content': content,
      // O timestamp do Firebase será a fonte da verdade para ordenação persistida.
      // O timestamp local pode ser usado para exibição imediata se necessário,
      // mas para o cache, usaremos o que vem do Firebase ou o atual para novas msgs.
      'timestamp': DateTime.now().toIso8601String(),
    };
    // Adiciona ao cache local para atualização rápida da UI
    if (_historicoCarregado) {
       _historicoConversaLocalCache.add(mensagem);
    }
    // Salva no Firebase (que usará seu próprio timestamp de servidor)
    await _firestoreService.adicionarMensagemAoHistorico({'role': role, 'content': content});
  }

  Future<List<Map<String, String>>> carregarHistoricoDoFirebase() async {
    _historicoConversaLocalCache = await _firestoreService.carregarHistoricoConversa();
    _historicoCarregado = true;
    return List.unmodifiable(_historicoConversaLocalCache);
  }

  List<Map<String, String>> getHistoricoConversaCache() {
    return List.unmodifiable(_historicoConversaLocalCache);
  }

  Future<void> limparHistorico() async {
    _historicoConversaLocalCache.clear();
    _historicoCarregado = false;
    await _firestoreService.limparHistoricoConversaAtual();
  }

  List<Map<String, String>> getHistoricoParaIA(String systemPromptContent) {
    // Usa o cache local, que deve ser preenchido por carregarHistoricoDoFirebase()
    List<Map<String, String>> historicoParaIA = List.from(_historicoConversaLocalCache);

    // Remove qualquer prompt de sistema existente para evitar duplicação se o prompt mudar
    historicoParaIA.removeWhere((msg) => msg['role'] == 'system');

    // Adiciona o prompt do sistema mais atual no início
    historicoParaIA.insert(0, {
      'role': 'system',
      'content': systemPromptContent,
      'timestamp': DateTime.now().toIso8601String() // Timestamp para consistência
    });
    return List.unmodifiable(historicoParaIA);
  }
}