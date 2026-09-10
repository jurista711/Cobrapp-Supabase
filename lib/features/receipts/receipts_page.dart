import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/licensed_rpc.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  bool loading = true;
  String? error;
  List<ReceiptItem> receipts = const [];

  @override
  void initState() {
    super.initState();
    loadReceipts();
  }

  Future<void> loadReceipts() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await licensedRpc('cobrapp_app_list_receipts');
      if (!mounted) return;
      setState(() {
        receipts = (rows as List)
            .map((row) => ReceiptItem.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar os recibos.';
      });
    }
  }

  Future<Uint8List> buildPdf(ReceiptItem item) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Roots Cobrança', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('RECIBO Nº ${item.number}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Cliente: ${item.customerName}'),
            pw.Text('Valor: ${money(item.amount)}'),
            pw.Text('Data: ${date(item.issuedAt)}'),
            pw.SizedBox(height: 18),
            pw.Text(item.textContent.isEmpty
                ? 'Recebemos o valor acima referente a pagamento registrado no CobrApp.'
                : item.textContent),
            pw.SizedBox(height: 42),
            pw.Divider(),
            pw.Text('Assinatura / responsável'),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> printReceipt(ReceiptItem item) async {
    final bytes = await buildPdf(item);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareReceipt(ReceiptItem item) async {
    final bytes = await buildPdf(item);
    await Printing.sharePdf(bytes: bytes, filename: 'recibo-${item.number}.pdf');
  }

  void openReceipt(ReceiptItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recibo nº ${item.number}', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              Text('Cliente: ${item.customerName}'),
              Text('Valor: ${money(item.amount)}'),
              Text('Data: ${date(item.issuedAt)}'),
              const SizedBox(height: 14),
              Text(item.textContent.isEmpty
                  ? 'Pagamento registrado no CobrApp.'
                  : item.textContent),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => shareReceipt(item),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => printReceipt(item),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Imprimir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final total = receipts.fold<double>(0, (sum, item) => sum + item.amount);
    return RefreshIndicator(
      onRefresh: loadReceipts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recibos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Emitidos', value: '${receipts.length}')),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Total', value: money(total))),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          if (!loading && receipts.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Nenhum recibo emitido ainda. Cada novo pagamento gera um recibo numerado automaticamente.'))),
          for (final item in receipts)
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('Recibo nº ${item.number}'),
                subtitle: Text('${item.customerName} • ${date(item.issuedAt)}'),
                trailing: Text(money(item.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => openReceipt(item),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.number,
    required this.customerName,
    required this.amount,
    required this.issuedAt,
    required this.textContent,
  });

  final String id;
  final int number;
  final String customerName;
  final double amount;
  final DateTime issuedAt;
  final String textContent;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id']?.toString() ?? '',
      number: int.tryParse(json['receipt_number']?.toString() ?? '') ?? 0,
      customerName: json['customer_name']?.toString() ?? 'Cliente',
      amount: _toDouble(json['amount']),
      issuedAt: DateTime.tryParse((json['payment_date'] ?? json['created_at']).toString()) ?? DateTime.now(),
      textContent: json['notes']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
