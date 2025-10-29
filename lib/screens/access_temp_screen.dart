import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cliente_screen.dart';

class AccessTempScreen extends StatefulWidget {
  final String tempUid;
  const AccessTempScreen({required this.tempUid, super.key});
  @override State<AccessTempScreen> createState() => _AccessTempScreenState();
}

class _AccessTempScreenState extends State<AccessTempScreen> {
  bool _loading = true;
  String? _erro;
  String? _liberadoPor;
  DateTime? _expiraEm;

  @override
  void initState() {
    super.initState();
    _autenticar();
  }

  Future<void> _autenticar() async {
    try {
      // URL da função onRequest (GET com query param)
      final url = Uri.parse(
        'https://southamerica-east1-app-innovaro-showcase.cloudfunctions.net/getTokenTemporario?temp=${widget.tempUid}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await FirebaseAuth.instance.signInWithCustomToken(token);

        // Busca dados do usuário externo
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.tempUid)
            .get();
        final userData = doc.data()!;
        final criadoPor = userData['criadoPor'] as String;
        final adminSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(criadoPor)
            .get();

        setState(() {
          _liberadoPor = adminSnap.data()?['nome'] ?? 'Admin';
          _expiraEm = (userData['expiresAt'] as Timestamp).toDate();
        });
      } else {
        throw Exception('Erro ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Erro na autenticação: $e'); // LOG PARA DEBUG
      setState(() => _erro = "Link inválido ou expirado: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_erro != null) return Scaffold(body: Center(child: Text(_erro!)));
    return ClienteScreen(liberadoPor: _liberadoPor, expiraEm: _expiraEm);
  }
}