import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CadastroUsuarioScreen extends StatefulWidget {
  const CadastroUsuarioScreen({super.key});

  @override
  State<CadastroUsuarioScreen> createState() => _CadastroUsuarioScreenState();
}

class _CadastroUsuarioScreenState extends State<CadastroUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  String isPerfil = 'cliente';
  bool _loading = false;

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('cadastrarUsuario');
      await callable.call({
        'email': _emailCtrl.text.trim(),
        'senha': _senhaCtrl.text,
        'nome': _nomeCtrl.text.trim(),
        'isPerfil': isPerfil,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuário cadastrado com sucesso!")),
        );
        _formKey.currentState!.reset();
        _emailCtrl.clear();
        _senhaCtrl.clear();
        _nomeCtrl.clear();
      }
    } on FirebaseFunctionsException catch (e) {
      String msg = e.message ?? "Erro desconhecido";
      if (e.code == 'already-exists') msg = "Este email já está em uso.";
      if (e.code == 'permission-denied') msg = "Você não tem permissão.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastrar Usuário")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: "Nome completo",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Obrigatório" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.contains('@') ? null : "Email inválido",
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _senhaCtrl,
                decoration: const InputDecoration(
                  labelText: "Senha (mín. 6 caracteres)",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => v!.length >= 6 ? null : "Mínimo 6 caracteres",
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: isPerfil,
                decoration: const InputDecoration(
                  labelText: "Tipo de usuário",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "admin",
                    child: Text("Administrador"),
                  ),
                  DropdownMenuItem(
                    value: "revendedor",
                    child: Text("Revendedor"),
                  ),
                  DropdownMenuItem(value: "cliente", child: Text("Cliente")),
                ],
                onChanged: (v) => setState(() => isPerfil = v!),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _cadastrar,
                        child: const Text("CADASTRAR USUÁRIO"),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
