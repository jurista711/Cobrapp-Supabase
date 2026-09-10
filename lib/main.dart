import 'dart:async';

import 'package:flutter/material.dart';

import 'core/supabase_config.dart';
import 'features/activation/activation_page.dart';
import 'features/cash/cash_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/documents/documents_page.dart';
import 'features/extra/extra_pages.dart' hide PaymentsPage, ReceiptsPage;
import 'features/loans/loans_page.dart';
import 'features/payments/payments_page.dart';
import 'features/receipts/receipts_page.dart';
import 'features/refined/refined_pages.dart';

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
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFF233A63)),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Roots Cobrança',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060B18),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B3DFF),
          secondary: Color(0xFFA855F7),
          tertiary: Color(0xFF22C55E),
          surface: Color(0xFF0C1629),
          onSurface: Color(0xFFF8FAFC),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF060B18),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0D172B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF182C4A)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1A31),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder.copyWith(
            borderSide: const BorderSide(color: Color(0xFF8B3DFF), width: 1.6),
          ),
          hintStyle: const TextStyle(color: Color(0xFF7183A7)),
          labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF07101F),
          indicatorColor: Color(0x332C1DFF),
          height: 68,
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B3DFF),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: ActivationGate(
        bootstrapError: bootstrapError,
        child: HomePage(bootstrapError: bootstrapError),
      ),
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
    const CustomersRefinedPage(),
    const LoansRefinedPage(),
    const CollectionsRefinedPage(),
    MorePage(openPage: openStandalone),
  ];

  void openStandalone(String title, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.bootstrapError != null)
              MaterialBanner(
                content: const Text('Falha ao conectar ao Supabase.'),
                actions: [
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(widget.bootstrapError!)),
                    ),
                    child: const Text('DETALHES'),
                  ),
                ],
              ),
            Expanded(child: IndexedStack(index: index, children: pages)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Empréstimos'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Cobranças'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Mais'),
        ],
      ),
    );
  }
}

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.openPage});

  final void Function(String title, Widget page) openPage;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, Widget page})>[
      (icon: Icons.account_balance_wallet_outlined, title: 'Empréstimos', page: const LoansPage()),
      (icon: Icons.payments_outlined, title: 'Pagamentos', page: const PaymentsPage()),
      (icon: Icons.calculate_outlined, title: 'Calculadora', page: const CalculatorPage()),
      (icon: Icons.receipt_long_outlined, title: 'Recibos', page: const ReceiptsPage()),
      (icon: Icons.point_of_sale_outlined, title: 'Caixa', page: const CashPage()),
      (icon: Icons.route_outlined, title: 'Rotas', page: const RoutesPage()),
      (icon: Icons.bar_chart_outlined, title: 'Relatórios', page: const ReportsPage()),
      (icon: Icons.pie_chart_outline, title: 'Gestão da Carteira', page: const PortfolioPage()),
      (icon: Icons.description_outlined, title: 'Documentos', page: const DocumentsPage()),
      (icon: Icons.settings_outlined, title: 'Configurações', page: const SettingsPage()),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const Text('Mais', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF7C3AED),
              child: Icon(Icons.person_rounded, color: Colors.white),
            ),
            title: const Text('Roots Cobrança', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Gestão de empréstimos e cobranças'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                ListTile(
                  leading: Icon(items[i].icon),
                  title: Text(items[i].title),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(items[i].title, items[i].page),
                ),
                if (i != items.length - 1) const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roots Cobrança', style: TextStyle(fontWeight: FontWeight.w900)),
                      Text('Mais controle para o seu negócio.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
