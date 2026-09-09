import '../core/supabase_config.dart';

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSummary> loadSummary() async {
    final client = supabaseOrNull;
    if (client == null) {
      return const DashboardSummary.empty();
    }

    final customersRows = await client
        .from('customers')
        .select('id')
        .eq('active', true);

    final loansRows = await client
        .from('loans')
        .select('amount, total_debt, status')
        .eq('status', 'active');

    final installmentsRows = await client
        .from('installments')
        .select('total, paid_amount, due_date, status')
        .inFilter('status', ['pending', 'overdue']);

    final startToday = DateTime.now();
    final start = DateTime(startToday.year, startToday.month, startToday.day);
    final end = start.add(const Duration(days: 1));

    final paymentsRows = await client
        .from('payments')
        .select('total_paid, paid_at')
        .gte('paid_at', start.toIso8601String())
        .lt('paid_at', end.toIso8601String());

    double totalLoaned = 0;
    double totalDebt = 0;
    for (final row in loansRows) {
      final json = Map<String, dynamic>.from(row);
      totalLoaned += _toDouble(json['amount']);
      totalDebt += _toDouble(json['total_debt']);
    }

    double pendingAmount = 0;
    int pendingInstallments = 0;
    int overdueInstallments = 0;
    final today = DateTime.now();
    final onlyToday = DateTime(today.year, today.month, today.day);

    for (final row in installmentsRows) {
      final json = Map<String, dynamic>.from(row);
      final total = _toDouble(json['total']);
      final paid = _toDouble(json['paid_amount']);
      final remaining = total - paid;
      if (remaining > 0) {
        pendingAmount += remaining;
      }
      pendingInstallments++;

      final dueDate = DateTime.tryParse(json['due_date'].toString());
      if (dueDate != null) {
        final onlyDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (onlyDue.isBefore(onlyToday)) {
          overdueInstallments++;
        }
      }
    }

    double receivedToday = 0;
    for (final row in paymentsRows) {
      final json = Map<String, dynamic>.from(row);
      receivedToday += _toDouble(json['total_paid']);
    }

    return DashboardSummary(
      customersCount: customersRows.length,
      activeLoansCount: loansRows.length,
      totalLoaned: totalLoaned,
      totalDebt: totalDebt,
      pendingAmount: pendingAmount,
      pendingInstallments: pendingInstallments,
      overdueInstallments: overdueInstallments,
      receivedToday: receivedToday,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.customersCount,
    required this.activeLoansCount,
    required this.totalLoaned,
    required this.totalDebt,
    required this.pendingAmount,
    required this.pendingInstallments,
    required this.overdueInstallments,
    required this.receivedToday,
  });

  const DashboardSummary.empty()
      : customersCount = 0,
        activeLoansCount = 0,
        totalLoaned = 0,
        totalDebt = 0,
        pendingAmount = 0,
        pendingInstallments = 0,
        overdueInstallments = 0,
        receivedToday = 0;

  final int customersCount;
  final int activeLoansCount;
  final double totalLoaned;
  final double totalDebt;
  final double pendingAmount;
  final int pendingInstallments;
  final int overdueInstallments;
  final double receivedToday;
}
