import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:urbanai/pages/MapPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:urbanai/main.dart'; // Para AppColors

class ImovelCard extends StatefulWidget {
  final Map<String, dynamic> cardData;
  const ImovelCard({super.key, required this.cardData});

  @override
  State<ImovelCard> createState() => _ImovelCardState();
}

class _ImovelCardState extends State<ImovelCard> {
  bool _favoritado = false;
  bool _isDescricaoExpandida = false;

  @override
  void initState() {
    super.initState();
    _verificarFavoritoInicial();
  }

  Future<void> _verificarFavoritoInicial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final linkAnuncio = widget.cardData['link_anuncio'] as String?;
    if (linkAnuncio == null || linkAnuncio.isEmpty) return;

    final docId = linkAnuncio.replaceAll(RegExp(r'[^\w]'), '_');
    final docRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid).collection('Favoritos').doc(docId);
    
    final doc = await docRef.get();
    if (doc.exists && mounted) {
      setState(() => _favoritado = true);
    }
  }
  
  Future<void> _toggleFavorito() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Mostra mensagem se o usuário não estiver logado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa estar logado para favoritar.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final linkAnuncio = widget.cardData['link_anuncio'] as String?;
    if (linkAnuncio == null || linkAnuncio.isEmpty) return;

    final docId = linkAnuncio.replaceAll(RegExp(r'[^\w]'), '_');
    final docRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid).collection('Favoritos').doc(docId);

    final novoEstado = !_favoritado;
    setState(() => _favoritado = novoEstado);

    try {
      if (novoEstado) {
        await docRef.set(widget.cardData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imóvel adicionado aos favoritos!'), backgroundColor: Colors.green),
        );
      } else {
        await docRef.delete();
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imóvel removido dos favoritos.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() => _favoritado = !novoEstado); // Reverte em caso de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar favoritos: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _launchURL(String urlString) async {
    String cleanUrlString = urlString;
    final questionMarkIndex = urlString.indexOf('?');
    if (questionMarkIndex != -1) {
      cleanUrlString = urlString.substring(0, questionMarkIndex);
    }
    final Uri url = Uri.parse(cleanUrlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Não foi possível abrir a URL: $cleanUrlString');
    }
  }
  
  // Widget auxiliar para os ícones de características
  Widget _buildFeatureIcon(IconData icon, String? value, String label) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        FaIcon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(height: 4),
        Text('$value $label', style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }

  // Novo widget para exibir quartos e suítes juntos
  Widget _buildRoomFeature() {
    final quartos = widget.cardData['quartos']?.toString();
    final suites = widget.cardData['quartos_suites']?.toString();

    if (quartos == null || quartos.isEmpty) return const SizedBox.shrink();

    String displayText = '$quartos Quartos';
    if (suites != null && suites.isNotEmpty && suites != '0') {
      displayText += ' ($suites Suíte)';
    }

    return Column(
      children: [
        const FaIcon(FontAwesomeIcons.bed, color: AppColors.secondary, size: 20),
        const SizedBox(height: 4),
        Text(displayText, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extração segura dos dados
    final titulo = widget.cardData['titulo'] as String? ?? 'Título não disponível';
    final endereco = widget.cardData['endereco'] as String? ?? '';
    final preco = widget.cardData['preco'] as String? ?? 'Preço a consultar';
    final precoCondominio = widget.cardData['preço_condominio'] as String?;
    final iptu = widget.cardData['iptu'] as String?;
    final tamanho = (widget.cardData['tamanho_m2'] as String?)?.replaceAll(RegExp(r'[^0-9]'), '');
    final banheiros = widget.cardData['banheiros']?.toString();
    final vagas = widget.cardData['vagas_garagem']?.toString();
    final linkAnuncio = widget.cardData['link_anuncio'] as String?;
    final descricao = widget.cardData['descricao_completa'] as String? ?? 'Sem descrição.';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 40.0),
                  child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(height: 4),
                if (endereco.isNotEmpty)
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.mapMarkerAlt, color: Colors.grey, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(endereco, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(preco, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                if (precoCondominio != null && precoCondominio.isNotEmpty)
                  Text("Condomínio: $precoCondominio", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                if (iptu != null && iptu.isNotEmpty)
                  Text("IPTU: $iptu", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFeatureIcon(FontAwesomeIcons.rulerCombined, tamanho, 'm²'),
                    _buildRoomFeature(), // NOVO WIDGET PARA QUARTOS E SUÍTES
                    _buildFeatureIcon(FontAwesomeIcons.bath, banheiros, 'Banheiros'),
                    _buildFeatureIcon(FontAwesomeIcons.car, vagas, 'Vagas'),
                  ],
                ),
                const SizedBox(height: 16),
                if (descricao.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Descrição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Text(
                      descricao,
                      maxLines: _isDescricaoExpandida ? null : 4,
                      overflow: _isDescricaoExpandida ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.5),
                    ),
                  ),
                  if (descricao.length > 200)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        child: Text(_isDescricaoExpandida ? 'Ler menos' : 'Ler mais...'),
                        onPressed: () => setState(() => _isDescricaoExpandida = !_isDescricaoExpandida),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (endereco.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const FaIcon(FontAwesomeIcons.map, size: 16),
                          label: const Text('Ver no Mapa'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MapPage(address: endereco))),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        ),
                      ),
                    if (endereco.isNotEmpty && linkAnuncio != null && linkAnuncio.isNotEmpty)
                      const SizedBox(width: 10),
                    if (linkAnuncio != null && linkAnuncio.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const FaIcon(FontAwesomeIcons.externalLinkAlt, size: 16, color: Colors.white),
                          label: const Text('Anúncio', style: TextStyle(color: Colors.white)),
                          onPressed: () => _launchURL(linkAnuncio),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: FaIcon(
                _favoritado ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                color: _favoritado ? Colors.redAccent : Colors.grey.shade400,
                size: 24,
              ),
              onPressed: _toggleFavorito,
              tooltip: _favoritado ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
            ),
          ),
        ],
      ),
    );
  }
}