import 'package:flutter/material.dart';

import '../../data/customers_repository.dart';
import '../../data/loan_crud_repository.dart';
import '../../data/loans_repository.dart';
import '../../domain/loan_models.dart';
import '../../services/loan_calculator.dart';

class LoanEditPage extends StatefulWidget {
  const LoanEditPage({super.key, required this.loanId});

  final String loanId;

  @override
  State<LoanEditPage> createState() => _LoanEditPageState();
}

class _LoanEditPageState extends State<LoanEditPage> {
  final loansRepository = const LoansRepository();
  final customersRepository = const CustomersRepository();
  final principalController = TextEditingController();
  final rateController = TextEditingController();
  final paymentsController = TextEditingController();
  final customDaysController = TextEditingController(text: '30');
  final noteController = TextEditingController();

  List<Customer> customers = const [];
  String? selectedCustomerId;
  InterestType interestType = InterestType.initialCapital;
  PaymentFrequency frequency = PaymentFrequency.monthly;
  DateTime startDate = DateTime.now();
  LoanCalculationResult? result;
  bool loading = true;
  bool saving = false;
  bool deleting = false;
  bool hasPaymentHistory = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
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

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        loansRepository.getLoanDetail(widget.loanId),
        customersRepository.listCustomers(),
      ]);
      final loan = values[0] as LoanDetail;
      final customerList = values[1] as List<Customer>;
      principalController.text = loan.amount.toStringAsFixed(2).replaceAll('.', ',');
      rateController.text = loan.interestRate.toStringAsFixed(2).replaceAll('.', ',');
      paymentsController.text = loan.paymentsNumber.toString();
      noteController.text = loan.note ?? '';
      startDate = loan.startDate;
      selectedCustomerId = loan.customerId;
      interestType = _interestTypeFromDb(loan.interestType);
      frequency = _frequencyFromDb(loan.paymentFrequency);
      if (frequency == PaymentFrequency.custom && loan.installments.isNotEmpty) {
        final days = loan.installments.first.dueDate.difference(loan.startDate).inDays;
        customDaysController.text = (days <= 0 ? 30 : days).toString();
      }
      hasPaymentHistory = loan.payments.isNotEmpty || loan.installments.any((e) => e.paidAmount > 0);
      customers = customerList;
      _calculateQuietly();
      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar o empréstimo: $e';
      });
    }
  }

  InterestType _interestTypeFromDb(String value) {
    switch (value) {
      case 'each_payment':
        return InterestType.eachPayment;
      case 'bank_compound':
        return InterestType.bankCompound;
      default:
        return InterestType.initialCapital;
    }
  }

  PaymentFrequency _frequencyFromDb(String value) {
    switch (value) {
      case 'daily':
        return PaymentFrequency.daily;
      case 'weekly':
        return PaymentFrequency.weekly;
      case 'biweekly':
        return PaymentFrequency.biweekly;
      case 'custom':
        return PaymentFrequency.custom;
      default:
        return PaymentFrequency.monthly;
    }
  }

  double _number(String value) => double.parse(value.trim().replaceAll('.', '').replaceAll(',', '.'));

  void _calculateQuietly() {
    try {
      result = const LoanCalculator().calculate(
        LoanCalculationInput(
          principal: _number(principalController.text),
          interestRatePercent: _number(rateController.text),
          paymentsNumber: int.parse(paymentsController.text.trim()),
          interestType: interestType,
          paymentFrequency: frequency,
          startDate: startDate,
          customIntervalDays: int.tryParse(customDaysController.text.trim()) ?? 30,
        ),
      );
      error = null;
    } catch (_) {
      result = null;
      error = 'Confira os valores informados.';
    }
  }

  void recalculate() => setState(_calculateQuietly);

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      startDate = picked;
      _calculateQuietly();
    });
  }

  Future<void> save() async {
    if (hasPaymentHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse empréstimo já possui pagamento registrado. Para preservar o histórico, os dados financeiros não podem ser recalculados.')),
      );
      return;
    }
    final current = result;
    final customerId = selectedCustomerId;
    if (current == null || customerId == null) return;
    setState(() => saving = true);
    try {
      await loansRepository.updateLoan(
        loanId: widget.loanId,
        customerId: customerId,
        input: LoanCalculationInput(
          principal: _number(principalController.text),
          interestRatePercent: _number(rateController.text),
          paymentsNumber: int.parse(paymentsController.text.trim()),
          interestType: interestType,
          paymentFrequency: frequency,
          startDate: startDate,
          customIntervalDays: int.tryParse(customDaysController.text.trim()) ?? 30,
        ),
        result: current,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível editar o empréstimo: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar empréstimo?'),
        content: const Text('Isso apaga o empréstimo, as parcelas e também os pagamentos/recibos vinculados a ele. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar tudo')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => deleting = true);
    try {
      await loansRepository.deleteLoan(widget.loanId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível apagar o empréstimo: $e')));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Editar empréstimo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          if (hasPaymentHistory)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Esse empréstimo já possui histórico de pagamento. Para não corromper o caixa e os recibos, a edição financeira fica bloqueada; a exclusão continua disponível com confirmação.'),
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: customers.any((c) => c.id == selectedCustomerId) ? selectedCustomerId : null,
            decoration: const InputDecoration(labelText: 'Cliente'),
            items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName))).toList(),
            onChanged: hasPaymentHistory ? null : (value) => setState(() => selectedCustomerId = value),
          ),
          const SizedBox(height: 10),
          TextField(controller: principalController, enabled: !hasPaymentHistory, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montante do empréstimo'), onChanged: (_) => recalculate()),
          const SizedBox(height: 10),
          TextField(controller: rateController, enabled: !hasPaymentHistory, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Juros (%)'), onChanged: (_) => recalculate()),
          const SizedBox(height: 10),
          TextField(controller: paymentsController, enabled: !hasPaymentHistory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cotas'), onChanged: (_) => recalculate()),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data do empréstimo'),
            subtitle: Text(_date(startDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: hasPaymentHistory ? null : chooseDate,
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<InterestType>(
            initialValue: interestType,
            decoration: const InputDecoration(labelText: 'Tipo de juros'),
            items: const [
              DropdownMenuItem(value: InterestType.initialCapital, child: Text('Capital inicial')),
              DropdownMenuItem(value: InterestType.eachPayment, child: Text('Cada parcela')),
              DropdownMenuItem(value: InterestType.bankCompound, child: Text('Juros compostos bancários')),
            ],
            onChanged: hasPaymentHistory ? null : (value) {
              if (value == null) return;
              setState(() {
                interestType = value;
                _calculateQuietly();
              });
            },
          ),
          const SizedBox(height: 10),
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
            onChanged: hasPaymentHistory ? null : (value) {
              if (value == null) return;
              setState(() {
                frequency = value;
                _calculateQuietly();
              });
            },
          ),
          if (frequency == PaymentFrequency.custom) ...[
            const SizedBox(height: 10),
            TextField(controller: customDaysController, enabled: !hasPaymentHistory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Intervalo manual em dias'), onChanged: (_) => recalculate()),
          ],
          const SizedBox(height: 10),
          TextField(controller: noteController, enabled: !hasPaymentHistory, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Observação')),
          if (result != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _Line(label: 'Montante', value: _money(result!.principal)),
                    _Line(label: 'Juros', value: _money(result!.totalInterest)),
                    _Line(label: 'Total', value: _money(result!.totalDebt)),
                    _Line(label: 'Pagamento', value: _money(result!.paymentAmount)),
                    _Line(label: 'Final', value: _date(result!.endDate)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving || deleting || hasPaymentHistory ? null : save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Salvando...' : 'Salvar alterações'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving || deleting ? null : delete,
            icon: deleting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_outline),
            label: Text(deleting ? 'Apagando...' : 'Apagar empréstimo'),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
    );
  }
}
