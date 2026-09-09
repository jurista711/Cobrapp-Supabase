import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> payments = const [];

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  Future<void> loadPayments() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await supabaseRequired.rpc('cobrapp_app_list_payments');
      if (!mounted) return;
      setState(() {
        payments = (loaded as List)
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar os pagamentos.';
      });
    }
  }

  String customerName(Map<String, dynamic> row) => row['customer_name']?.toString() ?? 'Cliente não informado';

  void showReceiptPreview(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prévia do recibo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${customerName(row)}'),
            Text('Valor: ${money(_toDouble(row['amount']))}'),
            Text('Data: ${formatDate(row['payment_date'] ?? row['created_at'])}'),
            Text('Método: ${row['method'] ?? 'manual'}'),
            if ((row['note'] ?? '').toString().trim().isNotEmpty) Text('Obs: ${row['note']}'),
            const SizedBox(height: 12),
            const Text('Próxima etapa: gerar recibo numerado em PDF e compartilhar no WhatsApp.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = payments.fold<double>(0, (sum, row) => sum + _toDouble(row['amount']));

    return RefreshIndicator(
      onRefresh: loadPayments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(title: 'Pagamentos', icon: Icons.payments_outlined),
          const SizedBox(height: 12),
          _MetricRow(
            leftTitle: 'Total recebido',
            leftValue: money(total),
            rightTitle: 'Registros',
            rightValue: payments.length.toString(),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) _InfoCard(title: 'Atenção', text: error!),
          if (!loading && payments.isEmpty) ...[
            const _InfoCard(title: 'Nenhum pagamento registrado.', text: 'Quando houver baixa de parcela, o histórico aparecerá aqui.'),
            const _InfoCard(title: 'Recibo', text: 'Cada pagamento fica preparado para gerar recibo numerado.'),
          ],
          for (final row in payments)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(customerName(row), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        Text(money(_toDouble(row['amount'])), style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Data: ${formatDate(row['payment_date'] ?? row['created_at'])}'),
                    Text('Método: ${row['method'] ?? 'manual'}'),
                    if ((row['note'] ?? '').toString().trim().isNotEmpty) Text('Obs: ${row['note']}'),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => showReceiptPreview(row),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Recibo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> receipts = const [];

  @override
  void initState() {
    super.initState();
    loadReceipts();
  }

  Future<void> loadReceipts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await supabaseRequired.rpc('cobrapp_app_list_receipts');
      if (!mounted) return;
      setState(() {
        receipts = (loaded as List)
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar os recibos.';
      });
    }
  }

  void showReceipt(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recibo ${row['receipt_number'] ?? ''}'.trim()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${row['customer_name'] ?? 'Cliente'}'),
            Text('Valor: ${money(_toDouble(row['amount']))}'),
            Text('Data: ${formatDate(row['payment_date'] ?? row['created_at'])}'),
            if ((row['notes'] ?? '').toString().trim().isNotEmpty) Text('Obs: ${row['notes']}'),
            const SizedBox(height: 12),
            const Text('Próxima etapa: PDF, assinatura, WhatsApp e impressão.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = receipts.fold<double>(0, (sum, row) => sum + _toDouble(row['amount']));

    return RefreshIndicator(
      onRefresh: loadReceipts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(title: 'Recibos', icon: Icons.receipt_long_outlined),
          const SizedBox(height: 12),
          _MetricRow(
            leftTitle: 'Total em recibos',
            leftValue: money(total),
            rightTitle: 'Emitidos',
            rightValue: receipts.length.toString(),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) _InfoCard(title: 'Atenção', text: error!),
          if (!loading && receipts.isEmpty) ...[
            const _InfoCard(title: 'Nenhum recibo encontrado.', text: 'Os recibos numerados aparecerão aqui após os pagamentos.'),
            const _InfoCard(title: 'Modelo do original', text: 'Preparado para PDF, assinatura, envio por WhatsApp/e-mail e impressão.'),
          ],
          for (final row in receipts)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(row['receipt_number']?.toString() ?? 'Recibo'),
                subtitle: Text('${row['customer_name'] ?? 'Cliente'} • ${formatDate(row['payment_date'] ?? row['created_at'])}'),
                trailing: Text(money(_toDouble(row['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => showReceipt(row),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class RoutesPage extends StatelessWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RemoteListPage(
      title: 'Rotas',
      icon: Icons.route_outlined,
      table: 'routes',
      select: 'id, name, description, created_at',
      emptyText: 'Nenhuma rota cadastrada.',
      fields: ['name', 'description', 'created_at'],
      fallback: [
        _ActionInfo('Rotas de cobrança', 'Organize clientes por rota ou região.'),
        _ActionInfo('Sequência de visita', 'Preparado para ordenar cobranças do dia.'),
        _ActionInfo('Status da rota', 'Preparado para acompanhar clientes pendentes e pagos.'),
      ],
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardLikePage(
      title: 'Relatórios',
      icon: Icons.bar_chart_outlined,
      items: [
        _ActionInfo('Recebido no período', 'Total por dia, semana, mês ou intervalo personalizado.'),
        _ActionInfo('Em aberto', 'Capital, juros e parcelas pendentes.'),
        _ActionInfo('Atrasados', 'Clientes e parcelas vencidas.'),
        _ActionInfo('Exportação', 'Área preparada para Excel, CSV e PDF.'),
      ],
    );
  }
}

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardLikePage(
      title: 'Gestão da Carteira',
      icon: Icons.pie_chart_outline,
      items: [
        _ActionInfo('Capital na rua', 'Soma de valores emprestados ainda em aberto.'),
        _ActionInfo('Vou receber', 'Parcelas futuras e vencidas.'),
        _ActionInfo('Lucro esperado', 'Juros previstos sobre a carteira ativa.'),
        _ActionInfo('Inadimplência', 'Controle de atrasos por cliente e empréstimo.'),
      ],
    );
  }
}

enum CalculatorInterestMode { initialCapital, eachPayment, bankCompound }

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final principal = TextEditingController();
  final installments = TextEditingController();
  final rate = TextEditingController();

  CalculatorInterestMode mode = CalculatorInterestMode.initialCapital;
  _SimulationResult? result;
  String? error;

  @override
  void dispose() {
    principal.dispose();
    installments.dispose();
    rate.dispose();
    super.dispose();
  }

  void calculate() {
    final amount = _parseMoney(principal.text);
    final count = int.tryParse(installments.text.trim()) ?? 0;
    final percent = _parseMoney(rate.text);

    if (amount <= 0) {
      setState(() {
        result = null;
        error = 'Informe o valor do crédito.';
      });
      return;
    }

    if (count <= 0) {
      setState(() {
        result = null;
        error = 'Informe a quantidade de cotas.';
      });
      return;
    }

    if (percent < 0) {
      setState(() {
        result = null;
        error = 'Informe uma taxa válida.';
      });
      return;
    }

    setState(() {
      error = null;
      result = _calculate(amount, count, percent, mode);
    });
  }

  _SimulationResult _calculate(double amount, int count, double percent, CalculatorInterestMode mode) {
    final rateDecimal = percent / 100;
    final rows = <_InstallmentRow>[];

    switch (mode) {
      case CalculatorInterestMode.initialCapital:
        final totalInterest = amount * rateDecimal;
        final totalDebt = amount + totalInterest;
        final payment = totalDebt / count;
        final principalPart = amount / count;
        final interestPart = totalInterest / count;
        for (var i = 1; i <= count; i++) {
          rows.add(_InstallmentRow(number: i, principal: principalPart, interest: interestPart, total: payment));
        }
        return _SimulationResult(
          modeName: 'Capital inicial',
          principal: amount,
          totalInterest: totalInterest,
          totalDebt: totalDebt,
          payment: payment,
          rows: rows,
        );

      case CalculatorInterestMode.eachPayment:
        final principalPart = amount / count;
        final interestPerInstallment = amount * rateDecimal;
        final payment = principalPart + interestPerInstallment;
        final totalInterest = interestPerInstallment * count;
        final totalDebt = amount + totalInterest;
        for (var i = 1; i <= count; i++) {
          rows.add(_InstallmentRow(number: i, principal: principalPart, interest: interestPerInstallment, total: payment));
        }
        return _SimulationResult(
          modeName: 'Cada parcela',
          principal: amount,
          totalInterest: totalInterest,
          totalDebt: totalDebt,
          payment: payment,
          rows: rows,
        );

      case CalculatorInterestMode.bankCompound:
        if (rateDecimal == 0) {
          final payment = amount / count;
          for (var i = 1; i <= count; i++) {
            rows.add(_InstallmentRow(number: i, principal: payment, interest: 0, total: payment));
          }
          return _SimulationResult(
            modeName: 'Juros compostos bancários',
            principal: amount,
            totalInterest: 0,
            totalDebt: amount,
            payment: payment,
            rows: rows,
          );
        }

        final payment = amount * rateDecimal / (1 - math.pow(1 + rateDecimal, -count));
        var balance = amount;
        var totalInterest = 0.0;

        for (var i = 1; i <= count; i++) {
          final interestPart = balance * rateDecimal;
          var principalPart = payment - interestPart;
          var rowTotal = payment;

          if (i == count) {
            principalPart = balance;
            rowTotal = principalPart + interestPart;
          }

          balance -= principalPart;
          totalInterest += interestPart;
          rows.add(_InstallmentRow(number: i, principal: principalPart, interest: interestPart, total: rowTotal));
        }

        return _SimulationResult(
          modeName: 'Juros compostos bancários',
          principal: amount,
          totalInterest: totalInterest,
          totalDebt: amount + totalInterest,
          payment: payment,
          rows: rows,
        );
    }
  }

  void clearFields() {
    principal.clear();
    installments.clear();
    rate.clear();
    setState(() {
      result = null;
      error = null;
    });
  }

  double _parseMoney(String value) {
    final clean = value.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final simulation = result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(title: 'Calculadora', icon: Icons.calculate_outlined),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo de juros', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<CalculatorInterestMode>(
                  segments: const [
                    ButtonSegment(value: CalculatorInterestMode.initialCapital, label: Text('Capital inicial')),
                    ButtonSegment(value: CalculatorInterestMode.eachPayment, label: Text('Cada parcela')),
                    ButtonSegment(value: CalculatorInterestMode.bankCompound, label: Text('Compostos')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selected) => setState(() {
                    mode = selected.first;
                    result = null;
                    error = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: principal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor', hintText: 'Ex: 3500'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: installments,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cotas', hintText: 'Ex: 5'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Juros do crédito (%)', hintText: 'Ex: 30'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: calculate,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Ver simulação'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: clearFields,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Limpar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (error != null) _InfoCard(title: 'Atenção', text: error!),
        if (simulation != null) ...[
          _SimulationSummary(result: simulation),
          const SizedBox(height: 12),
          Text('Plano de parcelas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final row in simulation.rows)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parcela ${row.number}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Capital: ${money(row.principal)}'),
                    Text('Juros: ${money(row.interest)}'),
                    Text('Total: ${money(row.total)}'),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SimulationSummary extends StatelessWidget {
  const _SimulationSummary({required this.result});

  final _SimulationResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo da simulação', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Interesse: ${result.modeName}'),
            Text('Valor dos juros: ${money(result.totalInterest)}'),
            Text('Valor do pagamento: ${money(result.payment)}'),
            Text('Montante total do empréstimo: ${money(result.principal)}'),
            Text('Empréstimo + juros: ${money(result.totalDebt)}'),
            Text('Dívida total: ${money(result.totalDebt)}'),
          ],
        ),
      ),
    );
  }
}

class _SimulationResult {
  const _SimulationResult({
    required this.modeName,
    required this.principal,
    required this.totalInterest,
    required this.totalDebt,
    required this.payment,
    required this.rows,
  });

  final String modeName;
  final double principal;
  final double totalInterest;
  final double totalDebt;
  final double payment;
  final List<_InstallmentRow> rows;
}

class _InstallmentRow {
  const _InstallmentRow({required this.number, required this.principal, required this.interest, required this.total});

  final int number;
  final double principal;
  final double interest;
  final double total;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardLikePage(
      title: 'Configurações',
      icon: Icons.settings_outlined,
      items: [
        _ActionInfo('Dados do negócio', 'Nome, telefone e identificação da cobrança.'),
        _ActionInfo('Moeda', 'Real e futuras moedas do app original.'),
        _ActionInfo('Logo e assinatura', 'Preparado para recibos e documentos.'),
        _ActionInfo('Supabase', 'Aplicativo online ligado ao backend configurado.'),
      ],
    );
  }
}

class _RemoteListPage extends StatefulWidget {
  const _RemoteListPage({
    required this.title,
    required this.icon,
    required this.table,
    required this.select,
    required this.emptyText,
    required this.fields,
    required this.fallback,
  });

  final String title;
  final IconData icon;
  final String table;
  final String select;
  final String emptyText;
  final List<String> fields;
  final List<_ActionInfo> fallback;

  @override
  State<_RemoteListPage> createState() => _RemoteListPageState();
}

class _RemoteListPageState extends State<_RemoteListPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final client = supabaseOrNull;
    if (client == null) {
      setState(() {
        loading = false;
        rows = const [];
      });
      return;
    }
    try {
      final loaded = await client.from(widget.table).select(widget.select).limit(50);
      if (!mounted) return;
      setState(() {
        rows = loaded.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Não foi possível carregar ${widget.title.toLowerCase()}.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(title: widget.title, icon: widget.icon),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) _InfoCard(title: 'Atenção', text: error!),
          if (!loading && rows.isEmpty) ...[
            _InfoCard(title: widget.emptyText, text: 'A tela está abrindo corretamente. A lista aparecerá quando existirem dados no Supabase.'),
            for (final item in widget.fallback) _InfoCard(title: item.title, text: item.text),
          ],
          for (final row in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final field in widget.fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('$field: ${row[field] ?? '-'}'),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DashboardLikePage extends StatelessWidget {
  const _DashboardLikePage({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<_ActionInfo> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(title: title, icon: icon),
        const SizedBox(height: 12),
        for (final item in items) _InfoCard(title: item.title, text: item.text),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.leftTitle, required this.leftValue, required this.rightTitle, required this.rightValue});

  final String leftTitle;
  final String leftValue;
  final String rightTitle;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SmallMetricCard(title: leftTitle, value: leftValue)),
        const SizedBox(width: 8),
        Expanded(child: _SmallMetricCard(title: rightTitle, value: rightValue)),
      ],
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text),
        ]),
      ),
    );
  }
}

class _ActionInfo {
  const _ActionInfo(this.title, this.text);
  final String title;
  final String text;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

String formatDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString().padLeft(4, '0');
  return '$day/$month/$year';
}
