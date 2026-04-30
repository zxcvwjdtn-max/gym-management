import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class CenterAccountingScreen extends StatefulWidget {
  const CenterAccountingScreen({super.key});
  @override
  State<CenterAccountingScreen> createState() => _CenterAccountingScreenState();
}

class _CenterAccountingScreenState extends State<CenterAccountingScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = '${_year}-${_month.toString().padLeft(2,'0')}-01';
      final to = '${_year}-${_month.toString().padLeft(2,'0')}-31';
      final data = await context.read<ApiService>().getDailySummary(from, to);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final total = _data.fold(0, (s, e) => s + (e['totalRevenue'] as int? ?? 0));
    final purchase = _data.fold(0, (s, e) => s + (e['purchase'] as int? ?? 0));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('center.accounting.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
              setState(() {
                if (_month == 1) { _year--; _month = 12; }
                else { _month--; }
              });
              _load();
            }),
            Text(loc.t('center.acc.monthHeader',
                params: {'y': _year.toString(), 'm': _month.toString()}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
              if (_year == DateTime.now().year && _month == DateTime.now().month) return;
              setState(() {
                if (_month == 12) { _year++; _month = 1; }
                else { _month++; }
              });
              _load();
            }),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Card(labelKey: 'center.acc.totalRevenue', value: total, color: Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _Card(labelKey: 'center.acc.totalPurchase', value: purchase, color: Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _Card(labelKey: 'center.acc.netIncome', value: total - purchase, color: Colors.green, bold: true)),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: [
                        DataColumn(label: Text(loc.t('center.acc.col.date'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('center.acc.col.ticket'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('center.acc.col.extra'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('center.acc.col.purchase'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('center.acc.col.net'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _data.map((row) {
                        final t = row['ticketRevenue'] as int? ?? 0;
                        final e = row['extraRevenue'] as int? ?? 0;
                        final p = row['purchase'] as int? ?? 0;
                        final net = t + e - p;
                        return DataRow(cells: [
                          DataCell(Text(row['date'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(t)}))),
                          DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(e)}))),
                          DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(p)}),
                            style: const TextStyle(color: Colors.red))),
                          DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(net)}),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: net >= 0 ? Colors.green.shade700 : Colors.red))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _Card extends StatelessWidget {
  final String labelKey;
  final int value;
  final Color color;
  final bool bold;
  const _Card({required this.labelKey, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(loc.t(labelKey), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 6),
          Text(loc.t('acc.wonAmount', params: {'v': _fmt(value)}),
            style: TextStyle(
              color: color, fontSize: 20,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ]),
      ),
    );
  }

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
