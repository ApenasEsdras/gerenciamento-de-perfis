// admin_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // Import share_plus

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _gerar(BuildContext ctx) async {
    try {
      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );
      final callable = functions.httpsCallable('gerarLinkTemporario');

      final result = await callable.call();
      final url = result.data['url'] as String;
      print("Link gerado: $url"); // LOG PARA DEBUG

      // Share the link via the native share sheet
      await Share.share(
        'Acesse os produtos em: $url',
        subject: 'Link Temporário de Acesso', // Optional for email
      );
    } catch (e) {
      print("ERRO ao gerar link: $e");
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text("Erro ao gerar link: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _gerar(context),
          child: const Text("Gerar Link Temporário (24h)"),
        ),
      ),
    );
  }
}
