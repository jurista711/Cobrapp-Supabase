import 'package:flutter/material.dart';

import '../../data/customers_repository.dart';
import '../../domain/loan_models.dart';

class CustomerEditPage extends StatefulWidget {
  const CustomerEditPage({super.key, required this.customer});

  final Customer customer;

  @override
  State<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends State<CustomerEditPage> {
  final repository = const CustomersRepository();
  late final TextEditingController nameController;
  late final TextEditingController documentController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController notesController;
  bool saving = false;
  bool deleting = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.customer.fullName);
    documentController = TextEditingController(text: widget.customer.identification);
    phoneController = TextEditingController(text: widget.customer.phone ?? '');
    addressController = TextEditingController(text: widget.customer.address ?? '');
    notesController = TextEditingController(text: widget.customer.notes ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    documentController.dispose();
    phoneController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }

  String? _optional(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    final document = documentController.text.trim();
    if (name.isEmpty || document.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e documento são obrigatórios.')));
      return;
    }
    setState(() => saving = true);
    try {
      await repository.updateCustomer(
        id: widget.customer.id,
        fullName: name,
        identification: document,
        phone: _optional(phoneController.text),
        address: _optional(addressController.text),
        notes: _optional(notesController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível atualizar o cliente: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar cliente?'),
        content: const Text('Isso apaga o cliente e também os empréstimos, parcelas, pagamentos e recibos vinculados a ele. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar tudo')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => deleting = true);
    try {
      await repository.deleteCustomer(widget.customer.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível apagar o cliente: $e')));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar cliente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: nameController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome completo')),
          const SizedBox(height: 10),
          TextField(controller: documentController, decoration: const InputDecoration(labelText: 'Documento / identificação')),
          const SizedBox(height: 10),
          TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone')),
          const SizedBox(height: 10),
          TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Endereço')),
          const SizedBox(height: 10),
          TextField(controller: notesController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Observação')),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving || deleting ? null : save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Salvando...' : 'Salvar alterações'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving || deleting ? null : delete,
            icon: deleting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_outline),
            label: Text(deleting ? 'Apagando...' : 'Apagar cliente'),
          ),
        ],
      ),
    );
  }
}
