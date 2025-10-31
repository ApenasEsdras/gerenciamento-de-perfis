// screens/home_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:appinncatalogo/screens/cadastro.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userRole;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      userRole = doc.data()?['isPerfil'];
      isLoading = false;
    });
  }

  Future<void> _shareCatalog(String catalogId, String catalogName) async {
    if (userRole != 'admin' && userRole != 'revendedor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Você não tem permissão para compartilhar."),
        ),
      );
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('generateCatalogLink');

      final result = await callable.call({'catalogId': catalogId});
      final link = result.data['link'] as String;

      // MENSAGEM PADRÃO
      final message =
          'Confira o catálogo *$catalogName*:\n\n$link\n\nVálido por 24h';

      // PLATAFORMA: MOBILE → SHARE NATIVO
      if (!kIsWeb) {
        await Share.share(message, subject: catalogName);
        return;
      }

      // PLATAFORMA: WEB → CAMPO + COPIAR
      if (kIsWeb) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Link do Catálogo"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: link),
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Link (clique em Copiar)",
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text("COPIAR LINK"),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text("Link copiado!")),
                        );
                        Navigator.of(ctx).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("FECHAR"),
              ),
            ],
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      String msg = e.message ?? "Erro ao gerar link.";
      if (e.code == 'permission-denied') msg = "Você não tem permissão.";
      if (e.code == 'not-found') msg = "Catálogo não encontrado.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userRole == 'admin'
              ? "Admin"
              : userRole == 'revendedor'
              ? "Revendedor"
              : "Cliente",
        ),
        actions: [
          if (userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CadastroUsuarioScreen(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('catalogos')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("Nenhum catálogo disponível."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Sem nome';
              final items =
                  (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

              final canShare = userRole == 'admin' || userRole == 'revendedor';

              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${items.length} itens"),
                  trailing: canShare
                      ? IconButton(
                          icon: const Icon(Icons.share, color: Colors.indigo),
                          onPressed: () => _shareCatalog(docs[index].id, name),
                        )
                      : null,
                  children: items.map((item) {
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: item['imageUrl'] ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(
                            width: 50,
                            height: 50,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                      title: Text(item['name'] ?? ''),
                      subtitle: Text(
                        "R\$ ${(item['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}\n"
                        "Tam: ${(item['sizes'] as List?)?.join(', ') ?? 'N/A'}",
                      ),
                      isThreeLine: true,
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
