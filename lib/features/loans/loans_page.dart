import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_config.dart';
import '../../data/customers_repository.dart';
import '../../data/loans_repository.dart';
import '../../domain/loan_models.dart';
import '../../services/loan_calculator.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final customersRepository = const CustomersRepository();
  final loansRepository = const LoansRepository();
  final principalController = TextEditingController(text: '3500');
  final rateController = TextEditingController(text: '30');
  final paymentsController = TextEditingController(text: '5');
  final customDaysController = TextEditingController(text: '30');
  final noteController = TextEditingController();
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final date = DateFormat('dd/MM/yyyy', 'pt_BR');

  List<Customer> customers = const <Customer>[];
  List<LoanListItem> loans = const <LoanListItem>[];
  String? selectedCustomerId;
  InterestType interestType = InterestType.initialCapital;
  PaymentFrequency frequency = PaymentFrequency.biweekly;
  LoanCalculationResult? result;
  String? error;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    calculate();
    loadData();
  }

  @override
  void dispose() {
    principalController.dispose();
    rateController.dispose();
    paymentsController.dispose();
    customDaysController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final loadedCustomers = await customersRepository.listCustomers();
      final loadedLoans = await loansRepository.listActiveLoans();
      if (!mounted) return;
      setState(() {
        customers = loadedCustomers;
        loans = loadedLoans;
        selectedCustomerId ??= loadedCustomers.isEmpty ? null : loadedCustomers.first.id;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar empréstimos.';
      });
    }
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
    } catch (_) {
      setState(() {
        result = null;
        error = 'Confira os valores informados.';
      });
    }
  }

  Future<void> saveLoan() async {
    final current = result;
    final customerId = selectedCustomerId;

    if (!hasSupabaseConfig) {
      showMessage('Supabase não configurado neste APK.');
      return;
    }

    if (customerId == null) {
      showMessage('Cadastre um cliente antes de salvar o empréstimo.');
      return;
    }

    if (current == null) {
      showMessage('Confira os valores do empréstimo.');
      return;
    }

    setState(() => saving = true);
    try {
      await loansRepository.createLoan(
        customerId: customerId,
        input: LoanCalculationInput(
          principal: _readNumber(principalController.text),
          interestRatePercent: _readNumber(rateController.text),
          paymentsNumber: int.parse(paymentsController.text.trim()),
          interestType: interestType,
          paymentFrequency: frequency,
          startDate: DateTime.now(),
          customIntervalDays: int.parse(customDaysController.text.trim()),
        ),
        result: current,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );

      noteController.clear();
      await loadData();
      showMessage('Empréstimo salvo no Supabase.');
    } catch (_) {
      showMessage('Erro ao salvar empréstimo. Verifique conexão e cliente.');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double _readNumber(String text) {
    final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.parse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Novo empréstimo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasSupabaseConfig)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Supabase não configurado. O empréstimo só salva online quando o APK tiver as chaves.'),
              ),
            ),
          if (customers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nenhum cliente carregado. Cadastre um cliente na tela Clientes.'),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedCustomerId,
              decoration: const InputDecoration(labelText: 'Cliente'),
              items: customers
                  .map(
                    (customer) => DropdownMenuItem(
                      value: customer.id,
                      child: Text(customer.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selectedCustomerId = value),
            ),
          const SizedBox(height: 8),
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
              DropdownMenuItem(value: InterestType.initialCapital, child: Text('Capital inicial')),
              DropdownMenuItem(value: InterestType.eachPayment, child: Text('Cada parcela')),
              DropdownMenuItem(value: InterestType.bankCompound, child: Text('Juros compostos bancários')),
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
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: 'Observação'),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            ),
          if (current != null) _LoanSummary(money: money, date: date, result: current),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : saveLoan,
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Salvando...' : 'Salvar empréstimo'),
          ),
          const SizedBox(height: 24),
          Text('Empréstimos cadastrados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (loans.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nenhum empréstimo cadastrado ainda.'),
              ),
            )
          else
            for (final loan in loans)
              Card(
                child: ListTile(
                  title: Text(loan.customerName),
                  subtitle: Text('${loan.paymentsNumber} cotas • vence ${date.format(loan.endDate)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money.format(loan.totalDebt), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(loan.status),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _LoanSummary extends StatelessWidget {
  const _LoanSummary({required this.money, required this.date, required this.result});

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
            Text('Resumo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _Line(label: 'Montante', value: money.format(result.principal)),
            _Line(label: 'Juros', value: money.format(result.totalInterest)),
            _Line(label: 'Total', value: money.format(result.totalDebt)),
            _Line(label: 'Pagamento', value: money.format(result.paymentAmount)),
            _Line(label: 'Final', value: date.format(result.endDate)),
            const Divider(),
            Text('Parcelas: ${result.installments.length}'),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

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
