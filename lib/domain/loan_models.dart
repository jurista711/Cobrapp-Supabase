enum InterestType {
  initialCapital,
  eachPayment,
  bankCompound,
}

enum PaymentFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  custom,
}

enum LoanStatus {
  active,
  completed,
  cancelled,
  renewed,
}

enum InstallmentStatus {
  pending,
  paid,
  overdue,
}

class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    required this.identification,
    this.phone,
    this.email,
    this.address,
    this.active = true,
  });

  final String id;
  final String fullName;
  final String identification;
  final String? phone;
  final String? email;
  final String? address;
  final bool active;
}

class Loan {
  const Loan({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.interestRate,
    required this.interestType,
    required this.paymentsNumber,
    required this.paymentFrequency,
    required this.startDate,
    required this.endDate,
    required this.totalInterest,
    required this.totalDebt,
    this.lateInterestRate,
    this.daysOfGrace = 0,
    this.lateFee = 0,
    this.note,
    this.status = LoanStatus.active,
  });

  final String id;
  final String customerId;
  final double amount;
  final double interestRate;
  final InterestType interestType;
  final int paymentsNumber;
  final PaymentFrequency paymentFrequency;
  final DateTime startDate;
  final DateTime endDate;
  final double totalInterest;
  final double totalDebt;
  final double? lateInterestRate;
  final int daysOfGrace;
  final double lateFee;
  final String? note;
  final LoanStatus status;
}

class Installment {
  const Installment({
    required this.id,
    required this.loanId,
    required this.number,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.total,
    this.paidAmount = 0,
    this.lateInterestPaid = 0,
    this.status = InstallmentStatus.pending,
  });

  final String id;
  final String loanId;
  final int number;
  final DateTime dueDate;
  final double principal;
  final double interest;
  final double total;
  final double paidAmount;
  final double lateInterestPaid;
  final InstallmentStatus status;
}

class Payment {
  const Payment({
    required this.id,
    required this.loanId,
    required this.date,
    required this.totalPaid,
    this.installmentId,
    this.principalPaid = 0,
    this.interestPaid = 0,
    this.lateInterestPaid = 0,
    this.extraCapitalPaid = 0,
    this.method,
    this.note,
  });

  final String id;
  final String loanId;
  final String? installmentId;
  final DateTime date;
  final double totalPaid;
  final double principalPaid;
  final double interestPaid;
  final double lateInterestPaid;
  final double extraCapitalPaid;
  final String? method;
  final String? note;
}
