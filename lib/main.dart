import 'package:appinncatalogo/screens/cliente_screen.dart';
import 'package:appinncatalogo/screens/access_temp_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/revendedor_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catálogo Simples',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: kIsWeb
          ? (Uri.base.queryParameters['temp'] != null
              ? AccessTempScreen(tempUid: Uri.base.queryParameters['temp']!)
              : const AuthWrapper())
          : const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const LoginScreen();

        final uid = snapshot.data!.uid;
        return FutureBuilder<Map<String, dynamic>?>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get().then((s) => s.data()),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final role = snap.data?['role'] ?? 'cliente';
            if (role == 'admin') return const AdminScreen();
            if (role == 'revendedor') return const RevendedorScreen();
            return const ClienteScreen();
          },
        );
      },
    );
  }
}