import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});
  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _detail = [];
  String? _selectedDate;
  bool _loading = true;
  bool _loadingDetail = false;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
      .subtract(const Duration(days: 29));
  DateTime _to = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // 선택 기간의 일별 매출 데이터 로드
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getDailySummary(_fmt(_from), _fmt(_to));
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 선택 날짜의 매출 상세 로드
  Future<void> _loadDetail(String date) async {
    setState(() { _selectedDate = date; _loadingDetail = true; _detail = []; });
    try {
      final list = await context.read<ApiService>().getAccountingDetails(date);
      if (mounted) setState(() { _detail = list; _loadingDetail = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  int get _totalRevenue => _data.fold(0, (s, e) => s + (e['totalRevenue'] as int? ?? 0));

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('dailySales.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _from,
                    firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) { setState(() => _from = d); _load(); }
              },
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(_fmt(_from)),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _to,
                    firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) { setState(() => _to = d); _load(); }
              },
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(_fmt(_to)),
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
          // 요약 카드
          Card(
            color: const Color(0xFF1565C0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 28),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.t('acc.periodRevenue'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(loc.t('acc.wonAmount', params: {'v': _fmt2(_totalRevenue)}),
                    style: const TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 좌측: 일별 테이블
                Expanded(flex: 3, child: _buildDailyTable(loc)),
                const SizedBox(width: 16),
                // 우측: 상세 패널
                Expanded(flex: 2, child: _buildDetailPanel(loc)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 일별 테이블 ─────────────────────────────────────
  Widget _buildDailyTable(LocaleProvider loc) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data.isEmpty) {
      return Center(
        child: Text(loc.t('acc.emptyData'), style: const TextStyle(color: Colors.grey)));
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
              DataColumn(label: Text(loc.t('acc.col.date'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.card'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.cash'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.ticketRev'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.extraRev'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.purchase'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.t('acc.col.netRev'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _data.map((row) {
              final date = row['date'] ?? '';
              final ticket = row['ticketRevenue'] as int? ?? 0;
              final extra = row['extraRevenue'] as int? ?? 0;
              final card = row['cardRevenue'] as int? ?? 0;
              final cash = row['cashRevenue'] as int? ?? 0;
              final purchase = row['purchase'] as int? ?? 0;
              final net = ticket + extra - purchase;
              final isSelected = _selectedDate == date;
              return DataRow(
                selected: isSelected,
                onSelectChanged: (_) => _loadDetail(date),
                cells: [
                  DataCell(Text(date, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt2(card)}),
                    style: TextStyle(color: card > 0 ? Colors.blue.shade700 : Colors.grey))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt2(cash)}),
                    style: TextStyle(color: cash > 0 ? Colors.green.shade700 : Colors.grey))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt2(ticket)}))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt2(extra)}))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt2(purchase)}),
                    style: const TextStyle(color: Colors.red))),
                  DataCell(Text(loc.t('acc.wonAmount', params: {'v': _fmt2(net)}),
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── 상세 패널 ───────────────────────────────────────
  Widget _buildDetailPanel(LocaleProvider loc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long, color: Color(0xFF1565C0), size: 20),
              const SizedBox(width: 8),
              Text(loc.t('acc.detail.title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedDate != null)
                Text(_selectedDate!, style: TextStyle(color: Colors.grey.shade700)),
            ]),
            const Divider(height: 20),
            Expanded(child: _buildDetailBody(loc)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBody(LocaleProvider loc) {
    if (_selectedDate == null) {
      return Center(
        child: Text(loc.t('acc.selectDate'), style: const TextStyle(color: Colors.grey)));
    }
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detail.isEmpty) {
      return Center(
        child: Text(loc.t('acc.emptyDetail'), style: const TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      itemCount: _detail.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _detail[i];
        final type = (r['accountingType'] as String?) ?? '';
        final category = (r['category'] as String?) ?? '';
        final amount = r['amount'] as int? ?? 0;
        final pm = (r['paymentMethod'] as String?) ?? '';
        final memberName = (r['memberName'] as String?) ?? '';
        final ticketName = (r['ticketName'] as String?) ?? '';
        final desc = (r['description'] as String?) ?? '';
        final isExpense = type == 'EXPENSE';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            // 구분 뱃지
            _categoryBadge(loc, category, isExpense),
            const SizedBox(width: 10),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName.isNotEmpty
                      ? (ticketName.isNotEmpty ? '$memberName · $ticketName' : memberName)
                      : (desc.isNotEmpty ? desc : loc.t('acc.noContent')),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (memberName.isNotEmpty && desc.isNotEmpty)
                    Text(desc,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  _paymentBadge(loc, pm, isExpense),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 금액
            Text(
              isExpense
                  ? loc.t('acc.minusWonAmount', params: {'v': _fmt2(amount)})
                  : loc.t('acc.wonAmount', params: {'v': _fmt2(amount)}),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isExpense ? Colors.red : Colors.black87,
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _categoryBadge(LocaleProvider loc, String category, bool isExpense) {
    late Color bg;
    late Color fg;
    late String label;
    if (isExpense) {
      bg = Colors.red.shade50; fg = Colors.red.shade700;
      label = loc.t('acc.category.expense');
    } else if (category == 'TICKET') {
      bg = Colors.blue.shade50; fg = Colors.blue.shade700;
      label = loc.t('acc.category.ticket');
    } else {
      bg = Colors.green.shade50; fg = Colors.green.shade700;
      label = loc.t('acc.category.extra');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _paymentBadge(LocaleProvider loc, String pm, bool isExpense) {
    if (isExpense) return const SizedBox.shrink();
    late Color color;
    late IconData icon;
    late String label;
    switch (pm) {
      case 'CARD':
        color = Colors.blue.shade700; icon = Icons.credit_card;
        label = loc.t('acc.pm.card'); break;
      case 'CASH':
        color = Colors.green.shade700; icon = Icons.payments;
        label = loc.t('acc.pm.cash'); break;
      case 'TRANSFER':
        color = Colors.purple.shade700; icon = Icons.account_balance;
        label = loc.t('acc.pm.transfer'); break;
      default:
        color = Colors.grey.shade600; icon = Icons.help_outline;
        label = loc.t('acc.pm.unset');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // 기타매출 등록 다이얼로그 표시
  void _showExtraDialog(BuildContext context) {
    final loc = context.read<LocaleProvider>();
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<ApiService>().createExtraSales({
                  'amount': int.tryParse(amtCtrl.text) ?? 0,
                  'description': descCtrl.text,
                  'date': _fmt(DateTime.now()),
                });
                if (context.mounted) { Navigator.pop(context); _load(); }
              } catch (e) {
                if (context.mounted) showErrorSnack(context, '${loc.t('acc.fail')}: $e');
              }
            },
            child: Text(loc.t('common.register')),
          ),
        ],
      ),
    );
  }

  // 매입 등록 다이얼로그 표시
  void _showPurchaseDialog(BuildContext context) {
    final loc = context.read<LocaleProvider>();
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<ApiService>().createPurchase({
                  'amount': int.tryParse(amtCtrl.text) ?? 0,
                  'description': descCtrl.text,
                  'date': _fmt(DateTime.now()),
                });
                if (context.mounted) { Navigator.pop(context); _load(); }
              } catch (e) {
                if (context.mounted) showErrorSnack(context, '${loc.t('acc.fail')}: $e');
              }
            },
            child: Text(loc.t('common.register')),
          ),
        ],
      ),
    );
  }

  // 정수를 천단위 콤마 형식 문자열로 변환
  String _fmt2(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
