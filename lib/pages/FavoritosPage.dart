import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:urbanai/pages/homePage.dart';
import 'package:urbanai/widget/imovel_card.dart'; 

class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  final user = FirebaseAuth.instance.currentUser;

  void _goToHomePage() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      // Tela para usuário não logado (sem alterações)
      return Scaffold(
        appBar: AppBar(title: const Text('Favoritos'), /* ... */),
        body: const Center(child: Text("Usuário não logado.")),
      );
    }

    final favoritosRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user!.uid)
        .collection('Favoritos');

    return WillPopScope(
      onWillPop: () async {
        _goToHomePage();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meus Favoritos'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.secondary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToHomePage,
          ),
        ),
        backgroundColor: AppColors.background,
        body: StreamBuilder<QuerySnapshot>(
          stream: favoritosRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
               return Center(child: Text("Ocorreu um erro: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum imóvel favoritado ainda.',
                  style: TextStyle(color: AppColors.secondary, fontSize: 18),
                ),
              );
            }
            
            final favoritos = snapshot.data!.docs;
            
            return ListView.builder(
              // Usamos um padding um pouco menor para o card ter mais espaço
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              itemCount: favoritos.length,
              itemBuilder: (context, index) {
                final doc = favoritos[index];
                final data = doc.data() as Map<String, dynamic>?;

                if (data == null) {
                  return const SizedBox.shrink(); 
                }
                
                // ### MUDANÇA PRINCIPAL AQUI ###
                // Em vez de construir um ListTile simples...
                // return Card( child: ListTile(...) );

                // ...nós simplesmente usamos nosso widget ImovelCard completo!
                return ImovelCard(cardData: data);
              },
            );
          },
        ),
      ),
    );
  }
}