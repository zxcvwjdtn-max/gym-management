import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class MonthlySettlementScreen extends StatefulWidget {
  const MonthlySettlementScreen({super.key});
  @override
  State<MonthlySettlementScreen> createState() => _MonthlySettlementScreenState();
}

class _MonthlySettlementScreenState extends State<MonthlySettlementScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _loading = true;

  int _cardRev = 0, _cashRev = 0, _ticketRev = 0, _extraRev = 0, _totalRev = 0;
  List<Map<String, dynamic>> _expenseItems = [];
  int _totalExpense = 0;

  final _salaryCtrl = TextEditingController();
  int _salary = 0;

  int get _netProfit => _totalRev - _totalExpense;
  int get _tax => (_salary * 0.033).round();
  int get _actualPay => _salary - _tax;
  int get _remaining => _netProfit - _salary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = '$_year-${_month.toString().padLeft(2, '0')}-01';
      final to = '$_year-${_month.toString().padLeft(2, '0')}-31';
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getDailySummary(from, to),
        api.getExpenseSummary(from, to),
      ]);

      final dailyList = results[0];
      final expenseList = results[1];

      int card = 0, cash = 0, ticket = 0, extra = 0, total = 0, exp = 0;
      for (final row in dailyList) {
        card += row['cardRevenue'] as int? ?? 0;
        cash += row['cashRevenue'] as int? ?? 0;
        ticket += row['ticketRevenue'] as int? ?? 0;
        extra += row['extraRevenue'] as int? ?? 0;
        total += row['totalRevenue'] as int? ?? 0;
        exp += row['purchase'] as int? ?? 0;
      }

      if (mounted) {
        setState(() {
          _cardRev = card; _cashRev = cash;
          _ticketRev = ticket; _extraRev = extra; _totalRev = total;
          _expenseItems = expenseList;
          _totalExpense = exp;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _year--; _month = 12; } else { _month--; }
    });
    _load();
  }

  void _nextMonth() {
    if (_year == DateTime.now().year && _month == DateTime.now().month) return;
    setState(() {
      if (_month == 12) { _year++; _month = 1; } else { _month++; }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(loc),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRevenueSection(),
                          const SizedBox(height: 16),
                          _buildExpenseSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildNetProfitCard(),
                        const SizedBox(height: 16),
                        _buildSalaryCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(LocaleProvider loc) {
    return Row(children: [
      Text(loc.t('settle.title'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(width: 20),
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
      Text('$_year년 $_month월',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
      const Spacer(),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh, size: 16),
        label: Text(loc.t('common.refresh')),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      ),
    ]);
  }

  Widget _buildRevenueSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.trending_up, color: Color(0xFF1565C0), size: 20),
              SizedBox(width: 8),
              Text('매출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _RevTile(label: '카드 매출', value: _cardRev, color: Colors.indigo)),
              const SizedBox(width: 10),
              Expanded(child: _RevTile(label: '현금 매출', value: _cashRev, color: Colors.teal)),
              const SizedBox(width: 10),
              Expanded(child: _RevTile(label: '티켓 매출', value: _ticketRev, color: Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _RevTile(label: '기타 매출', value: _extraRev, color: Colors.orange.shade700)),
              const SizedBox(width: 10),
              Expanded(child: _RevTile(label: '매출 합계', value: _totalRev,
                color: const Color(0xFF1565C0), bold: true)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.trending_down, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('지출', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            if (_expenseItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('지출 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
              )
            else ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _expenseHeader(),
                    ..._expenseItems.asMap().entries.map((e) =>
                      _expenseRow(e.key, e.value)),
                    _expenseTotalRow(),
                  ],
                ),
              ),
            ],
            if (_expenseItems.isNotEmpty)
              const SizedBox(height: 0)
            else
              _expenseEmptyTotal(),
          ],
        ),
      ),
    );
  }

  Widget _expenseHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(children: [
        Expanded(child: Text('항목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Text('금액', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _expenseRow(int index, Map<String, dynamic> item) {
    final desc = item['description'] as String? ?? '미분류';
    final total = _toInt(item['total']);
    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 13))),
        Text('${_fmt(total)}원',
          style: const TextStyle(fontSize: 13, color: Colors.red)),
      ]),
    );
  }

  Widget _expenseTotalRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(top: BorderSide(color: Colors.red.shade200)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Expanded(child: Text('지출 합계',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        Text('${_fmt(_totalExpense)}원',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
      ]),
    );
  }

  Widget _expenseEmptyTotal() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(children: [
        Expanded(child: Text('지출 합계', style: TextStyle(fontWeight: FontWeight.bold))),
        Text('0원', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      ]),
    );
  }

  Widget _buildNetProfitCard() {
    final pos = _netProfit >= 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: pos ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_balance_wallet_outlined,
                color: pos ? Colors.green.shade700 : Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text('순수익',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: pos ? Colors.green.shade700 : Colors.red.shade700)),
            ]),
            const SizedBox(height: 16),
            _sumRow('매출 합계', '${_fmt(_totalRev)}원', const Color(0xFF1565C0)),
            _sumRow('지출 합계', '- ${_fmt(_totalExpense)}원', Colors.red.shade700),
            Divider(height: 20, color: Colors.grey.shade300),
            _sumRow('순수익', '${_fmt(_netProfit)}원',
              pos ? Colors.green.shade700 : Colors.red.shade700,
              bold: true, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.people_outline, color: Color(0xFF1565C0), size: 20),
              SizedBox(width: 8),
              Text('직원 급여', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _salaryCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '급여 총액',
                suffixText: '원',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() {
                _salary = int.tryParse(v) ?? 0;
              }),
            ),
            if (_salary > 0) ...[
              const SizedBox(height: 16),
              _sumRow('원천세 (3.3%)', '- ${_fmt(_tax)}원', Colors.orange.shade700),
              _sumRow('실제 지급액', '${_fmt(_actualPay)}원', const Color(0xFF1565C0)),
              Divider(height: 20, color: Colors.grey.shade300),
              _sumRow('급여 후 남은 금액', '${_fmt(_remaining)}원',
                _remaining >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                bold: true, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value, Color color,
      {bool bold = false, double size = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: size, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(
            fontSize: size, color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _fmt(int v) => v.abs().toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _RevTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool bold;
  const _RevTile({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${_fmt(value)}원',
            style: TextStyle(fontSize: 16, color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
