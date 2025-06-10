import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:urbanai/main.dart'; // Para AppColors
import 'package:urbanai/pages/homePage.dart'; // Importe a sua HomePage!

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
      return Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.secondary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goToHomePage,
          ),
        ),
        body: const Center(
          child: Text("Usuário não logado."),
        ),
      );
    }

    final favoritosRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user!.uid)
        .collection('Favoritos');

    return WillPopScope(
      onWillPop: () async {
        _goToHomePage();
        return false; // impede o pop padrão
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos'),
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
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum imóvel favoritado ainda.',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 18,
                  ),
                ),
              );
            }
            final favoritos = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: favoritos.length,
              itemBuilder: (context, index) {
                final doc = favoritos[index];

                // --- INÍCIO DA CORREÇÃO ---
                // 1. Pega o mapa de dados do documento de forma segura.
                final data = doc.data() as Map<String, dynamic>?;

                // 2. Verifica se os dados existem antes de tentar usá-los.
                if (data == null) {
                  // Retorna um widget vazio ou de erro se o documento não tiver dados.
                  return const SizedBox.shrink(); 
                }
                
                // 3. Acessa os campos a partir do mapa, fornecendo valores padrão se faltarem.
                final nome = data['nome'] as String? ?? 'Imóvel sem nome';
                final link = data['link'] as String? ?? 'Link não disponível';
                // --- FIM DA CORREÇÃO ---

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  elevation: 4,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    title: Text(
                      nome, // Usa a variável segura
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    // Adicionando o subtítulo para mostrar o link, se existir
                    subtitle: Text(
                      link, // Usa a variável segura
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      tooltip: 'Remover dos favoritos',
                      onPressed: () async {
                        await doc.reference.delete();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Imóvel removido dos favoritos!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              }
            );
          }
        )
      )
    );
  }
}
      