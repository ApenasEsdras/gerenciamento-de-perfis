import 'package:appinncatalogo/firebase_options.dart';
import 'package:appinncatalogo/screens/catalog_share_screen.dart';
import 'package:appinncatalogo/screens/home_screen.dart';
import 'package:appinncatalogo/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingLinkId;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinkListener() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      final uri = Uri.tryParse(initialLink.toString());
      if (uri != null) _handleDeepLink(uri);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'app-innovaro-showcase.web.app' &&
        uri.path.startsWith('/share/')) {
      final linkId = uri.pathSegments.last;
      setState(() {
        _pendingLinkId = linkId;
      });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => CatalogShareScreen(linkId: linkId),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catálogos',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: _pendingLinkId != null
          ? CatalogShareScreen(linkId: _pendingLinkId!)
          : const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}