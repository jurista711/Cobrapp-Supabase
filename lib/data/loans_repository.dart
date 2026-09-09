import '../core/supabase_config.dart';
import '../domain/loan_models.dart';
import '../services/loan_calculator.dart';

class LoansRepository {
  const LoansRepository();

  Future<List<LoanListItem>> listActiveLoans() async {
    final client = supabaseOrNull;
    if (client == null) {
      return const <LoanListItem>[];
    }

    final rows = await client
        .from('loans')
        .select('id, customer_id, amount, total_debt, total_interest, payments_number, start_date, end_date, status, customers(full_name)')
        .order('created_at', ascending: false);

    return rows
        .map<LoanListItem>((row) => LoanListItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<LoanDetail> getLoanDetail(String loanId) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    final loanRow = await client
        .from('loans')
        .select('id, customer_id, amount, total_debt, total_interest, interest_rate, interest_type, payment_frequency, payments_number, start_date, end_date, late_interest_rate, days_of_grace, late_fee, note, status, customers(full_name, phone, identification)')
        .eq('id', loanId)
        .single();

    final installmentRows = await client
        .from('installments')
        .select('id, loan_id, number, due_date, principal, interest, total, paid_amount, status')
        .eq('loan_id', loanId)
        .order('number', ascending: true);

    final paymentRows = await client
        .from('payments')
        .select('id, loan_id, installment_id, paid_at, total_paid, principal_paid, interest_paid, late_interest_paid, extra_capital_paid, method, note')
        .eq('loan_id', loanId)
        .order('paid_at', ascending: false);

    return LoanDetail.fromJson(
      Map<String, dynamic>.from(loanRow),
      installmentRows.map<LoanInstallmentDetail>((row) => LoanInstallmentDetail.fromJson(Map<String, dynamic>.from(row))).toList(),
      paymentRows.map<LoanPaymentDetail>((row) => LoanPaymentDetail.fromJson(Map<String, dynamic>.from(row))).toList(),
    );
  }

  Future<void> registerPartialPayment({
    required LoanInstallmentDetail installment,
    required double amount,
    double lateCharge = 0,
    String method = 'manual',
    String? note,
  }) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    final now = DateTime.now().toIso8601String();
    final installmentPart = amount > installment.remainingAmount ? installment.remainingAmount : amount;
    final latePart = amount - installmentPart > 0 ? amount - installmentPart : 0.0;
    final paidAmount = installment.paidAmount + installmentPart;
    final newStatus = paidAmount + 0.009 >= installment.total ? 'paid' : 'pending';
    final cappedPaidAmount = paidAmount > installment.total ? installment.total : paidAmount;

    await client.from('payments').insert({
      'loan_id': installment.loanId,
      'installment_id': installment.id,
      'paid_at': now,
      'total_paid': _money(amount),
      'principal_paid': _money(installmentPart),
      'interest_paid': 0,
      'late_interest_paid': _money(latePart > lateCharge ? lateCharge : latePart),
      'extra_capital_paid': 0,
      'method': method,
      'note': note,
    });

    await client
        .from('installments')
        .update({
          'paid_amount': _money(cappedPaidAmount),
          'status': newStatus,
          'updated_at': now,
        })
        .eq('id', installment.id);

    final pendingRows = await client
        .from('installments')
        .select('id')
        .eq('loan_id', installment.loanId)
        .neq('status', 'paid')
        .limit(1);

    if (pendingRows.isEmpty) {
      await client
          .from('loans')
          .update({'status': 'completed', 'updated_at': now})
          .eq('id', installment.loanId);
    }
  }

  Future<String> createLoan({
    required String customerId,
    required LoanCalculationInput input,
    required LoanCalculationResult result,
    String? note,
  }) async {
    final client = supabaseOrNull;
    if (client == null) {
      throw StateError('Supabase não configurado neste APK.');
    }

    final loanRow = await client
        .from('loans')
        .insert({
          'customer_id': customerId,
          'amount': _money(input.principal),
          'interest_rate': input.interestRatePercent,
          'interest_type': input.interestType.toDatabaseValue(),
          'payments_number': input.paymentsNumber,
          'payment_frequency': input.paymentFrequency.toDatabaseValue(),
          'start_date': _date(input.startDate),
          'end_date': _date(result.endDate),
          'total_interest': _money(result.totalInterest),
          'total_debt': _money(result.totalDebt),
          'late_interest_rate': 0,
          'days_of_grace': 0,
          'late_fee': 0,
          'note': note,
          'status': 'active',
        })
        .select('id')
        .single();

    final loanId = loanRow['id'].toString();

    final installmentRows = result.installments
        .map(
          (installment) => {
            'loan_id': loanId,
            'number': installment.number,
            'due_date': _date(installment.dueDate),
            'principal': _money(installment.principal),
            'interest': _money(installment.interest),
            'total': _money(installment.total),
            'status': 'pending',
          },
        )
        .toList();

    if (installmentRows.isNotEmpty) {
      await client.from('installments').insert(installmentRows);
    }

    return loanId;
  }

  String _date(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  double _money(double value) => double.parse(value.toStringAsFixed(2));
}

class LoanDetail {
  const LoanDetail({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerIdentification,
    required this.amount,
    required this.totalDebt,
    required this.totalInterest,
    required this.interestRate,
    required this.interestType,
    required this.paymentFrequency,
    required this.paymentsNumber,
    required this.startDate,
    required this.endDate,
    required this.lateInterestRate,
    required this.daysOfGrace,
    required this.lateFee,
    this.note,
    required this.status,
    required this.installments,
    required this.payments,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerIdentification;
  final double amount;
  final double totalDebt;
  final double totalInterest;
  final double interestRate;
  final String interestType;
  final String paymentFrequency;
  final int paymentsNumber;
  final DateTime startDate;
  final DateTime endDate;
  final double lateInterestRate;
  final int daysOfGrace;
  final double lateFee;
  final String? note;
  final String status;
  final List<LoanInstallmentDetail> installments;
  final List<LoanPaymentDetail> payments;

  double get totalPaid => installments.fold<double>(0, (sum, item) => sum + item.paidAmount);
  double get remaining => totalDebt - totalPaid < 0 ? 0 : totalDebt - totalPaid;
  int get pendingCount => installments.where((item) => item.status != 'paid').length;
  int get paidCount => installments.where((item) => item.status == 'paid').length;
  int get overdueCount => installments.where((item) => item.isOverdue && item.status != 'paid').length;

  double lateChargeFor(LoanInstallmentDetail installment) {
    if (installment.isPaid || !installment.isOverdue) return 0;
    final billableDays = installment.daysLate - daysOfGrace;
    if (billableDays <= 0) return 0;
    final dailyLateInterest = installment.remainingAmount * (lateInterestRate / 100) * billableDays;
    return lateFee + dailyLateInterest;
  }

  double updatedRemainingFor(LoanInstallmentDetail installment) {
    return installment.remainingAmount + lateChargeFor(installment);
  }

  factory LoanDetail.fromJson(
    Map<String, dynamic> json,
    List<LoanInstallmentDetail> installments,
    List<LoanPaymentDetail> payments,
  ) {
    final customer = json['customers'];
    String customerName = 'Cliente';
    String? customerPhone;
    String? customerIdentification;

    if (customer is Map<String, dynamic>) {
      customerName = customer['full_name']?.toString() ?? customerName;
      customerPhone = customer['phone']?.toString();
      customerIdentification = customer['identification']?.toString();
    }

    return LoanDetail(
      id: json['id'].toString(),
      customerId: json['customer_id'].toString(),
      customerName: customerName,
      customerPhone: customerPhone,
      customerIdentification: customerIdentification,
      amount: _toDouble(json['amount']),
      totalDebt: _toDouble(json['total_debt']),
      totalInterest: _toDouble(json['total_interest']),
      interestRate: _toDouble(json['interest_rate']),
      interestType: json['interest_type']?.toString() ?? '',
      paymentFrequency: json['payment_frequency']?.toString() ?? '',
      paymentsNumber: int.tryParse(json['payments_number'].toString()) ?? 0,
      startDate: DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now(),
      lateInterestRate: _toDouble(json['late_interest_rate']),
      daysOfGrace: int.tryParse(json['days_of_grace'].toString()) ?? 0,
      lateFee: _toDouble(json['late_fee']),
      note: json['note']?.toString(),
      status: json['status']?.toString() ?? 'active',
      installments: installments,
      payments: payments,
    );
  }
}

class LoanInstallmentDetail {
  const LoanInstallmentDetail({
    required this.id,
    required this.loanId,
    required this.number,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.total,
    required this.paidAmount,
    required this.status,
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

  double get remainingAmount {
    final remaining = total - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isPaid => status == 'paid';

  int get daysLate {
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return cleanToday.difference(cleanDue).inDays < 0 ? 0 : cleanToday.difference(cleanDue).inDays;
  }

  bool get isOverdue => daysLate > 0;

  factory LoanInstallmentDetail.fromJson(Map<String, dynamic> json) {
    return LoanInstallmentDetail(
      id: json['id'].toString(),
      loanId: json['loan_id'].toString(),
      number: int.tryParse(json['number'].toString()) ?? 0,
      dueDate: DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now(),
      principal: _toDouble(json['principal']),
      interest: _toDouble(json['interest']),
      total: _toDouble(json['total']),
      paidAmount: _toDouble(json['paid_amount']),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class LoanPaymentDetail {
  const LoanPaymentDetail({
    required this.id,
    required this.loanId,
    this.installmentId,
    required this.paidAt,
    required this.totalPaid,
    required this.method,
    this.note,
  });

  final String id;
  final String loanId;
  final String? installmentId;
  final DateTime paidAt;
  final double totalPaid;
  final String method;
  final String? note;

  factory LoanPaymentDetail.fromJson(Map<String, dynamic> json) {
    return LoanPaymentDetail(
      id: json['id'].toString(),
      loanId: json['loan_id'].toString(),
      installmentId: json['installment_id']?.toString(),
      paidAt: DateTime.tryParse(json['paid_at'].toString()) ?? DateTime.now(),
      totalPaid: _toDouble(json['total_paid']),
      method: json['method']?.toString() ?? 'manual',
      note: json['note']?.toString(),
    );
  }
}

class LoanListItem {
  const LoanListItem({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.totalDebt,
    required this.totalInterest,
    required this.paymentsNumber,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;
  final String customerId;
  final String customerName;
  final double amount;
  final double totalDebt;
  final double totalInterest;
  final int paymentsNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  factory LoanListItem.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'];
    String customerName = 'Cliente';
    if (customer is Map<String, dynamic>) {
      customerName = customer['full_name']?.toString() ?? customerName;
    }

    return LoanListItem(
      id: json['id'].toString(),
      customerId: json['customer_id'].toString(),
      customerName: customerName,
      amount: _toDouble(json['amount']),
      totalDebt: _toDouble(json['total_debt']),
      totalInterest: _toDouble(json['total_interest']),
      paymentsNumber: int.tryParse(json['payments_number'].toString()) ?? 0,
      startDate: DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

extension InterestTypeDatabase on InterestType {
  String toDatabaseValue() {
    switch (this) {
      case InterestType.initialCapital:
        return 'initial_capital';
      case InterestType.eachPayment:
        return 'each_payment';
      case InterestType.bankCompound:
        return 'bank_compound';
    }
  }
}

extension PaymentFrequencyDatabase on PaymentFrequency {
  String toDatabaseValue() {
    switch (this) {
      case PaymentFrequency.daily:
        return 'daily';
      case PaymentFrequency.weekly:
        return 'weekly';
      case PaymentFrequency.biweekly:
        return 'biweekly';
      case PaymentFrequency.monthly:
        return 'monthly';
      case PaymentFrequency.custom:
        return 'custom';
    }
  }
}
