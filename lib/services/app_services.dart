class AppServices {
  static final AppServices _instance = AppServices._internal();
  factory AppServices() => _instance;
  AppServices._internal();

  final List<Map<String, String>> _historicoConversa = [];

  /// Adiciona uma mensagem ao histórico com role: system, user ou assistant
  void salvarMensagem(String role, String content) {
    _historicoConversa.add({
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Retorna o histórico completo (sem possibilidade de modificação externa)
  List<Map<String, String>> getHistoricoConversa() =>
      List.unmodifiable(_historicoConversa);

  void limparHistorico() {
    _historicoConversa.clear();
  }

  /// Garante que o system prompt esteja sempre no início do histórico
  void garantirSystemPrompt(String prompt) {
    if (_historicoConversa.isEmpty ||
        _historicoConversa.first['role'] != 'system') {
      salvarMensagem('system', prompt);
    }
  }
}
