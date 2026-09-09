import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';

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
    final client = supabaseOrNull;
    if (client == null) {
      setState(() => error = 'Supabase não configurado neste APK.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final now = DateTime.now();
      final today = _date(now);
      final monthStart = _date(DateTime(now.year, now.month, 1));

      final todayRows = await client
          .from('payments')
          .select('amount, total_paid, payment_date, paid_at')
          .or('payment_date.eq.$today,paid_at.gte.${today}T00:00:00')
          .order('created_at', ascending: false);

      final monthRows = await client
          .from('payments')
          .select('amount, total_paid, payment_date, paid_at')
          .or('payment_date.gte.$monthStart,paid_at.gte.${monthStart}T00:00:00')
          .order('created_at', ascending: false);

      final installmentRows = await client
          .from('installments')
          .select('total, amount, paid_amount, due_date, status')
          .neq('status', 'paid');

      double openTotal = 0;
      int overdue = 0;
      for (final row in installmentRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final total = _toDouble(map['total'] ?? map['amount']);
        final paid = _toDouble(map['paid_amount']);
        openTotal += (total - paid).clamp(0, double.infinity).toDouble();
        final due = map['due_date']?.toString() ?? '';
        if (due.compareTo(today) < 0) overdue++;
      }

      if (!mounted) return;
      setState(() {
        receivedToday = _sumPayments(todayRows);
        receivedMonth = _sumPayments(monthRows);
        paymentsToday = todayRows.length;
        pending = openTotal;
        overdueInstallments = overdue;
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

  double _sumPayments(List<dynamic> rows) {
    return rows.fold<double>(0, (sum, row) {
      final map = Map<String, dynamic>.from(row as Map);
      return sum + _toDouble(map['amount'] ?? map['total_paid']);
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _date(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
              Expanded(
                child: Text('Caixa', style: Theme.of(context).textTheme.headlineSmall),
              ),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            ),
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
