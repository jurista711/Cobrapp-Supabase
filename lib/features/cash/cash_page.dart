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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Caixa', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
              IconButton(
                onPressed: loading ? null : loadCash,
                icon: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const Text('Resumo financeiro da carteira.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF8B3DFF)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recebido hoje', style: TextStyle(color: Color(0xFFE9D5FF))),
                const SizedBox(height: 4),
                Text(_money(receivedToday), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('$paymentsToday pagamento(s) registrado(s) hoje'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _CashMetric(title: 'No mês', value: _money(receivedMonth), icon: Icons.calendar_month_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _CashMetric(title: 'A receber', value: _money(pending), icon: Icons.account_balance_wallet_outlined)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _CashMetric(title: 'Pagamentos hoje', value: '$paymentsToday', icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _CashMetric(title: 'Vencidas', value: '$overdueInstallments', icon: Icons.warning_amber_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Visão rápida', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF102C24), child: Icon(Icons.south_west_rounded, color: Color(0xFF22C55E))),
                  title: const Text('Entradas de hoje'),
                  trailing: Text(_money(receivedToday), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF2A1A16), child: Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B))),
                  title: const Text('Valor pendente'),
                  trailing: Text(_money(pending), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF2B151A), child: Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444))),
                  title: const Text('Parcelas vencidas'),
                  trailing: Text('$overdueInstallments', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

class _CashMetric extends StatelessWidget {
  const _CashMetric({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFA78BFA)),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
