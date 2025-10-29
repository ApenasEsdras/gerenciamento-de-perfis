// screens/owner_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  bool _isLoading = false;
  String? _link;
  String? _lastDuration;

  Future<void> _gerarLink(int minutos, String label) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Faça login para gerar o link');
      return;
    }

    setState(() {
      _isLoading = true;
      _lastDuration = label;
    });

    try {
      await user.getIdToken(true);
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

      final result = await functions.httpsCallable('createTempLink').call({
        'docId': 'contrato_123',
        'minutes': minutos,
      });

      final url = result.data['url'] as String;
      setState(() => _link = url);

      final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent("Acesse o contrato ($label): $url")}';
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } on FirebaseFunctionsException catch (e) {
      _showSnack('Erro: ${e.message}');
    } catch (e) {
      _showSnack('Erro inesperado: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _gerarDadosTeste() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'nome': 'João Silva',
      'plano': 'Premium',
      'validade': '31/12/2025',
      'valor': 'R\$ 99,90',
      'status': 'Ativo',
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shared')
        .doc('contrato_123')
        .set(data);

    _showSnack('Dados de teste gerados!');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final durations = [
      ('1 min', 1),
      ('5 min', 5),
      ('1h', 60),
      ('24h', 1440),
      ('2 dias', 2880),
      ('7 dias', 10080),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dono do Contrato'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'Olá, ${user.email}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Gerar Link Temporário', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: durations.map((d) {
                final (label, min) = d;
                return SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _gerarLink(min, label),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _gerarDadosTeste,
              icon: const Icon(Icons.data_usage),
              label: const Text('Gerar Dados de Teste'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Gerando link...'),
                ],
              ),
            if (_link != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Link gerado!', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Validade: $_lastDuration'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://wa.me/?text=${Uri.encodeComponent("Acesse o contrato ($_lastDuration): $_link")}'),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar no WhatsApp'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}