import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference usuarios = FirebaseFirestore.instance.collection('usuarios');

  Future<void> cadastrarUsuario({
    required String uid,
    required String nome,
    required String email,
    required String telefone,
  }) async {
    await usuarios.doc(uid).set({
      'Nome': nome,
      'Email': email,
      'Telefone': telefone,
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }
}
