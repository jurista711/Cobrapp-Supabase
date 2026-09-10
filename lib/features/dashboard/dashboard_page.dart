import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/licensed_rpc.dart';
import '../../data/dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.onNewCustomer,
    required this.onNewLoan,
    required this.onRegisterPayment,
    required this.onCalculator,
  });

  final VoidCallback onNewCustomer;
  final VoidCallback onNewLoan;
  final VoidCallback onRegisterPayment;
  final VoidCallback onCalculator;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final repository = const DashboardRepository();

  DashboardSummary summary = const DashboardSummary.empty();
  bool loading = true;
  _AppUpdateInfo? updateInfo;

  @override
  void initState() {
    super.initState();
    loadSummary();
    checkForUpdate();
  }

  Future<void> loadSummary() async {
    setState(() => loading = true);
    try {
      final loaded = await repository.loadSummary();
      if (!mounted) return;
      setState(() {
        summary = loaded;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(package.buildNumber) ?? 0;
      final response = await licensedRpc('cobrapp_app_latest_version');
      if (response == null || !mounted) return;
      final map = Map<String, dynamic>.from(response as Map);
      final remoteCode = int.tryParse(map['version_code']?.toString() ?? '') ?? 0;
      if (remoteCode <= currentCode) {
        if (updateInfo != null) setState(() => updateInfo = null);
        return;
      }
      setState(() => updateInfo = _AppUpdateInfo.fromJson(map));
    } catch (_) {
      // A checagem de atualização não deve impedir o uso normal do aplicativo.
    }
  }

  Future<void> openUpdate() async {
    final info = updateInfo;
    if (info == null) return;
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link da atualização.')),
      );
    }
  }

  String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await loadSummary();
        await checkForUpdate();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Olá, Berlan 👋', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Que bom te ver por aqui!', style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF111C31),
                    child: Icon(Icons.notifications_none_rounded),
                  ),
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (updateInfo != null) ...[
            const SizedBox(height: 14),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: openUpdate,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF7C3AED),
                        child: Icon(Icons.system_update_alt_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(updateInfo!.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text('Versão ${updateInfo!.versionName}', style: const TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.w700)),
                            if (updateInfo!.message.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(updateInfo!.message, style: const TextStyle(color: Color(0xFFCBD5E1))),
                            ],
                            const SizedBox(height: 8),
                            const Text('Toque para atualizar', style: TextStyle(color: Color(0xFFBFA7FF), fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saldo em carteira', style: TextStyle(color: Color(0xFFE9D5FF))),
                      const SizedBox(height: 4),
                      Text(money(summary.pendingAmount), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.trending_up_rounded, size: 17, color: Color(0xFF86EFAC)),
                          SizedBox(width: 4),
                          Text('Carteira ativa', style: TextStyle(color: Color(0xFFDCFCE7), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.visibility_outlined, color: Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _MetricTile(icon: Icons.account_balance_wallet_outlined, label: 'Total emprestado', value: money(summary.totalLoaned), accent: const Color(0xFF10B981)),
              _MetricTile(icon: Icons.payments_outlined, label: 'Recebido hoje', value: money(summary.receivedToday), accent: const Color(0xFF3B82F6)),
              _MetricTile(icon: Icons.warning_amber_rounded, label: 'Em atraso', value: '${summary.overdueInstallments} parcelas', accent: const Color(0xFFEF4444)),
              _MetricTile(icon: Icons.people_alt_outlined, label: 'Clientes', value: summary.customersCount.toString(), accent: const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Ações rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'Novo\ncliente', accent: const Color(0xFF7C3AED), onTap: widget.onNewCustomer)),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'Novo\nempréstimo', accent: const Color(0xFF059669), onTap: widget.onNewLoan)),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.payments_rounded, label: 'Registrar\npagamento', accent: const Color(0xFF2563EB), onTap: widget.onRegisterPayment)),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(icon: Icons.calculate_rounded, label: 'Calculadora', accent: const Color(0xFFEA580C), onTap: widget.onCalculator)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Text('Resumo da carteira', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              if (loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(onPressed: loadSummary, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          Card(
            child: Column(
              children: [
                _SummaryLine(icon: Icons.description_outlined, label: 'Empréstimos ativos', value: summary.activeLoansCount.toString()),
                const Divider(height: 1, indent: 54),
                _SummaryLine(icon: Icons.event_note_outlined, label: 'Parcelas pendentes', value: summary.pendingInstallments.toString()),
                const Divider(height: 1, indent: 54),
                _SummaryLine(icon: Icons.schedule_rounded, label: 'Parcelas vencidas', value: summary.overdueInstallments.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppUpdateInfo {
  const _AppUpdateInfo({
    required this.versionName,
    required this.title,
    required this.message,
    required this.downloadUrl,
  });

  final String versionName;
  final String title;
  final String message;
  final String downloadUrl;

  factory _AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return _AppUpdateInfo(
      versionName: json['version_name']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Nova atualização disponível',
      message: json['message']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.icon, required this.label, required this.value, required this.accent});
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: accent.withValues(alpha: .16), child: Icon(icon, color: accent, size: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.accent, required this.onTap});
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(15)),
            child: Center(child: Icon(icon, color: Colors.white, size: 27)),
          ),
          const SizedBox(height: 7),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.1)),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFA78BFA)),
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}
