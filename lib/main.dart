import 'dart:async';

import 'package:flutter/material.dart';

import 'core/supabase_config.dart';
import 'features/collections/collections_page.dart';
import 'features/customers/customers_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/documents/documents_page.dart';
import 'features/loans/loans_page.dart';

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

  late final pages = <Widget>[
    const DashboardPage(),
    const CustomersPage(),
    const LoansPage(),
    const CollectionsPage(),
    const DocumentsPage(),
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
