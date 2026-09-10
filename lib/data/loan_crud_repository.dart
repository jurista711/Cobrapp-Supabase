import '../core/licensed_rpc.dart';
import '../services/loan_calculator.dart';
import 'loans_repository.dart';

extension LoanCrudRepository on LoansRepository {
  Future<String> updateLoan({
    required String loanId,
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

    final response = await licensedRpc(
      'cobrapp_app_update_loan',
      params: {
        'p_loan_id': loanId,
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
    return response.toString();
  }

  Future<void> deleteLoan(String loanId) async {
    await licensedRpc('cobrapp_app_delete_loan', params: {'p_loan_id': loanId});
  }
}

String _date(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

double _money(double value) => double.parse(value.toStringAsFixed(2));
