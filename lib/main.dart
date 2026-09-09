import 'dart:async';

import 'package:flutter/material.dart';

import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? bootstrapError;
  try {
    await initSupabase().timeout(const Duration(seconds: 12));
  } on TimeoutException {
    bootstrapError = 'Tempo esgotado ao conectar ao Supabase.';
  } catch (error) {
    bootstrapError = error.toString();
  }

  runApp(CobrApp(bootstrapError: bootstrapError));
}

class CobrApp extends StatelessWidget {
  const CobrApp({super.key, this.bootstrapError});

  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CobrApp Supabase',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(bootstrapError: bootstrapError),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.bootstrapError});

  final String? bootstrapError;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  static const pages = <Widget>[
    _PlaceholderPage(title: 'Início', icon: Icons.dashboard_outlined),
    _PlaceholderPage(title: 'Clientes', icon: Icons.people_outline),
    _PlaceholderPage(
      title: 'Empréstimos',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _PlaceholderPage(title: 'Cobranças', icon: Icons.event_available_outlined),
    _PlaceholderPage(title: 'Documentos', icon: Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CobrApp Supabase')),
      body: Column(
        children: [
          if (widget.bootstrapError != null)
            MaterialBanner(
              content: const Text(
                'Supabase ainda não foi configurado neste APK. A interface continua disponível para validação.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(widget.bootstrapError!)),
                    );
                  },
                  child: const Text('DETALHES'),
                ),
              ],
            ),
          Expanded(child: pages[index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Empréstimos',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            label: 'Cobranças',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            label: 'Documentos',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}
