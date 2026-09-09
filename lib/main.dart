import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/supabase_config.dart';
import 'domain/loan_models.dart';
import 'services/loan_calculator.dart';

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
    const _PlaceholderPage(title: 'Início', icon: Icons.dashboard_outlined),
    const _PlaceholderPage(title: 'Clientes', icon: Icons.people_outline),
    const LoanCalculatorPage(),
    const _PlaceholderPage(title: 'Cobranças', icon: Icons.event_available_outlined),
    const _PlaceholderPage(title: 'Documentos', icon: Icons.description_outlined),
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

class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key});

  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage> {
  final principalController = TextEditingController(text: '3500');
  final rateController = TextEditingController(text: '30');
  final paymentsController = TextEditingController(text: '5');
  final customDaysController = TextEditingController(text: '30');
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final date = DateFormat('dd/MM/yyyy', 'pt_BR');

  InterestType interestType = InterestType.initialCapital;
  PaymentFrequency frequency = PaymentFrequency.biweekly;
  LoanCalculationResult? result;
  String? error;

  @override
  void initState() {
    super.initState();
    calculate();
  }

  @override
  void dispose() {
    principalController.dispose();
    rateController.dispose();
    paymentsController.dispose();
    customDaysController.dispose();
    super.dispose();
  }

  void calculate() {
    try {
      final calculator = const LoanCalculator();
      final principal = _readNumber(principalController.text);
      final rate = _readNumber(rateController.text);
      final payments = int.parse(paymentsController.text.trim());
      final customDays = int.parse(customDaysController.text.trim());

      setState(() {
        error = null;
        result = calculator.calculate(
          LoanCalculationInput(
            principal: principal,
            interestRatePercent: rate,
            paymentsNumber: payments,
            interestType: interestType,
            paymentFrequency: frequency,
            startDate: DateTime.now(),
            customIntervalDays: customDays,
          ),
        );
      });
    } catch (exception) {
      setState(() {
        result = null;
        error = 'Confira os valores informados.';
      });
    }
  }

  double _readNumber(String text) {
    final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.parse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Calculadora de empréstimo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: principalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montante do empréstimo'),
          onChanged: (_) => calculate(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: rateController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Interesse (%)'),
          onChanged: (_) => calculate(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: paymentsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cotas'),
          onChanged: (_) => calculate(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<InterestType>(
          initialValue: interestType,
          decoration: const InputDecoration(labelText: 'Tipo de juros'),
          items: const [
            DropdownMenuItem(
              value: InterestType.initialCapital,
              child: Text('Capital inicial'),
            ),
            DropdownMenuItem(
              value: InterestType.eachPayment,
              child: Text('Cada parcela'),
            ),
            DropdownMenuItem(
              value: InterestType.bankCompound,
              child: Text('Juros compostos bancários'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => interestType = value);
            calculate();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PaymentFrequency>(
          initialValue: frequency,
          decoration: const InputDecoration(labelText: 'Frequência de pagamento'),
          items: const [
            DropdownMenuItem(value: PaymentFrequency.daily, child: Text('Diário')),
            DropdownMenuItem(value: PaymentFrequency.weekly, child: Text('Semanal')),
            DropdownMenuItem(value: PaymentFrequency.biweekly, child: Text('Quinzenal')),
            DropdownMenuItem(value: PaymentFrequency.monthly, child: Text('Mensal')),
            DropdownMenuItem(value: PaymentFrequency.custom, child: Text('Inserir manual')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => frequency = value);
            calculate();
          },
        ),
        if (frequency == PaymentFrequency.custom) ...[
          const SizedBox(height: 8),
          TextField(
            controller: customDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Intervalo manual em dias'),
            onChanged: (_) => calculate(),
          ),
        ],
        const SizedBox(height: 16),
        if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!),
            ),
          ),
        if (current != null) ...[
          _SummaryCard(
            money: money,
            date: date,
            result: current,
          ),
          const SizedBox(height: 12),
          Text('Plano de parcelas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final installment in current.installments)
            Card(
              child: ListTile(
                title: Text('Parcela ${installment.number} • ${date.format(installment.dueDate)}'),
                subtitle: Text(
                  'Capital: ${money.format(installment.principal)}  |  Juros: ${money.format(installment.interest)}',
                ),
                trailing: Text(money.format(installment.total)),
              ),
            ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.money,
    required this.date,
    required this.result,
  });

  final NumberFormat money;
  final DateFormat date;
  final LoanCalculationResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo da simulação', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _SummaryLine(label: 'Montante', value: money.format(result.principal)),
            _SummaryLine(label: 'Valor dos juros', value: money.format(result.totalInterest)),
            _SummaryLine(label: 'Empréstimo + juros', value: money.format(result.totalDebt)),
            _SummaryLine(label: 'Valor do pagamento', value: money.format(result.paymentAmount)),
            _SummaryLine(label: 'Vencimento final', value: date.format(result.endDate)),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
