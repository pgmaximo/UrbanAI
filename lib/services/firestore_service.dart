import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:urbanai/services/user_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _conversationId = ''; // Para o histórico de chat

  // --- Gerenciamento do ID da Conversa (para o chat) ---
  void setConversationId(String id) {
    _conversationId = id;
    print("FirestoreService: Conversation ID definido como -> $_conversationId");
  }

  String getConversationId() => _conversationId;

  // --- Métodos do Histórico de Chat (existentes) ---
  Future<void> adicionarMensagemAoHistorico(Map<String, String> mensagem) async {
    if (_conversationId.isEmpty) {
      print("FirestoreService: ID da conversa não definido. Mensagem (chat) não salva.");
      return;
    }
    try {
      final Map<String, dynamic> mensagemParaSalvar = {
        'role': mensagem['role'],
        'content': mensagem['content'],
        'timestamp': FieldValue.serverTimestamp(),
      };
      await _db
          .collection('conversas')
          .doc(_conversationId) // Usa o _conversationId (que será o UID do usuário)
          .collection('mensagens')
          .add(mensagemParaSalvar);
    } catch (e) {
      print("Erro ao salvar mensagem (chat) no Firestore: $e");
    }
  }

  Future<List<Map<String, String>>> carregarHistoricoConversa() async {
    if (_conversationId.isEmpty) {
      print("FirestoreService: ID da conversa não definido. Histórico (chat) não carregado.");
      return [];
    }
    try {
      final querySnapshot = await _db
          .collection('conversas')
          .doc(_conversationId) // Usa o _conversationId
          .collection('mensagens')
          .orderBy('timestamp', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        Timestamp? serverTimestamp = data['timestamp'] as Timestamp?;
        return {
          'role': data['role'] as String? ?? 'unknown_role',
          'content': data['content'] as String? ?? '',
          'timestamp': serverTimestamp?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print("Erro ao carregar histórico (chat) do Firestore: $e");
      return [];
    }
  }

  Future<void> limparHistoricoConversaAtual() async {
    if (_conversationId.isEmpty) {
      print("FirestoreService: ID da conversa não definido. Histórico (chat) não limpo.");
      return;
    }
    try {
      // ... (código para limpar mensagens da subcoleção 'mensagens') ...
      // Este método está correto como antes.
      final snapshot = await _db
          .collection('conversas')
          .doc(_conversationId)
          .collection('mensagens')
          .get();
      WriteBatch batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("Histórico de chat da conversa '$_conversationId' limpo no Firestore.");
    } catch (e) {
      print("Erro ao limpar histórico (chat) no Firestore: $e");
    }
  }

    Future<UserData?> getUserData(String uid) async {
    if (uid.isEmpty) {
      print("FirestoreService: UID do usuário está vazio. Não é possível buscar dados.");
      return null;
    }
    try {
      DocumentSnapshot docSnapshot = await _db.collection('usuarios').doc(uid).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Converte o Map do Firestore para um objeto UserData
        return UserData.fromMap(docSnapshot.data()! as Map<String, dynamic>, uid);
      } else {
        print("FirestoreService: Documento do usuário com UID $uid não encontrado.");
        return null; // Usuário não encontrado
      }
    } catch (e) {
      print("Erro ao buscar dados do usuário (UID: $uid) no Firestore: $e");
      return null; // Erro na busca
    }
  }


  // --- MÉTODO ATUALIZADO: Cadastrar ou Atualizar Dados do Usuário ---
  /// Salva ou atualiza os dados de um usuário na coleção 'usuarios'.
  ///
  /// [uid] O ID único do usuário (do Firebase Authentication).
  /// [email] O email do usuário.
  /// [nome] O nome do usuário (opcional).
  /// [telefone] O telefone do usuário (opcional).
  /// [photoURL] A URL da foto de perfil do usuário (opcional, útil para login social).
  /// [outrosDados] Um mapa com quaisquer outros dados personalizados.
  Future<void> cadastrarOuAtualizarUsuario({
    required String uid,
    String? email, // Email geralmente não é editável pelo usuário diretamente
    String? nome,
    String? telefone,
    String? photoURL,
    Map<String, dynamic>? outrosDados,
  }) async {
    try {
      DocumentReference userDocRef = _db.collection('usuarios').doc(uid);
      Map<String, dynamic> dadosUsuario = {
        // 'uid': uid, // Não precisa estar no mapa de dados se já é o ID do doc
        // 'email': email, // Normalmente não se atualiza o email por aqui
      };

      if (nome != null) dadosUsuario['nome'] = nome;
      if (telefone != null) dadosUsuario['telefone'] = telefone;
      if (photoURL != null) dadosUsuario['photoURL'] = photoURL;
      // Sempre atualiza o timestamp do último login/modificação
      dadosUsuario['ultimaModificacao'] = FieldValue.serverTimestamp();

      if (outrosDados != null) {
        dadosUsuario.addAll(outrosDados);
      }
      
      // Se o email for fornecido (ex: no cadastro inicial ou se realmente for editável)
      if (email != null) dadosUsuario['email'] = email;


      // Se o mapa 'dadosUsuario' estiver vazio (nenhum campo foi alterado/passado),
      // podemos evitar uma escrita desnecessária, a menos que queiramos apenas atualizar 'ultimaModificacao'.
      // No entanto, como 'ultimaModificacao' está sempre presente, a escrita ocorrerá.
      // Se 'ultimaModificacao' não for desejada em todas as atualizações, ajuste esta lógica.

      await userDocRef.set(dadosUsuario, SetOptions(merge: true));
      print('Dados do usuário (UID: $uid) atualizados no Firestore.');
    } catch (e) {
      print('Erro ao atualizar dados do usuário (UID: $uid) no Firestore: $e');
      throw e; // Relançar para tratar na UI
    }
  }


}