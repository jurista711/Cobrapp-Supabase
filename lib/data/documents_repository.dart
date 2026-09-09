import '../core/supabase_config.dart';

class DocumentsRepository {
  const DocumentsRepository();

  Future<List<DocumentListItem>> listDocuments() async {
    final rows = await supabaseRequired.rpc('cobrapp_app_list_documents');
    return (rows as List)
        .map<DocumentListItem>((row) => DocumentListItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> createDocument({
    required String title,
    required String documentType,
    required String body,
    String? customerId,
    String? loanId,
  }) async {
    await supabaseRequired.rpc(
      'cobrapp_app_create_document',
      params: {
        'p_title': title,
        'p_document_type': documentType,
        'p_body': body,
        'p_customer_id': customerId,
        'p_loan_id': loanId,
      },
    );
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
    return DocumentListItem(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? 'Documento',
      documentType: json['document_type']?.toString() ?? 'documento',
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      customerName: json['customer_name']?.toString() ?? 'Cliente',
      totalDebt: _toDouble(json['total_debt']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}
