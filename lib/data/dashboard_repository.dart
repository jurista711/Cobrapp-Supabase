import '../core/licensed_rpc.dart';

class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSummary> loadSummary() async {
    final response = await licensedRpc('cobrapp_app_dashboard_summary');
    final json = Map<String, dynamic>.from(response as Map);
    return DashboardSummary(
      customersCount: _toInt(json['customers_count']),
      activeLoansCount: _toInt(json['active_loans_count']),
      totalLoaned: _toDouble(json['total_loaned']),
      totalDebt: _toDouble(json['total_debt']),
      pendingAmount: _toDouble(json['pending_amount']),
      pendingInstallments: _toInt(json['pending_installments']),
      overdueInstallments: _toInt(json['overdue_installments']),
      receivedToday: _toDouble(json['received_today']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
