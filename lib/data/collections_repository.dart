import '../core/supabase_config.dart';

class CollectionsRepository {
  const CollectionsRepository();

  Future<List<CollectionInstallment>> listPendingInstallments() async {
    final client = supabaseOrNull;
    if (client == null) {
      return const <CollectionInstallment>[];
    }

    final rows = await client
        .from('installments')
        .select('id, loan_id, number, due_date, principal, interest, total, paid_amount, status, loans(id, customer_id, customers(full_name, phone, identification))')
        .eq('status', 'pending')
        .order('due_date', ascending: true);

    return rows
        .map<CollectionInstallment>((row) => CollectionInstallment.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> markInstallmentPaid(CollectionInstallment installment) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    final now = DateTime.now().toIso8601String();

    await client.from('payments').insert({
      'loan_id': installment.loanId,
      'installment_id': installment.id,
      'paid_at': now,
      'total_paid': _money(installment.remainingAmount),
      'principal_paid': _money(installment.principal),
      'interest_paid': _money(installment.interest),
      'late_interest_paid': 0,
      'extra_capital_paid': 0,
      'method': 'manual',
      'note': 'Pagamento registrado pela tela Cobranças',
    });

    await client
        .from('installments')
        .update({
          'paid_amount': _money(installment.total),
          'status': 'paid',
          'updated_at': now,
        })
        .eq('id', installment.id);
  }

  double _money(double value) => double.parse(value.toStringAsFixed(2));
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
    final loan = json['loans'];
    Map<String, dynamic>? customer;
    String loanId = json['loan_id'].toString();

    if (loan is Map<String, dynamic>) {
      loanId = loan['id']?.toString() ?? loanId;
      final rawCustomer = loan['customers'];
      if (rawCustomer is Map<String, dynamic>) {
        customer = rawCustomer;
      }
    }

    return CollectionInstallment(
      id: json['id'].toString(),
      loanId: loanId,
      number: int.tryParse(json['number'].toString()) ?? 0,
      dueDate: DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now(),
      principal: _toDouble(json['principal']),
      interest: _toDouble(json['interest']),
      total: _toDouble(json['total']),
      paidAmount: _toDouble(json['paid_amount']),
      status: json['status']?.toString() ?? 'pending',
      customerName: customer?['full_name']?.toString() ?? 'Cliente',
      customerPhone: customer?['phone']?.toString(),
      customerIdentification: customer?['identification']?.toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
