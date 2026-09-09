import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';
import '../../data/customers_repository.dart';
import '../../domain/loan_models.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final repository = const CustomersRepository();
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
        loadError = 'Supabase não configurado neste APK. Informe as chaves no build para salvar online.';
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
      setState(() => loadError = 'Não foi possível carregar clientes do Supabase.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveCustomer() async {
    final name = nameController.text.trim();
    final document = documentController.text.trim();

    if (name.isEmpty || document.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome e documento são obrigatórios.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      late final Customer customer;
      if (hasSupabaseConfig) {
        customer = await repository.createCustomer(
          fullName: name,
          identification: document,
          phone: _optional(phoneController.text),
          email: _optional(emailController.text),
          address: _optional(addressController.text),
        );
      } else {
        customer = Customer(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          fullName: name,
          identification: document,
          phone: _optional(phoneController.text),
          email: _optional(emailController.text),
          address: _optional(addressController.text),
        );
      }

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
        SnackBar(
          content: Text(
            hasSupabaseConfig
                ? 'Cliente salvo no Supabase.'
                : 'Cliente adicionado só para validação deste APK.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar cliente. Verifique documento duplicado ou conexão.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> removeCustomer(Customer customer) async {
    final oldIndex = customers.indexOf(customer);
    setState(() => customers.remove(customer));

    try {
      if (hasSupabaseConfig) {
        await repository.deactivateCustomer(customer.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => customers.insert(oldIndex < 0 ? 0 : oldIndex, customer));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover o cliente.')),
      );
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
        const Text(
          'Cadastro base para vincular empréstimos, cobranças, pagamentos e documentos.',
        ),
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
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
          decoration: const InputDecoration(
            labelText: 'Buscar cliente',
            prefixIcon: Icon(Icons.search),
          ),
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
                subtitle: Text(
                  [
                    customer.identification,
                    if (customer.phone != null) customer.phone!,
                    if (customer.address != null) customer.address!,
                  ].join(' • '),
                ),
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
