import 'package:flutter/material.dart';

import '../../data/loans_repository.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final repository = const LoansRepository();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  List<LoanListItem> loans = const [];
  LoanDetail? detail;
  String? selectedLoanId;
  String? selectedInstallmentId;
  PaymentMode mode = PaymentMode.total;
  String method = 'Dinheiro';
  bool loading = true;
  bool paying = false;
  String? error;
  PaymentRegistrationResult? lastResult;

  @override
  void initState() {
    super.initState();
    loadLoans();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> loadLoans() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await repository.listActiveLoans();
      if (!mounted) return;
      setState(() {
        loans = loaded.where((item) => item.status != 'completed').toList();
        loading = false;
      });
      if (loans.isNotEmpty) {
        await selectLoan(selectedLoanId ?? loans.first.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar os empréstimos.';
      });
    }
  }

  Future<void> selectLoan(String? loanId) async {
    if (loanId == null) return;
    setState(() {
      selectedLoanId = loanId;
      loading = true;
      error = null;
      lastResult = null;
    });
    try {
      final loaded = await repository.getLoanDetail(loanId);
      final pending = loaded.installments.where((item) => !item.isPaid).toList();
      if (!mounted) return;
      setState(() {
        detail = loaded;
        selectedInstallmentId = pending.isEmpty ? null : pending.first.id;
        loading = false;
      });
      _syncAmount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível abrir o empréstimo.';
      });
    }
  }

  void _syncAmount() {
    final loan = detail;
    final installment = _selectedInstallment;
    if (loan == null || installment == null) {
      amountController.clear();
      return;
    }
    if (mode == PaymentMode.total) {
      amountController.text = _number(loan.updatedRemainingFor(installment));
    } else if (mode == PaymentMode.advance) {
      amountController.text = _number(_maxAdvance);
    } else {
      amountController.clear();
    }
  }

  LoanInstallmentDetail? get _selectedInstallment {
    final loan = detail;
    final id = selectedInstallmentId;
    if (loan == null || id == null) return null;
    for (final item in loan.installments) {
      if (item.id == id) return item;
    }
    return null;
  }

  double get _maxAdvance {
    final loan = detail;
    final installment = _selectedInstallment;
    if (loan == null || installment == null) return 0;
    final open = loan.installments
        .where((item) => !item.isPaid)
        .fold<double>(0, (sum, item) => sum + item.remainingAmount);
    return open + loan.lateChargeFor(installment);
  }

  Future<void> registerPayment() async {
    final loan = detail;
    final installment = _selectedInstallment;
    if (loan == null || installment == null) return;
    final amount = _parse(amountController.text);
    final lateCharge = loan.lateChargeFor(installment);
    final selectedTotal = loan.updatedRemainingFor(installment);

    if (amount <= 0) return _message('Informe um valor maior que zero.');
    if (mode == PaymentMode.total && (amount - selectedTotal).abs() > 0.009) {
      return _message('No pagamento exato, use o total atualizado da parcela.');
    }
    if (mode == PaymentMode.partial && amount >= selectedTotal - 0.009) {
      return _message('No pagamento parcial, informe um valor menor que o total da parcela.');
    }
    if (mode == PaymentMode.advance && amount > _maxAdvance + 0.009) {
      return _message('O adiantamento não pode ultrapassar o saldo total em aberto.');
    }

    setState(() {
      paying = true;
      lastResult = null;
    });
    try {
      final result = await repository.registerPayment(
        installment: installment,
        amount: amount,
        lateCharge: lateCharge,
        method: method,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        mode: mode,
      );
      final loanId = selectedLoanId;
      if (loanId != null) await selectLoan(loanId);
      if (!mounted) return;
      setState(() {
        lastResult = result;
        noteController.clear();
      });
      _message('Pagamento registrado. Recibo nº ${result.receiptNumber}.');
    } catch (e) {
      if (!mounted) return;
      _message('Não foi possível registrar o pagamento: $e');
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  double _parse(String value) =>
      double.tryParse(value.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  String _number(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
  String _money(double value) => 'R\$ ${_number(value)}';

  @override
  Widget build(BuildContext context) {
    final loan = detail;
    final installment = _selectedInstallment;
    final pending = loan?.installments.where((item) => !item.isPaid).toList() ?? const <LoanInstallmentDetail>[];
    final selectedLate = loan == null || installment == null ? 0.0 : loan.lateChargeFor(installment);
    final selectedTotal = loan == null || installment == null ? 0.0 : loan.updatedRemainingFor(installment);

    return RefreshIndicator(
      onRefresh: loadLoans,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pagamentos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          if (!loading && loans.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Nenhum empréstimo ativo para receber pagamento.'))),
          if (loans.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: selectedLoanId != null && loans.any((item) => item.id == selectedLoanId) ? selectedLoanId : loans.first.id,
              decoration: const InputDecoration(labelText: 'Empréstimo / cliente'),
              items: loans.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.customerName} • ${_money(item.totalDebt)}'))).toList(),
              onChanged: selectLoan,
            ),
            const SizedBox(height: 10),
          ],
          if (loan != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.customerName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Saldo em aberto: ${_money(loan.remaining)}'),
                    Text('Parcelas pendentes: ${loan.pendingCount}'),
                    Text('Parcelas vencidas: ${loan.overdueCount}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (pending.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedInstallmentId,
                decoration: const InputDecoration(labelText: 'Parcela inicial'),
                items: pending.map((item) => DropdownMenuItem(value: item.id, child: Text('Parcela ${item.number} • ${_money(item.remainingAmount)}'))).toList(),
                onChanged: (value) {
                  setState(() => selectedInstallmentId = value);
                  _syncAmount();
                },
              ),
            if (installment != null) ...[
              const SizedBox(height: 10),
              SegmentedButton<PaymentMode>(
                segments: const [
                  ButtonSegment(value: PaymentMode.total, label: Text('Exato')),
                  ButtonSegment(value: PaymentMode.partial, label: Text('Parcial')),
                  ButtonSegment(value: PaymentMode.advance, label: Text('Adiantado')),
                ],
                selected: {mode},
                onSelectionChanged: (selected) {
                  setState(() => mode = selected.first);
                  _syncAmount();
                },
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _Line(label: 'Restante da parcela', value: _money(installment.remainingAmount)),
                      _Line(label: 'Dias de atraso', value: '${installment.daysLate}'),
                      _Line(label: 'Mora / acréscimo', value: _money(selectedLate)),
                      _Line(label: 'Total atualizado', value: _money(selectedTotal)),
                      if (mode == PaymentMode.advance) _Line(label: 'Máximo para adiantar', value: _money(_maxAdvance)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valor pago',
                  helperText: mode == PaymentMode.partial
                      ? 'Informe um valor menor que ${_money(selectedTotal)}'
                      : mode == PaymentMode.advance
                          ? 'O excedente baixa as próximas parcelas automaticamente.'
                          : 'Pagamento exato da parcela selecionada.',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                items: const [
                  DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro')),
                  DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                  DropdownMenuItem(value: 'Transferência', child: Text('Transferência')),
                  DropdownMenuItem(value: 'Cartão', child: Text('Cartão')),
                  DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                ],
                onChanged: (value) => setState(() => method = value ?? 'Dinheiro'),
              ),
              const SizedBox(height: 10),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Observação')),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: paying ? null : registerPayment,
                icon: paying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.payments_outlined),
                label: Text(paying ? 'Registrando...' : 'Registrar pagamento'),
              ),
            ],
          ],
          if (lastResult != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('Recibo nº ${lastResult!.receiptNumber}'),
                subtitle: Text('${_money(lastResult!.amount)} • ${lastResult!.mode}'),
              ),
            ),
          ],
          const SizedBox(height: 80),
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
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
