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

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
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
