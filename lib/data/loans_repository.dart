import '../core/supabase_config.dart';
import '../domain/loan_models.dart';
import '../services/loan_calculator.dart';

class LoansRepository {
  const LoansRepository();

  Future<List<LoanListItem>> listActiveLoans() async {
    final rows = await supabaseRequired.rpc('cobrapp_app_list_loans');
    return (rows as List)
        .map<LoanListItem>((row) => LoanListItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<LoanDetail> getLoanDetail(String loanId) async {
    final response = await supabaseRequired.rpc(
      'cobrapp_app_get_loan_detail',
      params: {'p_loan_id': loanId},
    );
    if (response == null) {
      throw StateError('Empréstimo não encontrado.');
    }
    final json = Map<String, dynamic>.from(response as Map);
    final installmentRows = (json['installments'] as List? ?? const <dynamic>[])
        .map<LoanInstallmentDetail>((row) => LoanInstallmentDetail.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    final paymentRows = (json['payments'] as List? ?? const <dynamic>[])
        .map<LoanPaymentDetail>((row) => LoanPaymentDetail.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    return LoanDetail.fromJson(json, installmentRows, paymentRows);
  }

  Future<void> registerPartialPayment({
    required LoanInstallmentDetail installment,
    required double amount,
    double lateCharge = 0,
    String method = 'manual',
    String? note,
  }) async {
    await supabaseRequired.rpc(
      'cobrapp_app_register_payment',
      params: {
        'p_installment_id': installment.id,
        'p_amount': _money(amount),
        'p_late_charge': _money(lateCharge),
        'p_method': method,
        'p_note': note,
      },
    );
  }

  Future<String> createLoan({
    required String customerId,
    required LoanCalculationInput input,
    required LoanCalculationResult result,
    String? note,
  }) async {
    final installments = result.installments
        .map(
          (installment) => {
            'number': installment.number,
            'due_date': _date(installment.dueDate),
            'principal': _money(installment.principal),
            'interest': _money(installment.interest),
            'total': _money(installment.total),
          },
        )
        .toList();

    final loanId = await supabaseRequired.rpc(
      'cobrapp_app_create_loan',
      params: {
        'p_customer_id': customerId,
        'p_principal': _money(input.principal),
        'p_interest_rate': input.interestRatePercent,
        'p_interest_type': input.interestType.toDatabaseValue(),
        'p_payments_number': input.paymentsNumber,
        'p_payment_frequency': input.paymentFrequency.toDatabaseValue(),
        'p_start_date': _date(input.startDate),
        'p_end_date': _date(result.endDate),
        'p_total_interest': _money(result.totalInterest),
        'p_total_debt': _money(result.totalDebt),
        'p_note': note,
        'p_installments': installments,
      },
    );
    return loanId.toString();
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
    final difference = cleanToday.difference(cleanDue).inDays;
    return difference < 0 ? 0 : difference;
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
    final paidAtValue = json['payment_date'] ?? json['created_at'];
    return LoanPaymentDetail(
      id: json['id'].toString(),
      loanId: json['loan_id'].toString(),
      installmentId: json['installment_id']?.toString(),
      paidAt: DateTime.tryParse(paidAtValue.toString()) ?? DateTime.now(),
      totalPaid: _toDouble(json['amount']),
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
    String customerName = json['customer_name']?.toString() ?? 'Cliente';
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
