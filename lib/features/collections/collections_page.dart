import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';
import '../../data/collections_repository.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final repository = const CollectionsRepository();
  List<CollectionInstallment> installments = const <CollectionInstallment>[];
  bool loading = true;
  String? error;
  String? payingId;

  @override
  void initState() {
    super.initState();
    loadInstallments();
  }

  Future<void> loadInstallments() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loaded = await repository.listPendingInstallments();
      if (!mounted) return;
      setState(() {
        installments = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar as cobranças.';
      });
    }
  }

  Future<void> markPaid(CollectionInstallment installment) async {
    setState(() => payingId = installment.id);
    try {
      await repository.markInstallmentPaid(installment);
      if (!mounted) return;
      showMessage('Pagamento registrado.');
      await loadInstallments();
    } catch (_) {
      if (!mounted) return;
      showMessage('Erro ao registrar pagamento. Verifique a conexão.');
    } finally {
      if (mounted) {
        setState(() => payingId = null);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String money(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final overdue = installments.where((item) => item.isOverdue).toList();
    final upcoming = installments.where((item) => !item.isOverdue).toList();
    final totalOverdue = overdue.fold<double>(0, (sum, item) => sum + item.remainingAmount);
    final totalUpcoming = upcoming.fold<double>(0, (sum, item) => sum + item.remainingAmount);

    return RefreshIndicator(
      onRefresh: loadInstallments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cobranças', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasSupabaseConfig)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Supabase não configurado neste APK.'),
              ),
            ),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Vencidas',
                  value: money(totalOverdue),
                  subtitle: '${overdue.length} parcelas',
                  icon: Icons.warning_amber_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'A vencer',
                  value: money(totalUpcoming),
                  subtitle: '${upcoming.length} parcelas',
                  icon: Icons.schedule_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Vencidas', count: overdue.length),
          if (overdue.isEmpty)
            const _EmptyCard(text: 'Nenhuma cobrança vencida.')
          else
            for (final installment in overdue)
              _CollectionCard(
                installment: installment,
                money: money,
                formatDate: formatDate,
                paying: payingId == installment.id,
                onPaid: () => markPaid(installment),
              ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Próximas cobranças', count: upcoming.length),
          if (upcoming.isEmpty)
            const _EmptyCard(text: 'Nenhuma cobrança próxima.')
          else
            for (final installment in upcoming)
              _CollectionCard(
                installment: installment,
                money: money,
                formatDate: formatDate,
                paying: payingId == installment.id,
                onPaid: () => markPaid(installment),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
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
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          Text('$count'),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.installment,
    required this.money,
    required this.formatDate,
    required this.paying,
    required this.onPaid,
  });

  final CollectionInstallment installment;
  final String Function(double value) money;
  final String Function(DateTime date) formatDate;
  final bool paying;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final statusText = installment.isOverdue
        ? 'Atrasada há ${installment.overdueDays} dias'
        : 'Vence em ${formatDate(installment.dueDate)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    installment.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  money(installment.remainingAmount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Parcela ${installment.number} • ${formatDate(installment.dueDate)}'),
            Text(statusText),
            if ((installment.customerPhone ?? '').isNotEmpty) Text('Telefone: ${installment.customerPhone}'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: paying ? null : onPaid,
                icon: paying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(paying ? 'Registrando...' : 'Marcar como paga'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
