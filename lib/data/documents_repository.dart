import '../core/supabase_config.dart';

class DocumentsRepository {
  const DocumentsRepository();

  Future<List<DocumentListItem>> listDocuments() async {
    final client = supabaseOrNull;
    if (client == null) {
      return const <DocumentListItem>[];
    }

    final rows = await client
        .from('generated_documents')
        .select('id, title, document_type, created_at, customers(full_name), loans(total_debt)')
        .order('created_at', ascending: false);

    return rows
        .map<DocumentListItem>((row) => DocumentListItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> createDocument({
    required String title,
    required String documentType,
    required String body,
    String? customerId,
    String? loanId,
  }) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    await client.from('generated_documents').insert({
      'customer_id': customerId,
      'loan_id': loanId,
      'title': title,
      'document_type': documentType,
      'snapshot': {
        'body': body,
        'generated_by': 'cobrapp_supabase',
      },
    });
  }
}

class DocumentListItem {
  const DocumentListItem({
    required this.id,
    required this.title,
    required this.documentType,
    required this.createdAt,
    required this.customerName,
    required this.totalDebt,
  });

  final String id;
  final String title;
  final String documentType;
  final DateTime createdAt;
  final String customerName;
  final double totalDebt;

  factory DocumentListItem.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'];
    final loan = json['loans'];

    return DocumentListItem(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? 'Documento',
      documentType: json['document_type']?.toString() ?? 'documento',
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      customerName: customer is Map<String, dynamic>
          ? customer['full_name']?.toString() ?? 'Cliente'
          : 'Cliente',
      totalDebt: loan is Map<String, dynamic> ? _toDouble(loan['total_debt']) : 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}
