import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';
import '../../data/collections_repository.dart';
import '../../data/customers_repository.dart';
import '../../data/loans_repository.dart';
import '../../domain/loan_models.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final repository = const CustomersRepository();
  final loansRepository = const LoansRepository();
  final collectionsRepository = const CollectionsRepository();
  final nameController = TextEditingController();
  final documentController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final searchController = TextEditingController();

  final customers = <Customer>[];
  String query = '';
  String? loadError;
  bool loading = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadCustomers();
  }

  @override
  void dispose() {
    nameController.dispose();
    documentController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadCustomers() async {
    if (!hasSupabaseConfig) {
      setState(() {
        loadError = 'Supabase não conectado neste APK. Gere a build com SUPABASE_URL e SUPABASE_ANON_KEY configurados nos Secrets do GitHub.';
      });
      return;
    }

    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      final loaded = await repository.listCustomers();
      if (!mounted) return;
      setState(() {
        customers
          ..clear()
          ..addAll(loaded);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loadError = 'Não foi possível carregar clientes do Supabase: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveCustomer() async {
    final name = nameController.text.trim();
    final document = documentController.text.trim();

    if (!hasSupabaseConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase não conectado. Cliente não foi salvo.')),
      );
      setState(() {
        loadError = 'Supabase não conectado neste APK. A build precisa receber SUPABASE_URL e SUPABASE_ANON_KEY.';
      });
      return;
    }

    if (name.isEmpty || document.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e documento são obrigatórios.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final customer = await repository.createCustomer(
        fullName: name,
        identification: document,
        phone: _optional(phoneController.text),
        email: _optional(emailController.text),
        address: _optional(addressController.text),
      );

      if (!mounted) return;
      setState(() {
        customers.insert(0, customer);
        nameController.clear();
        documentController.clear();
        phoneController.clear();
        emailController.clear();
        addressController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente salvo no Supabase.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar cliente no Supabase: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> removeCustomer(Customer customer) async {
    if (!hasSupabaseConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase não conectado. Cliente não foi removido.')),
      );
      return;
    }

    final oldIndex = customers.indexOf(customer);
    setState(() => customers.remove(customer));

    try {
      await repository.deactivateCustomer(customer.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => customers.insert(oldIndex < 0 ? 0 : oldIndex, customer));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível remover o cliente: $error')),
      );
    }
  }

  Future<void> openCustomerDetails(Customer customer) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final loans = await loansRepository.listActiveLoans();
      final installments = await collectionsRepository.listPendingInstallments();
      final customerLoans = loans.where((loan) => loan.customerId == customer.id).toList();
      final loanIds = customerLoans.map((loan) => loan.id).toSet();
      final customerInstallments = installments.where((item) => loanIds.contains(item.loanId)).toList();
      final overdue = customerInstallments.where((item) => item.isOverdue).toList();
      final totalOpen = customerInstallments.fold<double>(0, (sum, item) => sum + item.remainingAmount);
      final totalLoans = customerLoans.fold<double>(0, (sum, item) => sum + item.totalDebt);

      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(customer.fullName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailLine(label: 'Documento', value: customer.identification),
                if (customer.phone != null) _DetailLine(label: 'Telefone', value: customer.phone!),
                if (customer.email != null) _DetailLine(label: 'E-mail', value: customer.email!),
                if (customer.address != null) _DetailLine(label: 'Endereço', value: customer.address!),
                const Divider(),
                _DetailLine(label: 'Empréstimos ativos', value: customerLoans.length.toString()),
                _DetailLine(label: 'Total contratado', value: _money(totalLoans)),
                _DetailLine(label: 'Total em aberto', value: _money(totalOpen)),
                _DetailLine(label: 'Parcelas pendentes', value: customerInstallments.length.toString()),
                _DetailLine(label: 'Parcelas vencidas', value: overdue.length.toString()),
                const SizedBox(height: 12),
                if (customerLoans.isEmpty)
                  const Text('Este cliente ainda não possui empréstimo ativo.')
                else
                  for (final loan in customerLoans.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_money(loan.totalDebt)),
                      subtitle: Text('${loan.paymentsNumber} parcelas • vence ${_date(loan.endDate)}'),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FECHAR'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar detalhes do cliente: $error')),
      );
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  List<Customer> get filteredCustomers {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return customers;

    return customers.where((customer) {
      return customer.fullName.toLowerCase().contains(normalized) ||
          customer.identification.toLowerCase().contains(normalized) ||
          (customer.phone ?? '').toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCustomers = filteredCustomers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Clientes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Cadastro base para vincular empréstimos, cobranças, pagamentos e documentos.'),
        const SizedBox(height: 12),
        if (loadError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(loadError!),
            ),
          ),
        if (loading) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Novo cliente', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: documentController,
                  decoration: const InputDecoration(labelText: 'Documento / identificação'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: saving ? null : saveCustomer,
                  icon: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(saving ? 'Salvando...' : 'Salvar cliente'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(labelText: 'Buscar cliente', prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lista de clientes', style: Theme.of(context).textTheme.titleMedium),
            Text('${visibleCustomers.length}/${customers.length}'),
          ],
        ),
        const SizedBox(height: 8),
        if (customers.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum cliente cadastrado ainda.'),
            ),
          )
        else if (visibleCustomers.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum cliente encontrado nessa busca.'),
            ),
          )
        else
          for (final customer in visibleCustomers)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(customer.fullName),
                subtitle: Text([
                  customer.identification,
                  if (customer.phone != null) customer.phone!,
                  if (customer.address != null) customer.address!,
                ].join(' • ')),
                onTap: () => openCustomerDetails(customer),
                trailing: IconButton(
                  tooltip: 'Remover cliente',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => removeCustomer(customer),
                ),
              ),
            ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
