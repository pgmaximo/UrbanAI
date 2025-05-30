//classe simples para representar os dados do usuário.
class UserData {
  final String uid;
  final String email;
  final String? nome;
  final String? telefone;
  final String? photoURL;

  UserData({
    required this.uid,
    required this.email,
    this.nome,
    this.telefone,
    this.photoURL,
  });

  // Fábrica para criar UserData a partir de um Map (vindo do Firestore)
  factory UserData.fromMap(Map<String, dynamic> map, String uid) {
    return UserData(
      uid: uid, // uid geralmente é o ID do documento, não dentro do mapa de dados
      email: map['email'] as String? ?? 'Email não disponível',
      nome: map['nome'] as String?,
      telefone: map['telefone'] as String?,
      photoURL: map['photoURL'] as String?,
    );
  }

  // Método para facilitar a exibição do nome (com fallback)
  String get displayName {
    return nome != null && nome!.isNotEmpty ? nome! : email;
  }
}