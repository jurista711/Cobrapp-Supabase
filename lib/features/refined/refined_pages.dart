import 'package:flutter/material.dart';

import '../../data/collections_repository.dart';
import '../../data/customers_repository.dart';
import '../../data/loans_repository.dart';
import '../../domain/loan_models.dart';
import '../collections/collections_page.dart';
import '../customers/customers_page.dart';
import '../loans/loans_page.dart';

class CustomersRefinedPage extends StatefulWidget {
  const CustomersRefinedPage({super.key});

  @override
  State<CustomersRefinedPage> createState() => _CustomersRefinedPageState();
}

class _CustomersRefinedPageState extends State<CustomersRefinedPage> {
  final customersRepository = const CustomersRepository();
  final loansRepository = const LoansRepository();
  final collectionsRepository = const CollectionsRepository();
  final searchController = TextEditingController();

  List<Customer> customers = const [];
  List<LoanListItem> loans = const [];
  List<CollectionInstallment> installments = const [];
  bool loading = true;
  String query = '';
  int filter = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final result = await Future.wait([
        customersRepository.listCustomers(),
        loansRepository.listActiveLoans(),
        collectionsRepository.listPendingInstallments(),
      ]);
      if (!mounted) return;
      setState(() {
        customers = result[0] as List<Customer>;
        loans = result[1] as List<LoanListItem>;
        installments = result[2] as List<CollectionInstallment>;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Set<String> get overdueCustomerIds {
    final overdueLoanIds = installments.where((e) => e.isOverdue).map((e) => e.loanId).toSet();
    return loans.where((e) => overdueLoanIds.contains(e.id)).map((e) => e.customerId).toSet();
  }

  List<Customer> get visible {
    final q = query.trim().toLowerCase();
    return customers.where((c) {
      final matchesQuery = q.isEmpty ||
          c.fullName.toLowerCase().contains(q) ||
          c.identification.toLowerCase().contains(q) ||
          (c.phone ?? '').toLowerCase().contains(q);
      final overdue = overdueCustomerIds.contains(c.id);
      final matchesFilter = switch (filter) {
        1 => !overdue,
        2 => overdue,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  int loanCount(String customerId) => loans.where((e) => e.customerId == customerId).length;

  Future<void> openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Novo cliente')),
        body: const CustomersPage(),
      ),
    ));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final list = visible;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Row(children: [
            const Expanded(child: Text('Clientes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            FilledButton.icon(onPressed: openCreate, icon: const Icon(Icons.add), label: const Text('Novo cliente')),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'Buscar cliente...', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text('Todos ${customers.length}'), selected: filter == 0, onSelected: (_) => setState(() => filter = 0)),
            ChoiceChip(label: Text('Ativos ${customers.length - overdueCustomerIds.length}'), selected: filter == 1, onSelected: (_) => setState(() => filter = 1)),
            ChoiceChip(label: Text('Em atraso ${overdueCustomerIds.length}'), selected: filter == 2, onSelected: (_) => setState(() => filter = 2)),
          ]),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (!loading && list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum cliente encontrado.'))),
          for (final customer in list)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                leading: CircleAvatar(child: Text(_initials(customer.fullName))),
                title: Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(customer.phone ?? customer.identification),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(text: overdueCustomerIds.contains(customer.id) ? 'Em atraso' : 'Ativo', overdue: overdueCustomerIds.contains(customer.id)),
                    const SizedBox(height: 4),
                    Text('${loanCount(customer.id)} empréstimo${loanCount(customer.id) == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(appBar: AppBar(title: Text(customer.fullName)), body: const CustomersPage()),
                  ));
                  await load();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class LoansRefinedPage extends StatefulWidget {
  const LoansRefinedPage({super.key});

  @override
  State<LoansRefinedPage> createState() => _LoansRefinedPageState();
}

class _LoansRefinedPageState extends State<LoansRefinedPage> {
  final repository = const LoansRepository();
  final searchController = TextEditingController();
  List<LoanListItem> loans = const [];
  bool loading = true;
  String query = '';
  int filter = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await repository.listActiveLoans();
      if (!mounted) return;
      setState(() {
        loans = data;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  List<LoanListItem> get visible {
    final q = query.trim().toLowerCase();
    return loans.where((l) {
      final matches = q.isEmpty || l.customerName.toLowerCase().contains(q) || l.status.toLowerCase().contains(q);
      if (!matches) return false;
      if (filter == 2) return false;
      return true;
    }).toList();
  }

  Future<void> openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('Novo empréstimo')), body: const LoansPage()),
    ));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final list = visible;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Row(children: [
            const Expanded(child: Text('Empréstimos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            FilledButton.icon(onPressed: openCreate, icon: const Icon(Icons.add), label: const Text('Novo empréstimo')),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'Buscar empréstimo...', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text('Todos ${loans.length}'), selected: filter == 0, onSelected: (_) => setState(() => filter = 0)),
            ChoiceChip(label: Text('Ativos ${loans.length}'), selected: filter == 1, onSelected: (_) => setState(() => filter = 1)),
            ChoiceChip(label: const Text('Quitados 0'), selected: filter == 2, onSelected: (_) => setState(() => filter = 2)),
          ]),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (!loading && list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum empréstimo encontrado.'))),
          for (final loan in list)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                leading: CircleAvatar(child: Text(_initials(loan.customerName))),
                title: Text(loan.customerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_money(loan.totalDebt)}\n${loan.paymentsNumber} parcelas'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(text: loan.status, overdue: loan.status.toLowerCase().contains('atras')),
                    const SizedBox(height: 4),
                    Text(_date(loan.endDate), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(appBar: AppBar(title: Text(loan.customerName)), body: const LoansPage()),
                  ));
                  await load();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CollectionsRefinedPage extends StatefulWidget {
  const CollectionsRefinedPage({super.key});

  @override
  State<CollectionsRefinedPage> createState() => _CollectionsRefinedPageState();
}

class _CollectionsRefinedPageState extends State<CollectionsRefinedPage> {
  final repository = const CollectionsRepository();
  final searchController = TextEditingController();
  List<CollectionInstallment> installments = const [];
  bool loading = true;
  String query = '';
  int filter = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await repository.listPendingInstallments();
      if (!mounted) return;
      setState(() {
        installments = data;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  List<CollectionInstallment> get visible {
    final q = query.trim().toLowerCase();
    return installments.where((e) {
      final matches = q.isEmpty || e.customerName.toLowerCase().contains(q);
      if (!matches) return false;
      if (filter == 0) return true;
      if (filter == 1) return e.isOverdue;
      return !e.isOverdue;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final overdue = installments.where((e) => e.isOverdue).length;
    final upcoming = installments.length - overdue;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const Text('Cobranças', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'Buscar cobranças...', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text('Todas ${installments.length}'), selected: filter == 0, onSelected: (_) => setState(() => filter = 0)),
            ChoiceChip(label: Text('Pendentes $overdue'), selected: filter == 1, onSelected: (_) => setState(() => filter = 1)),
            ChoiceChip(label: Text('Em dia $upcoming'), selected: filter == 2, onSelected: (_) => setState(() => filter = 2)),
          ]),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (!loading && visible.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma cobrança encontrada.'))),
          for (final item in visible)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                leading: CircleAvatar(child: Text(_initials(item.customerName))),
                title: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Parcela ${item.number} • Venc. ${_date(item.dueDate)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(text: item.isOverdue ? 'Em atraso' : 'Em dia', overdue: item.isOverdue),
                    const SizedBox(height: 4),
                    Text(_money(item.remainingAmount), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(appBar: AppBar(title: const Text('Cobrança')), body: const CollectionsPage()),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.overdue});
  final String text;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: overdue ? const Color(0xFF5C1720) : const Color(0xFF0D4A36),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: overdue ? const Color(0xFFFF8A8A) : const Color(0xFF6EE7B7))),
    );
  }
}

String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

String _date(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  return '$d/$m/${value.year}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
