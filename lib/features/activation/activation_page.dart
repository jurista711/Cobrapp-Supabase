import 'package:flutter/material.dart';

import '../../core/license_service.dart';

class ActivationGate extends StatefulWidget {
  const ActivationGate({super.key, required this.child, this.bootstrapError});

  final Widget child;
  final String? bootstrapError;

  @override
  State<ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<ActivationGate> {
  final licenseService = const LicenseService();
  bool checking = true;
  bool authorized = false;
  String? message;

  @override
  void initState() {
    super.initState();
    validate();
  }

  Future<void> validate() async {
    setState(() {
      checking = true;
      message = null;
    });

    try {
      final result = await licenseService.validateDevice();
      if (!mounted) return;
      setState(() {
        authorized = result.ok;
        message = result.ok ? null : result.message;
        checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        authorized = false;
        message = 'Não foi possível validar a licença: $error';
        checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Validando aparelho...'),
            ],
          ),
        ),
      );
    }

    if (authorized) {
      return widget.child;
    }

    return ActivationPage(
      initialMessage: widget.bootstrapError ?? message,
      onActivated: validate,
    );
  }
}

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key, this.initialMessage, required this.onActivated});

  final String? initialMessage;
  final VoidCallback onActivated;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final licenseService = const LicenseService();
  final codeController = TextEditingController();
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    message = widget.initialMessage;
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> activateDevice() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() => message = 'Digite o código de ativação.');
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final result = await licenseService.activateDevice(code);
      if (!mounted) return;
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        widget.onActivated();
      } else {
        setState(() => message = result.message);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => message = 'Não foi possível ativar: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        'Ativar aparelho',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Digite o código de ativação para liberar este aparelho. Depois disso o app entra direto, sem tela de login.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código de ativação',
                          hintText: 'Ex: COBRAPP-TESTE-001',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        onSubmitted: (_) => loading ? null : activateDevice(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: loading ? null : activateDevice,
                        icon: loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lock_open_outlined),
                        label: Text(loading ? 'Ativando...' : 'Ativar'),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(message!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
