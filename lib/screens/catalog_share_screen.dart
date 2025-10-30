// catalog_share_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class CatalogShareScreen extends StatefulWidget {
  final String linkId;
  const CatalogShareScreen({super.key, required this.linkId});

  @override
  State<CatalogShareScreen> createState() => _CatalogShareScreenState();
}

class _CatalogShareScreenState extends State<CatalogShareScreen> {
  Map<String, dynamic>? catalog;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final uri = Uri.https(
        'southamerica-east1-seu-projeto.cloudfunctions.net',
        '/getCatalogByLink',
        {'linkId': widget.linkId},
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          catalog = json['catalog'];
          loading = false;
        });
      } else if (response.statusCode == 410) {
        setState(() {
          error = "Este link expirou (24h).";
          loading = false;
        });
      } else {
        setState(() {
          error = "Catálogo não encontrado.";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Erro de conexão.";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Catálogo Compartilhado")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(fontSize: 18)))
              : _buildCatalog(),
    );
  }

  Widget _buildCatalog() {
    final items = catalog!['items'] as List<dynamic>;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(catalog!['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: Column(
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: item['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("R\$ ${(item['price'] as num).toStringAsFixed(2)}"),
                          Text("Tam: ${(item['sizes'] as List).join(', ')}"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}