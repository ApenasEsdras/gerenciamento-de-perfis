// screens/home_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _gerarLink(BuildContext context) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await functions.httpsCallable('gerarLinkTemporario').call();
      final url = result.data['url'] as String;

      await Share.share(
        'Acesse os produtos em: $url',
        subject: 'Link Temporário de Acesso',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao gerar link: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isExterno = user.uid.startsWith('temp_');

    return Scaffold(
      appBar: AppBar(
        title: Text(isExterno ? "Acesso Temporário" : "Catálogo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Erro ao carregar perfil"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final role = data['role'] ?? 'cliente';
          final criadoPorUid = data['criadoPor'] as String?;
          final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // === TÍTULO DO PERFIL ===
                Text(
                  switch (role) {
                    'admin' => "ADMINISTRADOR",
                    'revendedor' => "REVENDEDOR",
                    _ => isExterno ? "CLIENTE EXTERNO" : "CLIENTE",
                  },
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // === INFORMAÇÕES DO ACESSO EXTERNO ===
                if (isExterno) ...[
                  FutureBuilder<DocumentSnapshot>(
                    future: criadoPorUid != null
                        ? FirebaseFirestore.instance.collection('users').doc(criadoPorUid).get()
                        : null,
                    builder: (context, adminSnap) {
                      final adminNome = (adminSnap.hasData && adminSnap.data!.exists)
                          ? ((adminSnap.data!.data() as Map<String, dynamic>)['nome'] ?? 'Admin')
                          : 'Carregando...';
                      return Column(
                        children: [
                          Text("Liberado por: $adminNome", style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          if (expiresAt != null)
                            Text(
                              "Válido até: ${DateFormat('dd/MM HH:mm').format(expiresAt)}",
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],

                // === BOTÃO PARA ADMIN ===
                if (role == 'admin') ...[
                  ElevatedButton.icon(
                    onPressed: () => _gerarLink(context),
                    icon: const Icon(Icons.link),
                    label: const Text("Gerar Link Temporário (24h)"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // === CONTEÚDO PERSONALIZADO (exemplo) ===
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text("Bem-vindo!  ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(switch (role) {
                          'admin' => "Você gerencia o catálogo e acessos temporários.",
                          'revendedor' => "Você tem acesso aos produtos para revenda.",
                          _ => "Explore o catálogo de produtos.",
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}