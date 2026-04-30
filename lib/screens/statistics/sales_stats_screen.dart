import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class SalesStatsScreen extends StatefulWidget {
  const SalesStatsScreen({super.key});
  @override
  State<SalesStatsScreen> createState() => _SalesStatsScreenState();
}

class _SalesStatsScreenState extends State<SalesStatsScreen> {
  List<Map<String, dynamic>> _monthly = [];
  bool _loading = true;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getMonthlySummary(_year);
      if (mounted) setState(() { _monthly = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final maxRevenue = _monthly.isEmpty ? 1
        : _monthly.map((e) => e['totalRevenue'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
    final total = _monthly.fold(0, (s, e) => s + (e['totalRevenue'] as int? ?? 0));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('stats.sales.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
              setState(() => _year--); _load();
            }),
            Text(loc.t('stats.sales.yearHeader', params: {'y': _year.toString()}),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _year < DateTime.now().year
                ? () { setState(() => _year++); _load(); } : null),
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
          Card(
            color: const Color(0xFF1565C0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.trending_up, color: Colors.white70, size: 28),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.t('stats.sales.yearTotal', params: {'y': _year.toString()}),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(loc.t('acc.wonAmount', params: {'v': _fmt(total)}),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('stats.sales.monthly'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _monthly.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final item = _monthly[i];
                            final month = item['month'] as int? ?? (i + 1);
                            final revenue = item['totalRevenue'] as int? ?? 0;
                            final ratio = maxRevenue == 0 ? 0.0 : revenue / maxRevenue;
                            return Row(children: [
                              SizedBox(
                                width: 44,
                                child: Text(loc.t('stats.sales.monthLabel', params: {'m': month.toString()}),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.right),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Stack(alignment: Alignment.centerLeft, children: [
                                  Container(height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6))),
                                  FractionallySizedBox(
                                    widthFactor: ratio,
                                    child: Container(height: 32,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                                        borderRadius: BorderRadius.circular(6))),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 110,
                                child: Text(loc.t('acc.wonAmount', params: {'v': _fmt(revenue)}),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 정수를 천단위 콤마 형식 문자열로 변환
  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
