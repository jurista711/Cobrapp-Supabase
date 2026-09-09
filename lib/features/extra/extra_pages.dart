import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RemoteListPage(
      title: 'Pagamentos',
      icon: Icons.payments_outlined,
      table: 'payments',
      select: 'id, amount, payment_date, method, status, created_at',
      emptyText: 'Nenhum pagamento registrado.',
      fields: ['amount', 'payment_date', 'method', 'status'],
      fallback: [
        _ActionInfo('Histórico de pagamentos', 'Lista pagamentos registrados no Supabase.'),
        _ActionInfo('Baixa de parcela', 'A baixa será ligada ao fluxo de cobrança e empréstimo.'),
        _ActionInfo('Recibo', 'Cada pagamento poderá gerar recibo numerado.'),
      ],
    );
  }
}

class ReceiptsPage extends StatelessWidget {
  const ReceiptsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RemoteListPage(
      title: 'Recibos',
      icon: Icons.receipt_long_outlined,
      table: 'receipts',
      select: 'id, receipt_number, customer_name, amount, created_at',
      emptyText: 'Nenhum recibo encontrado.',
      fields: ['receipt_number', 'customer_name', 'amount', 'created_at'],
      fallback: [
        _ActionInfo('Recibos numerados', 'Preparado para histórico e sequência de recibos.'),
        _ActionInfo('PDF e compartilhamento', 'Fluxo preparado para PDF, WhatsApp e impressão.'),
        _ActionInfo('Assinatura', 'Área reservada para assinatura do cliente no recibo.'),
      ],
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
  final principal = TextEditingController(text: '3500');
  final installments = TextEditingController(text: '5');
  final rate = TextEditingController(text: '30');

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

  double _parseMoney(String value) {
    final clean = value.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0;
  }

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: installments,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cotas'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Juros do crédito (%)'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: calculate,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Ver simulação'),
                ),
              ],
            ),
          ),
        ),
        if (error != null) _InfoCard(title: 'Atenção', text: error!),
        if (simulation != null) ...[
          _SimulationSummary(result: simulation, money: money),
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
  const _SimulationSummary({required this.result, required this.money});

  final _SimulationResult result;
  final String Function(double value) money;

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
  const _RemoteListPage({required this.title, required this.icon, required this.table, required this.select, required this.emptyText, required this.fields, required this.fallback});

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
