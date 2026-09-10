import 'dart:math' as math;

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
  DateTime paymentDate = DateTime.now();
  bool loading = true;
  bool paying = false;
  String? error;
  PaymentRegistrationResult? lastResult;
  String? lastPartialSummary;

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
      lastPartialSummary = null;
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

  Future<void> choosePaymentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate.isAfter(now) ? now : paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Data do pagamento',
    );
    if (picked == null || !mounted) return;
    setState(() => paymentDate = picked);
    _syncAmount();
  }

  void _syncAmount() {
    final loan = detail;
    final installment = _selectedInstallment;
    if (loan == null || installment == null) {
      amountController.clear();
      return;
    }
    if (mode == PaymentMode.total) {
      amountController.text = _number(loan.updatedRemainingFor(installment, asOf: paymentDate));
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
    return open + loan.lateChargeFor(installment, asOf: paymentDate);
  }

  Future<void> registerPayment() async {
    final loan = detail;
    final installment = _selectedInstallment;
    if (loan == null || installment == null) return;
    final amount = _parse(amountController.text);
    final lateCharge = loan.lateChargeFor(installment, asOf: paymentDate);
    final selectedTotal = loan.updatedRemainingFor(installment, asOf: paymentDate);

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

    String? partialSummary;
    if (mode == PaymentMode.partial) {
      final lateApplied = math.min(amount, lateCharge).toDouble();
      final regularPaid = math.max(amount - lateApplied, 0).toDouble();
      final rolloverBase = math.max(installment.remainingAmount - regularPaid, 0).toDouble();
      final rolloverInterest = rolloverBase * (loan.interestRate / 100);
      final rolloverTotal = rolloverBase + rolloverInterest;
      final baseDate = installment.dueDate.isAfter(paymentDate) ? installment.dueDate : paymentDate;
      final nextDate = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      partialSummary = 'Saldo-base: ${_money(rolloverBase)} • Juros: ${_money(rolloverInterest)} • Novo total: ${_money(rolloverTotal)} • Próxima cobrança: ${_date(nextDate)}';
    }

    setState(() {
      paying = true;
      lastResult = null;
      lastPartialSummary = null;
    });
    try {
      final result = await repository.registerPayment(
        installment: installment,
        amount: amount,
        lateCharge: lateCharge,
        method: method,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        mode: mode,
        paidAt: paymentDate,
      );
      final paidDate = paymentDate;
      final loanId = selectedLoanId;
      if (loanId != null) await selectLoan(loanId);
      if (!mounted) return;
      setState(() {
        lastResult = result;
        lastPartialSummary = partialSummary;
        noteController.clear();
        paymentDate = DateTime.now();
      });
      _message('Pagamento de ${_date(paidDate)} registrado. Recibo nº ${result.receiptNumber}.');
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

  double _parse(String value) => double.tryParse(value.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  String _number(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
  String _money(double value) => 'R\$ ${_number(value)}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final loan = detail;
    final installment = _selectedInstallment;
    final pending = loan?.installments.where((item) => !item.isPaid).toList() ?? const <LoanInstallmentDetail>[];
    final selectedLate = loan == null || installment == null ? 0.0 : loan.lateChargeFor(installment, asOf: paymentDate);
    final selectedTotal = loan == null || installment == null ? 0.0 : loan.updatedRemainingFor(installment, asOf: paymentDate);

    return RefreshIndicator(
      onRefresh: loadLoans,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          const Text('Pagamentos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Registre recebimentos usando a data em que o pagamento realmente aconteceu.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          if (!loading && loans.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Nenhum empréstimo ativo para receber pagamento.'))),
          if (loans.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: selectedLoanId != null && loans.any((item) => item.id == selectedLoanId) ? selectedLoanId : loans.first.id,
              decoration: const InputDecoration(labelText: 'Cliente / empréstimo', prefixIcon: Icon(Icons.person_search_outlined)),
              items: loans.map((item) => DropdownMenuItem(value: item.id, child: Text(item.customerName))).toList(),
              onChanged: selectLoan,
            ),
            const SizedBox(height: 12),
          ],
          if (loan != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF8B3DFF)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Saldo em aberto', style: TextStyle(color: Color(0xFFE9D5FF))),
                  Text(_money(loan.remaining), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('${loan.pendingCount} parcela(s) pendente(s) • ${loan.overdueCount} vencida(s)'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (pending.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedInstallmentId,
                decoration: const InputDecoration(labelText: 'Parcela'),
                items: pending.map((item) => DropdownMenuItem(value: item.id, child: Text('Parcela ${item.number} • ${_money(item.remainingAmount)}'))).toList(),
                onChanged: (value) {
                  setState(() => selectedInstallmentId = value);
                  _syncAmount();
                },
              ),
            if (installment != null) ...[
              const SizedBox(height: 12),
              _DateField(label: 'Data do pagamento', value: _date(paymentDate), onTap: choosePaymentDate),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _Line(label: 'Restante da parcela', value: _money(installment.remainingAmount)),
                      _Line(label: 'Dias de atraso na data escolhida', value: '${installment.daysLateAt(paymentDate)}'),
                      _Line(label: 'Mora / acréscimo', value: _money(selectedLate)),
                      _Line(label: 'Total atualizado', value: _money(selectedTotal)),
                      if (mode == PaymentMode.advance) _Line(label: 'Máximo para adiantar', value: _money(_maxAdvance)),
                    ],
                  ),
                ),
              ),
              if (mode == PaymentMode.partial) ...[
                const SizedBox(height: 10),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.update_rounded, color: Color(0xFFA78BFA)),
                        SizedBox(width: 10),
                        Expanded(child: Text('Pagamento parcial: o saldo restante será prorrogado a partir da data escolhida e recalculado com a taxa do empréstimo.')),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valor pago',
                  prefixText: 'R\$ ',
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: paying ? null : registerPayment,
                  icon: paying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.payments_outlined),
                  label: Text(paying ? 'Registrando...' : 'Registrar pagamento'),
                ),
              ),
            ],
          ],
          if (lastResult != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      Text('Pagamento confirmado', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 10),
                    Text('Recibo nº ${lastResult!.receiptNumber}'),
                    Text('Valor: ${_money(lastResult!.amount)}'),
                    if (lastPartialSummary != null) ...[
                      const Divider(height: 24),
                      const Text('Prorrogação e recálculo', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(lastPartialSummary!),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_month_outlined), suffixIcon: const Icon(Icons.expand_more)),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
