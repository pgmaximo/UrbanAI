import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference usuarios = FirebaseFirestore.instance.collection('usuarios');

  Future<void> cadastrarUsuario({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
  }) async {
    // Opcional: aqui você pode checar se o email já existe
    await usuarios.add({
      'Nome': nome,
      'Email': email,
      'Telefone': telefone,
      'Senha': senha, // Não recomendado salvar senha em texto puro
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }
}
