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
        selectedCustomerId ??= loadedCustomers.isEmpty ? null : loadedCustomers.first.id;
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

  void calculate() => setState(_calculateQuietly);

  void _calculateQuietly() {
    try {
      final calculator = const LoanCalculator();
      error = null;
      result = calculator.calculate(
        LoanCalculationInput(
          principal: _readNumber(principalController.text),
          interestRatePercent: _readNumber(rateController.text),
          paymentsNumber: int.parse(paymentsController.text.trim()),
          interestType: interestType,
          paymentFrequency: frequency,
          startDate: DateTime.now(),
          customIntervalDays: int.parse(customDaysController.text.trim()),
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
    if (!hasSupabaseConfig) return showMessage('Supabase não configurado neste APK.');
    if (customerId == null) return showMessage('Cadastre um cliente antes de salvar o empréstimo.');
    if (current == null) return showMessage('Confira os valores do empréstimo.');

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
      if (!mounted) return;
      showMessage('Empréstimo salvo no Supabase.');
    } catch (_) {
      if (!mounted) return;
      showMessage('Erro ao salvar empréstimo. Verifique conexão, tabela e cliente.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> openLoanDetail(LoanListItem loan) async {
    if (!hasSupabaseConfig) return showMessage('Supabase não configurado neste APK.');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LoanDetailSheet(
        loanId: loan.id,
        repository: loansRepository,
        money: _money,
        date: _date,
        onChanged: loadData,
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double _readNumber(String text) => double.parse(text.trim().replaceAll('.', '').replaceAll(',', '.'));

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

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
              Expanded(child: Text('Empréstimos', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(onPressed: loading ? null : loadData, icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(hasSupabaseConfig ? 'Online no Supabase. Toque em um empréstimo para detalhes e baixa.' : 'Supabase não configurado neste APK.'))),
          const SizedBox(height: 12),
          Text('Novo empréstimo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (customers.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Nenhum cliente carregado. Cadastre primeiro na tela Clientes e toque em atualizar.')))
          else
            DropdownButtonFormField<String>(
              initialValue: customers.any((customer) => customer.id == selectedCustomerId) ? selectedCustomerId : customers.first.id,
              decoration: const InputDecoration(labelText: 'Cliente'),
              items: customers.map((customer) => DropdownMenuItem(value: customer.id, child: Text(customer.fullName))).toList(),
              onChanged: (value) => setState(() => selectedCustomerId = value),
            ),
          const SizedBox(height: 8),
          TextField(controller: principalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montante do empréstimo'), onChanged: (_) => calculate()),
          const SizedBox(height: 8),
          TextField(controller: rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Juros (%)'), onChanged: (_) => calculate()),
          const SizedBox(height: 8),
          TextField(controller: paymentsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cotas'), onChanged: (_) => calculate()),
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
              setState(() {
                interestType = value;
                _calculateQuietly();
              });
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
              setState(() {
                frequency = value;
                _calculateQuietly();
              });
            },
          ),
          if (frequency == PaymentFrequency.custom) ...[
            const SizedBox(height: 8),
            TextField(controller: customDaysController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Intervalo manual em dias'), onChanged: (_) => calculate()),
          ],
          const SizedBox(height: 8),
          TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Observação')),
          const SizedBox(height: 16),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
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
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Salvando...' : 'Salvar empréstimo'),
          ),
          const SizedBox(height: 24),
          Text('Empréstimos cadastrados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (loans.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Nenhum empréstimo cadastrado ainda.')))
          else
            for (final loan in loans)
              Card(
                child: ListTile(
                  onTap: () => openLoanDetail(loan),
                  title: Text(loan.customerName),
                  subtitle: Text('${loan.paymentsNumber} cotas • vence ${_date(loan.endDate)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [Text(_money(loan.totalDebt), style: const TextStyle(fontWeight: FontWeight.w700)), Text(loan.status)],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class LoanDetailSheet extends StatefulWidget {
  const LoanDetailSheet({
    super.key,
    required this.loanId,
    required this.repository,
    required this.money,
    required this.date,
    required this.onChanged,
  });

  final String loanId;
  final LoansRepository repository;
  final String Function(double value) money;
  final String Function(DateTime value) date;
  final Future<void> Function() onChanged;

  @override
  State<LoanDetailSheet> createState() => _LoanDetailSheetState();
}

class _LoanDetailSheetState extends State<LoanDetailSheet> {
  LoanDetail? detail;
  bool loading = true;
  bool paying = false;
  String? error;
  String? selectedInstallmentId;
  final paymentController = TextEditingController();
  final paymentNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  @override
  void dispose() {
    paymentController.dispose();
    paymentNoteController.dispose();
    super.dispose();
  }

  Future<void> loadDetail() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.repository.getLoanDetail(widget.loanId);
      if (!mounted) return;
      final nextInstallment = loaded.installments.where((item) => !item.isPaid).firstOrNull;
      setState(() {
        detail = loaded;
        selectedInstallmentId = nextInstallment?.id;
        if (nextInstallment != null && paymentController.text.trim().isEmpty) {
          paymentController.text = loaded.updatedRemainingFor(nextInstallment).toStringAsFixed(2).replaceAll('.', ',');
        }
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível abrir os detalhes do empréstimo.';
      });
    }
  }

  Future<void> registerPayment() async {
    final current = detail;
    if (current == null || selectedInstallmentId == null) return;
    final installment = current.installments.firstWhere((item) => item.id == selectedInstallmentId);
    final amount = _readNumber(paymentController.text);
    final lateCharge = current.lateChargeFor(installment);
    final maxPayable = current.updatedRemainingFor(installment);

    if (amount <= 0) return showMessage('Informe um valor maior que zero.');
    if (amount > maxPayable + 0.009) return showMessage('O valor não pode passar do total atualizado da parcela.');

    setState(() => paying = true);
    try {
      await widget.repository.registerPartialPayment(
        installment: installment,
        amount: amount,
        lateCharge: lateCharge,
        note: paymentNoteController.text.trim().isEmpty ? null : paymentNoteController.text.trim(),
      );
      paymentController.clear();
      paymentNoteController.clear();
      await loadDetail();
      await widget.onChanged();
      if (!mounted) return;
      showMessage('Pagamento registrado.');
    } catch (_) {
      if (!mounted) return;
      showMessage('Erro ao registrar pagamento.');
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double _readNumber(String text) => double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final current = detail;
    final selectedInstallment = current?.installments.where((item) => item.id == selectedInstallmentId).firstOrNull;
    final selectedLateCharge = current == null || selectedInstallment == null ? 0.0 : current.lateChargeFor(selectedInstallment);
    final selectedUpdatedTotal = current == null || selectedInstallment == null ? 0.0 : current.updatedRemainingFor(selectedInstallment);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: loading
            ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            : error != null
                ? SizedBox(height: 220, child: Center(child: Text(error!)))
                : current == null
                    ? const SizedBox(height: 220, child: Center(child: Text('Empréstimo não encontrado.')))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          Row(children: [Expanded(child: Text('Detalhe do empréstimo', style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: loadDetail, icon: const Icon(Icons.refresh))]),
                          Text(current.customerName, style: Theme.of(context).textTheme.titleMedium),
                          if (current.customerPhone != null) Text('Telefone: ${current.customerPhone}'),
                          if (current.customerIdentification != null) Text('Documento: ${current.customerIdentification}'),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  _Line(label: 'Capital', value: widget.money(current.amount)),
                                  _Line(label: 'Juros', value: widget.money(current.totalInterest)),
                                  _Line(label: 'Total original', value: widget.money(current.totalDebt)),
                                  _Line(label: 'Pago em parcelas', value: widget.money(current.totalPaid)),
                                  _Line(label: 'Restante original', value: widget.money(current.remaining)),
                                  _Line(label: 'Juros atraso/dia', value: '${current.lateInterestRate.toStringAsFixed(2).replaceAll('.', ',')}%'),
                                  _Line(label: 'Multa atraso', value: widget.money(current.lateFee)),
                                  _Line(label: 'Carência', value: '${current.daysOfGrace} dia(s)'),
                                  _Line(label: 'Parcelas pagas', value: '${current.paidCount}/${current.installments.length}'),
                                  _Line(label: 'Vencidas', value: '${current.overdueCount}'),
                                  _Line(label: 'Status', value: current.status),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Registrar pagamento', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (current.pendingCount == 0)
                            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Todas as parcelas estão pagas.')))
                          else ...[
                            DropdownButtonFormField<String>(
                              initialValue: selectedInstallmentId,
                              decoration: const InputDecoration(labelText: 'Parcela'),
                              items: current.installments.where((item) => !item.isPaid).map((item) {
                                final late = current.lateChargeFor(item);
                                final label = late > 0 ? 'Parcela ${item.number} • ${widget.money(item.remainingAmount + late)} com atraso' : 'Parcela ${item.number} • ${widget.money(item.remainingAmount)}';
                                return DropdownMenuItem(value: item.id, child: Text(label));
                              }).toList(),
                              onChanged: (value) {
                                final next = current.installments.where((item) => item.id == value).firstOrNull;
                                setState(() {
                                  selectedInstallmentId = value;
                                  if (next != null) paymentController.text = current.updatedRemainingFor(next).toStringAsFixed(2).replaceAll('.', ',');
                                });
                              },
                            ),
                            if (selectedInstallment != null) ...[
                              const SizedBox(height: 8),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      _Line(label: 'Restante da parcela', value: widget.money(selectedInstallment.remainingAmount)),
                                      _Line(label: 'Dias de atraso', value: '${selectedInstallment.daysLate}'),
                                      _Line(label: 'Acréscimo por atraso', value: widget.money(selectedLateCharge)),
                                      _Line(label: 'Total atualizado', value: widget.money(selectedUpdatedTotal)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextField(controller: paymentController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Valor pago', helperText: selectedInstallment == null ? null : 'Pode ser parcial ou total atualizado: ${widget.money(selectedUpdatedTotal)}')),
                            const SizedBox(height: 8),
                            TextField(controller: paymentNoteController, decoration: const InputDecoration(labelText: 'Observação do pagamento')),
                            const SizedBox(height: 8),
                            FilledButton.icon(onPressed: paying ? null : registerPayment, icon: paying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payments_outlined), label: Text(paying ? 'Registrando...' : 'Registrar pagamento')),
                          ],
                          const SizedBox(height: 16),
                          Text('Parcelas', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          for (final installment in current.installments)
                            Card(
                              child: ListTile(
                                title: Text('Parcela ${installment.number}'),
                                subtitle: Text('Vence ${widget.date(installment.dueDate)} • Pago ${widget.money(installment.paidAmount)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(widget.money(current.updatedRemainingFor(installment)), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(installment.isPaid ? 'paga' : installment.isOverdue ? '${installment.daysLate} dia(s)' : 'pendente'),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text('Histórico de pagamentos', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (current.payments.isEmpty)
                            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Nenhum pagamento registrado.')))
                          else
                            for (final payment in current.payments)
                              Card(child: ListTile(leading: const Icon(Icons.receipt_long_outlined), title: Text(widget.money(payment.totalPaid)), subtitle: Text('${widget.date(payment.paidAt)} • ${payment.method}${payment.note == null ? '' : ' • ${payment.note}'}'))),
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
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))],
      ),
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
