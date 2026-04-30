import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class YearlySalesScreen extends StatefulWidget {
  const YearlySalesScreen({super.key});
  @override
  State<YearlySalesScreen> createState() => _YearlySalesScreenState();
}

class _YearlySalesScreenState extends State<YearlySalesScreen> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _monthly = [];
  int? _selectedYear;
  bool _loading = true;
  bool _loadingMonthly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getYearlySummary();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMonthly(int year) async {
    setState(() { _selectedYear = year; _loadingMonthly = true; _monthly = []; });
    try {
      final list = await context.read<ApiService>().getMonthlySummary(year);
      if (mounted) setState(() { _monthly = list; _loadingMonthly = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMonthly = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('yearlySales.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_data.isEmpty)
            Expanded(child: Center(
              child: Text(loc.t('yearlySales.empty'),
                style: const TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildYearlyTable(loc)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildMonthlyPanel(loc)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 연도별 테이블 ─────────────────────────────────────
  Widget _buildYearlyTable(LocaleProvider loc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            showCheckboxColumn: false,
            columns: [
              DataColumn(label: Text(loc.t('acc.col.year'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.ticketRev'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.extraRev'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.purchase'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.netRev'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('yearlySales.col.newMembers'),
                style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _data.map((row) {
              final year = row['year'] as int? ?? 0;
              final ticket = row['ticketRevenue'] as int? ?? 0;
              final extra = row['extraRevenue'] as int? ?? 0;
              final purchase = row['purchase'] as int? ?? 0;
              final net = ticket + extra - purchase;
              final isSelected = _selectedYear == year;
              return DataRow(
                selected: isSelected,
                onSelectChanged: (_) => _loadMonthly(year),
                cells: [
                  DataCell(Row(children: [
                    Text(loc.t('yearlySales.yearLabel', params: {'y': year.toString()}),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ])),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(ticket)}))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(extra)}))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(purchase)}),
                    style: const TextStyle(color: Colors.red))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(net)}),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)))),
                  DataCell(Text(loc.t('yearlySales.newCount',
                    params: {'n': (row['newMembers'] ?? 0).toString()}))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── 월별 상세 패널 ──────────────────────────────────
  Widget _buildMonthlyPanel(LocaleProvider loc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.calendar_month, color: Color(0xFF1565C0), size: 20),
              const SizedBox(width: 8),
              Text(loc.t('monthlySales.title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedYear != null)
                Text(loc.t('yearlySales.yearLabel', params: {'y': _selectedYear.toString()}),
                  style: TextStyle(color: Colors.grey.shade700)),
            ]),
            const Divider(height: 20),
            Expanded(child: _buildMonthlyBody(loc)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBody(LocaleProvider loc) {
    if (_selectedYear == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.touch_app, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(loc.t('yearlySales.selectYear'),
            style: const TextStyle(color: Colors.grey)),
        ]),
      );
    }
    if (_loadingMonthly) return const Center(child: CircularProgressIndicator());
    if (_monthly.isEmpty) {
      return Center(child: Text(loc.t('acc.emptyData'), style: const TextStyle(color: Colors.grey)));
    }

    final total = _monthly.fold<int>(0, (s, e) {
      final ticket = e['ticketRevenue'] as int? ?? 0;
      final extra = e['extraRevenue'] as int? ?? 0;
      final purchase = e['purchase'] as int? ?? 0;
      return s + ticket + extra - purchase;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet, color: Color(0xFF1565C0), size: 18),
            const SizedBox(width: 8),
            Text(loc.t('monthlySales.yearTotal', params: {'y': _selectedYear.toString()}),
              style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
            const Spacer(),
            Text(loc.t('acc.wonAmount', params: {'v': _fmt(total)}),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 15)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 12,
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 42,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: [
                DataColumn(label: Text(loc.t('acc.col.month'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text(loc.t('acc.col.ticketRev'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text(loc.t('acc.col.extraRev'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text(loc.t('acc.col.netRev'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: _monthly.map((row) {
                final month = row['month'] as int? ?? 0;
                final ticket = row['ticketRevenue'] as int? ?? 0;
                final extra = row['extraRevenue'] as int? ?? 0;
                final purchase = row['purchase'] as int? ?? 0;
                final net = ticket + extra - purchase;
                return DataRow(cells: [
                  DataCell(Text(
                    loc.t('monthlySales.monthLabel', params: {'m': month.toString()}),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(_fmt(ticket),
                    style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmt(extra),
                    style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_fmt(net),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: net >= 0 ? const Color(0xFF1565C0) : Colors.red))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
