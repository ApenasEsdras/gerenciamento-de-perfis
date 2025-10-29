import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class ClienteScreen extends StatelessWidget {
  final String? liberadoPor;
  final DateTime? expiraEm;

  const ClienteScreen({super.key, this.liberadoPor, this.expiraEm});

  @override
  Widget build(BuildContext context) {
    final isExterno = FirebaseAuth.instance.currentUser?.uid.startsWith('temp_') == true;

    return Scaffold(
      appBar: AppBar(title: const Text("Cliente"), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
      ]),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("CLIENTE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (isExterno) ...[
              const Text("CLIENTE EXTERNO", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            if (liberadoPor != null) Text("Liberado por: $liberadoPor"),
            if (expiraEm != null)
              Text("Válido até: ${DateFormat('dd/MM HH:mm').format(expiraEm!)}", style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}