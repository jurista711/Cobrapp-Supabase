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
  String query = '';
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
                ? 'Recebemos o valor acima referente a pagamento registrado no Roots Cobrança.'
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
      backgroundColor: const Color(0xFF0C1629),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(99))),
              Text('Recibo nº ${item.number}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _DetailLine(label: 'Cliente', value: item.customerName),
              _DetailLine(label: 'Valor', value: money(item.amount)),
              _DetailLine(label: 'Data', value: date(item.issuedAt)),
              const Divider(height: 28),
              Text(item.textContent.isEmpty ? 'Pagamento registrado no Roots Cobrança.' : item.textContent),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => shareReceipt(item),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar'),
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
  String date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final filtered = receipts.where((item) {
      final normalized = query.trim().toLowerCase();
      if (normalized.isEmpty) return true;
      return item.customerName.toLowerCase().contains(normalized) || item.number.toString().contains(normalized);
    }).toList();
    final total = receipts.fold<double>(0, (sum, item) => sum + item.amount);

    return RefreshIndicator(
      onRefresh: loadReceipts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          const Text('Recibos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Histórico de recibos emitidos.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Metric(label: 'Emitidos', value: '${receipts.length}', icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'Total', value: money(total), icon: Icons.payments_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Buscar recibo ou cliente...', prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
          if (!loading && filtered.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Nenhum recibo encontrado.'))),
          for (final item in filtered)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF261B4B), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.receipt_long_outlined, color: Color(0xFFA78BFA)),
                ),
                title: Text('Recibo nº ${item.number}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.customerName} • ${date(item.issuedAt)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(item.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                    const Text('Abrir', style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA))),
                  ],
                ),
                onTap: () => openReceipt(item),
              ),
            ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

class ReceiptItem {
  const ReceiptItem({required this.id, required this.number, required this.customerName, required this.amount, required this.issuedAt, required this.textContent});
  final String id;
  final int number;
  final String customerName;
  final double amount;
  final DateTime issuedAt;
  final String textContent;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: json['id']?.toString() ?? '',
        number: int.tryParse(json['receipt_number']?.toString() ?? '') ?? 0,
        customerName: json['customer_name']?.toString() ?? 'Cliente',
        amount: _toDouble(json['amount']),
        issuedAt: DateTime.tryParse((json['payment_date'] ?? json['created_at']).toString()) ?? DateTime.now(),
        textContent: json['notes']?.toString() ?? '',
      );

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
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
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8)))), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
    );
  }
}
