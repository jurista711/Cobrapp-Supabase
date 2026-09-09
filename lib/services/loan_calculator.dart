import 'dart:math' as math;

import '../domain/loan_models.dart';

class LoanCalculationInput {
  const LoanCalculationInput({
    required this.principal,
    required this.interestRatePercent,
    required this.paymentsNumber,
    required this.interestType,
    required this.paymentFrequency,
    required this.startDate,
    this.customIntervalDays = 30,
  });

  final double principal;
  final double interestRatePercent;
  final int paymentsNumber;
  final InterestType interestType;
  final PaymentFrequency paymentFrequency;
  final DateTime startDate;
  final int customIntervalDays;
}

class LoanCalculationResult {
  const LoanCalculationResult({
    required this.principal,
    required this.totalInterest,
    required this.totalDebt,
    required this.paymentAmount,
    required this.endDate,
    required this.installments,
  });

  final double principal;
  final double totalInterest;
  final double totalDebt;
  final double paymentAmount;
  final DateTime endDate;
  final List<LoanInstallmentPreview> installments;
}

class LoanInstallmentPreview {
  const LoanInstallmentPreview({
    required this.number,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.total,
    required this.remainingPrincipal,
  });

  final int number;
  final DateTime dueDate;
  final double principal;
  final double interest;
  final double total;
  final double remainingPrincipal;
}

class LoanCalculator {
  const LoanCalculator();

  LoanCalculationResult calculate(LoanCalculationInput input) {
    _validate(input);

    final rate = input.interestRatePercent / 100;
    final installments = switch (input.interestType) {
      InterestType.initialCapital => _initialCapital(input, rate),
      InterestType.eachPayment => _eachPayment(input, rate),
      InterestType.bankCompound => _bankCompound(input, rate),
    };

    final totalDebt = _round2(
      installments.fold<double>(0, (sum, item) => sum + item.total),
    );
    final totalInterest = _round2(
      installments.fold<double>(0, (sum, item) => sum + item.interest),
    );

    return LoanCalculationResult(
      principal: _round2(input.principal),
      totalInterest: totalInterest,
      totalDebt: totalDebt,
      paymentAmount: installments.isEmpty ? 0 : installments.first.total,
      endDate: installments.last.dueDate,
      installments: installments,
    );
  }

  void _validate(LoanCalculationInput input) {
    if (input.principal <= 0) {
      throw ArgumentError.value(input.principal, 'principal', 'deve ser maior que zero');
    }
    if (input.interestRatePercent < 0) {
      throw ArgumentError.value(
        input.interestRatePercent,
        'interestRatePercent',
        'não pode ser negativa',
      );
    }
    if (input.paymentsNumber <= 0) {
      throw ArgumentError.value(
        input.paymentsNumber,
        'paymentsNumber',
        'deve ser maior que zero',
      );
    }
    if (input.customIntervalDays <= 0) {
      throw ArgumentError.value(
        input.customIntervalDays,
        'customIntervalDays',
        'deve ser maior que zero',
      );
    }
  }

  List<LoanInstallmentPreview> _initialCapital(
    LoanCalculationInput input,
    double rate,
  ) {
    final totalInterest = input.principal * rate;
    final principalPart = input.principal / input.paymentsNumber;
    final interestPart = totalInterest / input.paymentsNumber;
    final totalPart = (input.principal + totalInterest) / input.paymentsNumber;

    var remaining = input.principal;
    return List.generate(input.paymentsNumber, (index) {
      final number = index + 1;
      final principal = number == input.paymentsNumber ? remaining : principalPart;
      remaining = _round2(remaining - principal);
      return LoanInstallmentPreview(
        number: number,
        dueDate: dueDateFor(input, number),
        principal: _round2(principal),
        interest: _round2(interestPart),
        total: _round2(totalPart),
        remainingPrincipal: number == input.paymentsNumber ? 0 : remaining,
      );
    });
  }

  List<LoanInstallmentPreview> _eachPayment(
    LoanCalculationInput input,
    double rate,
  ) {
    final principalPart = input.principal / input.paymentsNumber;
    final interestPart = input.principal * rate;
    final totalPart = principalPart + interestPart;

    var remaining = input.principal;
    return List.generate(input.paymentsNumber, (index) {
      final number = index + 1;
      final principal = number == input.paymentsNumber ? remaining : principalPart;
      remaining = _round2(remaining - principal);
      return LoanInstallmentPreview(
        number: number,
        dueDate: dueDateFor(input, number),
        principal: _round2(principal),
        interest: _round2(interestPart),
        total: _round2(totalPart),
        remainingPrincipal: number == input.paymentsNumber ? 0 : remaining,
      );
    });
  }

  List<LoanInstallmentPreview> _bankCompound(
    LoanCalculationInput input,
    double rate,
  ) {
    final payment = rate == 0
        ? input.principal / input.paymentsNumber
        : input.principal * rate / (1 - math.pow(1 + rate, -input.paymentsNumber));

    var remaining = input.principal;
    return List.generate(input.paymentsNumber, (index) {
      final number = index + 1;
      final interest = remaining * rate;
      final principal = number == input.paymentsNumber ? remaining : payment - interest;
      remaining = _round2(remaining - principal);
      final total = number == input.paymentsNumber ? principal + interest : payment;

      return LoanInstallmentPreview(
        number: number,
        dueDate: dueDateFor(input, number),
        principal: _round2(principal),
        interest: _round2(interest),
        total: _round2(total),
        remainingPrincipal: number == input.paymentsNumber ? 0 : remaining,
      );
    });
  }

  DateTime dueDateFor(LoanCalculationInput input, int paymentNumber) {
    return switch (input.paymentFrequency) {
      PaymentFrequency.daily => input.startDate.add(Duration(days: paymentNumber)),
      PaymentFrequency.weekly => input.startDate.add(Duration(days: paymentNumber * 7)),
      PaymentFrequency.biweekly => input.startDate.add(Duration(days: paymentNumber * 15)),
      PaymentFrequency.monthly => _addMonths(input.startDate, paymentNumber),
      PaymentFrequency.custom => input.startDate.add(
          Duration(days: paymentNumber * input.customIntervalDays),
        ),
    };
  }

  DateTime _addMonths(DateTime date, int months) {
    final targetMonth = date.month + months;
    final year = date.year + ((targetMonth - 1) ~/ 12);
    final month = ((targetMonth - 1) % 12) + 1;
    final day = math.min(date.day, DateTime(year, month + 1, 0).day);
    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;
}
