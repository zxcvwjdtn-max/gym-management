import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class MonthlySalesScreen extends StatefulWidget {
  const MonthlySalesScreen({super.key});
  @override
  State<MonthlySalesScreen> createState() => _MonthlySalesScreenState();
}

class _MonthlySalesScreenState extends State<MonthlySalesScreen> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _daily = [];
  int? _selectedMonth;
  bool _loading = true;
  bool _loadingDaily = false;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 선택 연도의 월별 매출 데이터 로드
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getMonthlySummary(_year);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 선택 월의 일별 매출 로드
  Future<void> _loadDaily(int month) async {
    final lastDay = DateTime(_year, month + 1, 0).day;
    final from = '$_year-${month.toString().padLeft(2,'0')}-01';
    final to = '$_year-${month.toString().padLeft(2,'0')}-${lastDay.toString().padLeft(2,'0')}';
    setState(() { _selectedMonth = month; _loadingDaily = true; _daily = []; });
    try {
      final list = await context.read<ApiService>().getDailySummary(from, to);
      if (mounted) setState(() { _daily = list; _loadingDaily = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDaily = false);
    }
  }

  int get _total => _data.fold(0, (s, e) => s + (e['totalRevenue'] as int? ?? 0));

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('monthlySales.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () { setState(() { _year--; _selectedMonth = null; _daily = []; }); _load(); },
            ),
            Text(loc.t('monthlySales.yearHeader', params: {'y': _year.toString()}),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _year < DateTime.now().year
                  ? () { setState(() { _year++; _selectedMonth = null; _daily = []; }); _load(); } : null,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showExtraDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: Text(loc.t('acc.btn.extra')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _showPurchaseDialog(context),
              icon: const Icon(Icons.remove, size: 16),
              label: Text(loc.t('acc.btn.purchase')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1565C0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 28),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.t('monthlySales.yearTotal', params: {'y': _year.toString()}),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(loc.t('acc.wonAmount', params: {'v': _fmt(_total)}),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildMonthlyTable(loc)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildDailyPanel(loc)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 월별 테이블 ─────────────────────────────────────
  Widget _buildMonthlyTable(LocaleProvider loc) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data.isEmpty) {
      return Center(child: Text(loc.t('acc.emptyData'), style: const TextStyle(color: Colors.grey)));
    }
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
              DataColumn(label: Text(loc.t('acc.col.month'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.card'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.cash'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.ticketRev'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.extraRev'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.purchase'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.netRev'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _data.map((row) {
              final month = row['month'] as int? ?? 0;
              final ticket = row['ticketRevenue'] as int? ?? 0;
              final extra = row['extraRevenue'] as int? ?? 0;
              final card = row['cardRevenue'] as int? ?? 0;
              final cash = row['cashRevenue'] as int? ?? 0;
              final purchase = row['purchase'] as int? ?? 0;
              final net = ticket + extra - purchase;
              final isSelected = _selectedMonth == month;
              return DataRow(
                selected: isSelected,
                onSelectChanged: (_) => _loadDaily(month),
                cells: [
                  DataCell(Text(loc.t('monthlySales.monthLabel', params: {'m': month.toString()}),
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(card)}),
                    style: TextStyle(color: card > 0 ? Colors.blue.shade700 : Colors.grey))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(cash)}),
                    style: TextStyle(color: cash > 0 ? Colors.green.shade700 : Colors.grey))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(ticket)}))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(extra)}))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(purchase)}),
                    style: const TextStyle(color: Colors.red))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt(net)}),
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── 일별 상세 패널 ──────────────────────────────────
  Widget _buildDailyPanel(LocaleProvider loc) {
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
              Text(loc.t('monthlySales.dailyTitle'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedMonth != null)
                Text(loc.t('common.monthHeader',
                    params: {'y': _year.toString(), 'm': _selectedMonth.toString()}),
                  style: TextStyle(color: Colors.grey.shade700)),
            ]),
            const Divider(height: 20),
            Expanded(child: _buildDailyBody(loc)),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBody(LocaleProvider loc) {
    if (_selectedMonth == null) {
      return Center(child: Text(loc.t('acc.selectMonth'), style: const TextStyle(color: Colors.grey)));
    }
    if (_loadingDaily) return const Center(child: CircularProgressIndicator());
    if (_daily.isEmpty) {
      return Center(child: Text(loc.t('acc.emptyDetail'), style: const TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 12,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 42,
        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
        columns: [
          DataColumn(label: Text(loc.t('acc.col.date'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text(loc.t('acc.col.card'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text(loc.t('acc.col.cash'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text(loc.t('acc.col.netRev'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
        rows: _daily.map((row) {
          final date = (row['date'] as String?) ?? '';
          final card = row['cardRevenue'] as int? ?? 0;
          final cash = row['cashRevenue'] as int? ?? 0;
          final ticket = row['ticketRevenue'] as int? ?? 0;
          final extra = row['extraRevenue'] as int? ?? 0;
          final purchase = row['purchase'] as int? ?? 0;
          final net = ticket + extra - purchase;
          final day = date.length >= 10 ? date.substring(8, 10) : date;
          return DataRow(cells: [
            DataCell(Text(loc.t('monthlySales.dayLabel', params: {'d': day}),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            DataCell(Text(_fmt(card),
              style: TextStyle(fontSize: 12, color: card > 0 ? Colors.blue.shade700 : Colors.grey))),
            DataCell(Text(_fmt(cash),
              style: TextStyle(fontSize: 12, color: cash > 0 ? Colors.green.shade700 : Colors.grey))),
            DataCell(Text(_fmt(net),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }

  // 기타매출 등록 다이얼로그
  void _showExtraDialog(BuildContext context) {
    final loc = context.read<LocaleProvider>();
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime date = DateTime.now();
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          title: Text(loc.t('acc.dialog.extra.title')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amtCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: loc.t('acc.field.amount'),
                  border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl,
              decoration: InputDecoration(
                  labelText: loc.t('acc.field.desc'),
                  border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(context: dCtx, initialDate: date,
                    firstDate: DateTime(2020), lastDate: DateTime.now());
                if (picked != null) setS(() => date = picked);
              },
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(loc.t('acc.field.dateLabel', params: {'d': _fmtDate(date)})),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(loc.t('common.cancel'))),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<ApiService>().createExtraSales({
                    'amount': int.tryParse(amtCtrl.text) ?? 0,
                    'description': descCtrl.text,
                    'date': _fmtDate(date),
                  });
                  if (context.mounted) { Navigator.pop(dCtx); _load(); }
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, '${loc.t('acc.fail')}: $e');
                }
              },
              child: Text(loc.t('common.register')),
            ),
          ],
        ),
      ),
    );
  }

  // 매입 등록 다이얼로그
  void _showPurchaseDialog(BuildContext context) {
    final loc = context.read<LocaleProvider>();
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime date = DateTime.now();
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          title: Text(loc.t('acc.dialog.purchase.title')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amtCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: loc.t('acc.field.amount'),
                  border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl,
              decoration: InputDecoration(
                  labelText: loc.t('acc.field.desc'),
                  border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(context: dCtx, initialDate: date,
                    firstDate: DateTime(2020), lastDate: DateTime.now());
                if (picked != null) setS(() => date = picked);
              },
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(loc.t('acc.field.dateLabel', params: {'d': _fmtDate(date)})),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(loc.t('common.cancel'))),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<ApiService>().createPurchase({
                    'amount': int.tryParse(amtCtrl.text) ?? 0,
                    'description': descCtrl.text,
                    'date': _fmtDate(date),
                  });
                  if (context.mounted) { Navigator.pop(dCtx); _load(); }
                } catch (e) {
                  if (context.mounted) showErrorSnack(context, '${loc.t('acc.fail')}: $e');
                }
              },
              child: Text(loc.t('common.register')),
            ),
          ],
        ),
      ),
    );
  }

  // 정수를 천단위 콤마 형식 문자열로 변환
  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
