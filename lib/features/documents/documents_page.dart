import 'package:flutter/material.dart';

import '../../core/supabase_config.dart';
import '../../data/customers_repository.dart';
import '../../data/documents_repository.dart';
import '../../data/loans_repository.dart';
import '../../domain/loan_models.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final customersRepository = const CustomersRepository();
  final loansRepository = const LoansRepository();
  final documentsRepository = const DocumentsRepository();
  final observationController = TextEditingController();

  List<Customer> customers = const <Customer>[];
  List<LoanListItem> loans = const <LoanListItem>[];
  List<DocumentListItem> documents = const <DocumentListItem>[];
  String? selectedCustomerId;
  String? selectedLoanId;
  String documentType = 'contrato_emprestimo';
  bool loading = true;
  bool saving = false;
  String statusMessage = 'Carregando documentos...';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    observationController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      statusMessage = 'Carregando documentos...';
    });

    try {
      final loadedCustomers = await customersRepository.listCustomers();
      final loadedLoans = await loansRepository.listActiveLoans();
      final loadedDocuments = await documentsRepository.listDocuments();
      if (!mounted) return;
      setState(() {
        customers = loadedCustomers;
        loans = loadedLoans;
        documents = loadedDocuments;
        selectedCustomerId ??= loadedCustomers.isEmpty ? null : loadedCustomers.first.id;
        selectedLoanId ??= loadedLoans.isEmpty ? null : loadedLoans.first.id;
        statusMessage = hasSupabaseConfig
            ? 'Documentos conectados ao Supabase.'
            : 'Supabase não configurado neste APK.';
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        statusMessage = 'Erro ao carregar documentos. Verifique internet/Supabase.';
      });
    }
  }

  Future<void> generateDocument() async {
    if (!hasSupabaseConfig) {
      showMessage('Supabase não configurado neste APK.');
      return;
    }

    if (selectedCustomerId == null) {
      showMessage('Cadastre um cliente antes de gerar documento.');
      return;
    }

    final customer = customers.firstWhere((item) => item.id == selectedCustomerId);
    final loan = selectedLoanId == null
        ? null
        : loans.where((item) => item.id == selectedLoanId).cast<LoanListItem?>().firstOrNull;

    final body = buildDocumentBody(customer: customer, loan: loan);
    final title = documentType == 'recibo_pagamento'
        ? 'Recibo - ${customer.fullName}'
        : 'Contrato - ${customer.fullName}';

    setState(() => saving = true);
    try {
      await documentsRepository.createDocument(
        title: title,
        documentType: documentType,
        body: body,
        customerId: customer.id,
        loanId: loan?.id,
      );
      await loadData();
      showDocumentPreview(title, body);
    } catch (_) {
      showMessage('Erro ao salvar documento no Supabase.');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  String buildDocumentBody({required Customer customer, required LoanListItem? loan}) {
    final observation = observationController.text.trim();
    final amount = loan == null ? 'não informado' : formatMoney(loan.totalDebt);
    final now = formatDate(DateTime.now());

    if (documentType == 'recibo_pagamento') {
      return 'RECIBO DE PAGAMENTO\n\nRecebi de ${customer.fullName}, documento ${customer.identification}, o valor referente ao acordo/emprestimo cadastrado no CobrApp.\n\nValor relacionado: $amount\nData: $now\n\nObservacao: ${observation.isEmpty ? 'Sem observacao.' : observation}\n\nAssinatura: ______________________________';
    }

    return 'CONTRATO DE EMPRESTIMO\n\nCredor e devedor declaram que ${customer.fullName}, documento ${customer.identification}, possui emprestimo registrado no CobrApp Supabase.\n\nValor total relacionado: $amount\nData de emissao: $now\n\nO pagamento devera seguir as parcelas cadastradas no sistema. Em caso de atraso, podera haver cobranca conforme combinada entre as partes.\n\nObservacao: ${observation.isEmpty ? 'Sem observacao.' : observation}\n\nAssinatura do cliente: ______________________________\nAssinatura do credor: ______________________________';
  }

  void showDocumentPreview(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('FECHAR'),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String formatMoney(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final customerLoans = selectedCustomerId == null
        ? loans
        : loans.where((loan) => loan.customerId == selectedCustomerId).toList();

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Documentos', style: Theme.of(context).textTheme.titleLarge),
              ),
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusMessage),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Gerar documento', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: documentType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'contrato_emprestimo', child: Text('Contrato de emprestimo')),
                      DropdownMenuItem(value: 'recibo_pagamento', child: Text('Recibo de pagamento')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => documentType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (customers.isEmpty)
                    const Text('Cadastre um cliente primeiro.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: customers
                          .map((customer) => DropdownMenuItem(value: customer.id, child: Text(customer.fullName)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCustomerId = value;
                          final filtered = loans.where((loan) => loan.customerId == value).toList();
                          selectedLoanId = filtered.isEmpty ? null : filtered.first.id;
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  if (customerLoans.isEmpty)
                    const Text('Nenhum emprestimo para este cliente.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedLoanId,
                      decoration: const InputDecoration(labelText: 'Emprestimo'),
                      items: customerLoans
                          .map(
                            (loan) => DropdownMenuItem(
                              value: loan.id,
                              child: Text('${formatMoney(loan.totalDebt)} - ${formatDate(loan.endDate)}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => selectedLoanId = value),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observationController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Observacao'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: saving ? null : generateDocument,
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.description_outlined),
                    label: Text(saving ? 'Gerando...' : 'Gerar documento'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Documentos gerados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (documents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nenhum documento gerado ainda.'),
              ),
            )
          else
            for (final document in documents)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(document.title),
                  subtitle: Text('${document.customerName} • ${document.documentType}'),
                  trailing: Text(formatDate(document.createdAt)),
                ),
              ),
        ],
      ),
    );
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
