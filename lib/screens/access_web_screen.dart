// screens/access_web_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AccessWebScreen extends StatefulWidget {
  const AccessWebScreen({super.key});

  @override
  State<AccessWebScreen> createState() => _AccessWebScreenState();
}

class _AccessWebScreenState extends State<AccessWebScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  int _secondsLeft = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadFromUrl();
  }

  Future<void> _loadFromUrl() async {
    final uri = Uri.base;
    final accessId = uri.queryParameters['aid'];
    if (accessId == null) {
      setState(() => _error = 'Link inválido');
      return;
    }

    try {
      // 1. Chama a função para pegar o token
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await functions.httpsCallable('getTempToken').call({'accessId': accessId});
      final token = result.data['token'] as String;
      await FirebaseAuth.instance.signInWithCustomToken(token);

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 2. Busca os dados do contrato
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('shared')
          .doc('contrato_123')
          .get();

      if (!doc.exists) {
        setState(() => _error = 'Dados não encontrados');
        return;
      }

      // 3. Busca o tempo de expiração
      final accessSnap = await FirebaseFirestore.instance
          .collection('tempAccess')
          .doc(accessId)
          .get();

      if (!accessSnap.exists) {
        setState(() => _error = 'Link inválido');
        return;
      }

      final expiresAt = (accessSnap.data()!['expiresAt'] as Timestamp).toDate();
      final now = DateTime.now();
      final diff = expiresAt.difference(now).inSeconds;

      if (diff <= 0) {
        setState(() => _error = 'Link expirado');
        return;
      }

      // 4. Atualiza UI
      setState(() {
        _data = doc.data();
        _secondsLeft = diff;
      });

      // 5. Inicia contagem regressiva
      _startCountdown();
    } catch (e) {
      setState(() => _error = 'Link expirado ou inválido');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft--;
      });

      if (_secondsLeft <= 0) {
        timer.cancel();
        FirebaseAuth.instance.signOut();
        setState(() => _error = 'Acesso expirado');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso Temporário'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _error != null
              ? _buildError()
              : _data != null
                  ? _buildSuccess()
                  : const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => launchUrl(Uri.parse('https://app-innovaro-showcase.web.app')),
          child: const Text('Voltar ao início'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final minutes = (_secondsLeft / 60).floor();
    final seconds = _secondsLeft % 60;
    final timeText = minutes > 0
        ? '$minutes min ${seconds}s'
        : '$seconds segundos';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contrato Compartilhado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            ..._data!.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(e.value.toString())),
                ],
              ),
            )).toList(),
            const Divider(height: 30),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tempo restante: $timeText',
                  style: TextStyle(
                    fontSize: 16,
                    color: _secondsLeft <= 30 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}