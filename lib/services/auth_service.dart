import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:urbanai/services/app_services.dart';
import 'package:urbanai/services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppServices _appServices = AppServices();
  final FirestoreService _firestoreService = FirestoreService();

  /// Função unificada para login com Google que funciona em Web e plataformas nativas.
  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    UserCredential? userCredential;

    try {
      if (kIsWeb) {
        // --- FLUXO PARA WEB ---
        final googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // --- FLUXO PARA DESKTOP/MOBILE (WINDOWS, ANDROID, IOS) ---
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null; // Usuário cancelou
        
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      // --- LÓGICA COMUM APÓS O LOGIN (PARA AMBAS AS PLATAFORMAS) ---
      if (userCredential != null && userCredential.user != null) {
        final user = userCredential.user!;
        // Salva/Atualiza dados no Firestore
        await _firestoreService.cadastrarOuAtualizarUsuario(
          uid: user.uid,
          email: user.email,
          nome: user.displayName,
          photoURL: user.photoURL,
        );
        // Define o ID da conversa para o histórico de chat
        _appServices.setConversationId(user.uid);
        print("Login com Google bem-sucedido para UID: ${user.uid}");
      }
      return userCredential;

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Ocorreu um erro durante o login com Google.";
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = "Já existe uma conta com este e-mail usando outro método.";
      } else if (e.code == 'popup-closed-by-user' && kIsWeb) {
        errorMessage = "O pop-up de login foi fechado.";
      }
      _showErrorSnackbar(context, errorMessage);
      return null;
    } catch (e) {
      if (kDebugMode) print("Erro genérico no login com Google: $e");
      _showErrorSnackbar(context, "Ocorreu um erro inesperado.");
      return null;
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}