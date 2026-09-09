import 'package:flutter/material.dart';

import '../../core/licensed_rpc.dart';

class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  bool loading = false;
  String? error;
  double receivedToday = 0;
  double receivedMonth = 0;
  double pending = 0;
  int paymentsToday = 0;
  int overdueInstallments = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadCash());
  }

  Future<void> loadCash() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await licensedRpc('cobrapp_app_cash_summary');
      final map = Map<String, dynamic>.from(response as Map);
      if (!mounted) return;
      setState(() {
        receivedToday = _toDouble(map['received_today']);
        receivedMonth = _toDouble(map['received_month']);
        paymentsToday = _toInt(map['payments_today']);
        pending = _toDouble(map['pending']);
        overdueInstallments = _toInt(map['overdue_installments']);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar o caixa.';
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadCash,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text('Caixa', style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                onPressed: loading ? null : loadCash,
                icon: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (error != null)
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          const SizedBox(height: 12),
          _CashCard(title: 'Recebido hoje', value: _money(receivedToday), icon: Icons.payments_outlined),
          const SizedBox(height: 12),
          _CashCard(title: 'Recebido no mês', value: _money(receivedMonth), icon: Icons.calendar_month_outlined),
          const SizedBox(height: 12),
          _CashCard(title: 'A receber', value: _money(pending), icon: Icons.account_balance_wallet_outlined),
          const SizedBox(height: 12),
          _CashCard(title: 'Pagamentos hoje', value: '$paymentsToday', icon: Icons.receipt_long_outlined),
          const SizedBox(height: 12),
          _CashCard(title: 'Parcelas vencidas', value: '$overdueInstallments', icon: Icons.warning_amber_outlined),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Caixa alinhado ao fluxo do original: resumo de recebidos, pendências e vencidos.'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
