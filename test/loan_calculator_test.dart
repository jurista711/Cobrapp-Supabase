import 'package:cobrapp_supabase/domain/loan_models.dart';
import 'package:cobrapp_supabase/services/loan_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = LoanCalculator();
  final startDate = DateTime(2026, 9, 9);

  test('calcula juros sobre capital inicial', () {
    final result = calculator.calculate(
      LoanCalculationInput(
        principal: 3500,
        interestRatePercent: 30,
        paymentsNumber: 5,
        interestType: InterestType.initialCapital,
        paymentFrequency: PaymentFrequency.biweekly,
        startDate: startDate,
      ),
    );

    expect(result.totalInterest, 1050);
    expect(result.totalDebt, 4550);
    expect(result.paymentAmount, 910);
    expect(result.installments.first.principal, 700);
    expect(result.installments.first.interest, 210);
    expect(result.installments.first.total, 910);
    expect(result.installments.first.dueDate, DateTime(2026, 9, 24));
  });

  test('calcula juros em cada parcela', () {
    final result = calculator.calculate(
      LoanCalculationInput(
        principal: 3500,
        interestRatePercent: 30,
        paymentsNumber: 5,
        interestType: InterestType.eachPayment,
        paymentFrequency: PaymentFrequency.weekly,
        startDate: startDate,
      ),
    );

    expect(result.totalInterest, 5250);
    expect(result.totalDebt, 8750);
    expect(result.paymentAmount, 1750);
    expect(result.installments.first.principal, 700);
    expect(result.installments.first.interest, 1050);
    expect(result.installments.first.total, 1750);
    expect(result.installments.first.dueDate, DateTime(2026, 9, 16));
  });

  test('calcula juros compostos bancários', () {
    final result = calculator.calculate(
      LoanCalculationInput(
        principal: 3500,
        interestRatePercent: 30,
        paymentsNumber: 5,
        interestType: InterestType.bankCompound,
        paymentFrequency: PaymentFrequency.monthly,
        startDate: startDate,
      ),
    );

    expect(result.paymentAmount, 1437.04);
    expect(result.totalDebt, 7185.18);
    expect(result.totalInterest, closeTo(3685.18, 0.01));
    expect(result.installments.first.principal, 387.04);
    expect(result.installments.first.interest, 1050);
    expect(result.installments[1].principal, 503.15);
    expect(result.installments[1].interest, 933.89);
  });
}
