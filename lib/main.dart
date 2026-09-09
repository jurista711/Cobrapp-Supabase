import 'dart:async';

import 'package:flutter/material.dart';

import 'core/supabase_config.dart';
import 'features/cash/cash_page.dart';
import 'features/collections/collections_page.dart';
import 'features/customers/customers_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/documents/documents_page.dart';
import 'features/extra/extra_pages.dart';
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
      title: 'Roots Cobrança',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0618),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFFEC4899),
          tertiary: Color(0xFFEF4444),
          surface: Color(0xFF120A2B),
          onSurface: Color(0xFFF8F5FF),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF17102F),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  Widget? drawerPage;
  String drawerTitle = 'Roots Cobrança';

  late final pages = <Widget>[
    const DashboardPage(),
    const CustomersPage(),
    const LoansPage(),
    const CollectionsPage(),
    const CashPage(),
  ];

  final bottomTitles = const <String>[
    'Início',
    'Clientes',
    'Empréstimos',
    'Cobranças',
    'Caixa',
  ];

  void openDrawerPage(String title, Widget page) {
    Navigator.of(context).pop();
    setState(() {
      drawerTitle = title;
      drawerPage = page;
    });
  }

  void openMainPage(int value) {
    setState(() {
      index = value;
      drawerPage = null;
      drawerTitle = 'Roots Cobrança';
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTitle = drawerPage == null ? bottomTitles[index] : drawerTitle;
    return Scaffold(
      appBar: AppBar(title: Text(activeTitle == 'Início' ? 'Roots Cobrança' : activeTitle)),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 42),
                    SizedBox(height: 10),
                    Text('Roots Cobrança', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    Text('Gestão de empréstimos e cobranças'),
                  ],
                ),
              ),
              _DrawerItem(icon: Icons.dashboard_outlined, title: 'Início', onTap: () => openMainPage(0)),
              _DrawerItem(icon: Icons.people_outline, title: 'Clientes', onTap: () => openMainPage(1)),
              _DrawerItem(icon: Icons.account_balance_wallet_outlined, title: 'Empréstimos', onTap: () => openMainPage(2)),
              _DrawerItem(icon: Icons.event_available_outlined, title: 'Cobranças', onTap: () => openMainPage(3)),
              _DrawerItem(icon: Icons.point_of_sale_outlined, title: 'Caixa', onTap: () => openMainPage(4)),
              const Divider(),
              _DrawerItem(icon: Icons.payments_outlined, title: 'Pagamentos', onTap: () => openDrawerPage('Pagamentos', const PaymentsPage())),
              _DrawerItem(icon: Icons.receipt_long_outlined, title: 'Recibos', onTap: () => openDrawerPage('Recibos', const ReceiptsPage())),
              _DrawerItem(icon: Icons.route_outlined, title: 'Rotas', onTap: () => openDrawerPage('Rotas', const RoutesPage())),
              _DrawerItem(icon: Icons.bar_chart_outlined, title: 'Relatórios', onTap: () => openDrawerPage('Relatórios', const ReportsPage())),
              _DrawerItem(icon: Icons.pie_chart_outline, title: 'Gestão da Carteira', onTap: () => openDrawerPage('Gestão da Carteira', const PortfolioPage())),
              _DrawerItem(icon: Icons.calculate_outlined, title: 'Calculadora', onTap: () => openDrawerPage('Calculadora', const CalculatorPage())),
              _DrawerItem(icon: Icons.settings_outlined, title: 'Configurações', onTap: () => openDrawerPage('Configurações', const SettingsPage())),
              _DrawerItem(icon: Icons.description_outlined, title: 'Documentos', onTap: () => openDrawerPage('Documentos', const DocumentsPage())),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.bootstrapError != null)
            MaterialBanner(
              content: const Text('Supabase ainda não foi configurado neste APK. A interface continua disponível para validação.'),
              actions: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.bootstrapError!)));
                  },
                  child: const Text('DETALHES'),
                ),
              ],
            ),
          Expanded(child: drawerPage ?? pages[index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: drawerPage == null ? index : 0,
        onDestinationSelected: openMainPage,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Empréstimos'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'Cobranças'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), label: 'Caixa'),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}
