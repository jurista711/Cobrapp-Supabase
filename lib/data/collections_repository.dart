import '../core/licensed_rpc.dart';

class CollectionsRepository {
  const CollectionsRepository();

  Future<List<CollectionInstallment>> listPendingInstallments() async {
    final rows = await licensedRpc('cobrapp_app_list_pending_installments');
    return (rows as List)
        .map<CollectionInstallment>((row) => CollectionInstallment.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> markInstallmentPaid(CollectionInstallment installment) async {
    await licensedRpc(
      'cobrapp_app_mark_installment_paid',
      params: {'p_installment_id': installment.id},
    );
  }
}

class CollectionInstallment {
  const CollectionInstallment({
    required this.id,
    required this.loanId,
    required this.number,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.total,
    required this.paidAmount,
    required this.status,
    required this.customerName,
    this.customerPhone,
    this.customerIdentification,
  });

  final String id;
  final String loanId;
  final int number;
  final DateTime dueDate;
  final double principal;
  final double interest;
  final double total;
  final double paidAmount;
  final String status;
  final String customerName;
  final String? customerPhone;
  final String? customerIdentification;

  double get remainingAmount {
    final remaining = total - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isOverdue {
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return cleanDue.isBefore(cleanToday);
  }

  int get overdueDays {
    if (!isOverdue) return 0;
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return cleanToday.difference(cleanDue).inDays;
  }

  factory CollectionInstallment.fromJson(Map<String, dynamic> json) {
    return CollectionInstallment(
      id: json['id'].toString(),
      loanId: json['loan_id'].toString(),
      number: int.tryParse(json['number'].toString()) ?? 0,
      dueDate: DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now(),
      principal: _toDouble(json['principal']),
      interest: _toDouble(json['interest']),
      total: _toDouble(json['total']),
      paidAmount: _toDouble(json['paid_amount']),
      status: json['status']?.toString() ?? 'pending',
      customerName: json['customer_name']?.toString() ?? 'Cliente',
      customerPhone: json['customer_phone']?.toString(),
      customerIdentification: json['customer_identification']?.toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
