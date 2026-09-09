import 'package:flutter/material.dart';

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

  List<Customer> customers = const <Customer>[];
  List<LoanListItem> loans = const <LoanListItem>[];
  String? selectedCustomerId;
  InterestType interestType = InterestType.initialCapital;
  PaymentFrequency frequency = PaymentFrequency.biweekly;
  LoanCalculationResult? result;
  String? error;
  bool loading = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _calculateQuietly();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
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
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final loadedCustomers = await customersRepository.listCustomers();
      final loadedLoans = await loansRepository.listActiveLoans();
      if (!mounted) return;
      setState(() {
        customers = loadedCustomers;
        loans = loadedLoans;
        if (selectedCustomerId == null && loadedCustomers.isNotEmpty) {
          selectedCustomerId = loadedCustomers.first.id;
        }
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar dados do Supabase.';
      });
    }
  }

  void calculate() {
    setState(_calculateQuietly);
  }

  void _calculateQuietly() {
    try {
      final calculator = const LoanCalculator();
      final principal = _readNumber(principalController.text);
      final rate = _readNumber(rateController.text);
      final payments = int.parse(paymentsController.text.trim());
      final customDays = int.parse(customDaysController.text.trim());

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
    } catch (_) {
      result = null;
      error = 'Confira os valores informados.';
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
      showMessage('Erro ao salvar empréstimo. Verifique conexão, tabela e cliente.');
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

  String _money(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Empréstimos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: loading ? null : loadData,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                hasSupabaseConfig
                    ? 'Online no Supabase. Selecione um cliente e salve o empréstimo.'
                    : 'Supabase não configurado neste APK.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Novo empréstimo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (customers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nenhum cliente carregado. Cadastre primeiro na tela Clientes e toque em atualizar.'),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: customers.any((customer) => customer.id == selectedCustomerId)
                  ? selectedCustomerId
                  : customers.first.id,
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
            decoration: const InputDecoration(labelText: 'Juros (%)'),
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
            value: interestType,
            decoration: const InputDecoration(labelText: 'Tipo de juros'),
            items: const [
              DropdownMenuItem(value: InterestType.initialCapital, child: Text('Capital inicial')),
              DropdownMenuItem(value: InterestType.eachPayment, child: Text('Cada parcela')),
              DropdownMenuItem(value: InterestType.bankCompound, child: Text('Juros compostos bancários')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                interestType = value;
                _calculateQuietly();
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentFrequency>(
            value: frequency,
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
              setState(() {
                frequency = value;
                _calculateQuietly();
              });
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
          if (current != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumo', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _Line(label: 'Montante', value: _money(current.principal)),
                    _Line(label: 'Juros', value: _money(current.totalInterest)),
                    _Line(label: 'Total', value: _money(current.totalDebt)),
                    _Line(label: 'Pagamento', value: _money(current.paymentAmount)),
                    _Line(label: 'Final', value: _date(current.endDate)),
                    const Divider(),
                    Text('Parcelas geradas: ${current.installments.length}'),
                  ],
                ),
              ),
            ),
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
                  subtitle: Text('${loan.paymentsNumber} cotas • vence ${_date(loan.endDate)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(loan.totalDebt), style: const TextStyle(fontWeight: FontWeight.w700)),
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
