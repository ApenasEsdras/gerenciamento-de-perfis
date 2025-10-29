import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RevendedorScreen extends StatelessWidget {
  const RevendedorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Revendedor"), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
      ]),
      body: const Center(child: Text("REVENDEDOR", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
    );
  }
}