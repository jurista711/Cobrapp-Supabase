import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';
import '../../data/dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final repository = const DashboardRepository();

  DashboardSummary summary = const DashboardSummary.empty();
  bool loading = true;
  String statusMessage = 'Carregando resumo...';

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future<void> loadSummary() async {
    setState(() {
      loading = true;
      statusMessage = 'Carregando resumo...';
    });

    try {
      final loaded = await repository.loadSummary();
      if (!mounted) return;
      setState(() {
        summary = loaded;
        loading = false;
        statusMessage = hasSupabaseConfig
            ? 'Resumo conectado ao Supabase.'
            : 'Supabase não configurado neste APK.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        statusMessage = 'Erro ao carregar resumo. Verifique internet/Supabase.';
      });
    }
  }

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Início', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                onPressed: loading ? null : loadSummary,
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
          const SizedBox(height: 4),
          Text(statusMessage),
          const SizedBox(height: 16),
          _MetricCard(
            title: 'Total emprestado',
            value: money(summary.totalLoaned),
            icon: Icons.account_balance_wallet_outlined,
          ),
          _MetricCard(
            title: 'Total a receber',
            value: money(summary.pendingAmount),
            icon: Icons.trending_up,
          ),
          _MetricCard(
            title: 'Recebido hoje',
            value: money(summary.receivedToday),
            icon: Icons.payments_outlined,
          ),
          Row(
            children: [
              Expanded(
                child: _SmallMetricCard(
                  title: 'Clientes',
                  value: summary.customersCount.toString(),
                  icon: Icons.people_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallMetricCard(
                  title: 'Empréstimos',
                  value: summary.activeLoansCount.toString(),
                  icon: Icons.description_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SmallMetricCard(
                  title: 'Parcelas pendentes',
                  value: summary.pendingInstallments.toString(),
                  icon: Icons.event_note_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallMetricCard(
                  title: 'Vencidas',
                  value: summary.overdueInstallments.toString(),
                  icon: Icons.warning_amber_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Atalho de trabalho', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('1. Cadastre o cliente.\n2. Crie o empréstimo.\n3. Acompanhe cobranças.\n4. Gere documentos em português.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});

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
            Icon(icon, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }
}
