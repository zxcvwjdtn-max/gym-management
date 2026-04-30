import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class VisitStatsScreen extends StatefulWidget {
  const VisitStatsScreen({super.key});
  @override
  State<VisitStatsScreen> createState() => _VisitStatsScreenState();
}

class _VisitStatsScreenState extends State<VisitStatsScreen> {
  List<Map<String, dynamic>> _daily = [];
  bool _loading = true;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final hourly = await context.read<ApiService>().getHourlyStats(_fmtDate(_date));
      if (mounted) setState(() { _daily = hourly; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) { setState(() => _date = picked); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final maxVal = _daily.isEmpty ? 1
        : _daily.map((e) => e['count'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
    final total = _daily.fold(0, (s, e) => s + (e['count'] as int? ?? 0));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('stats.visit.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_fmtDate(_date)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(loc.t('stats.visit.totalPersons', params: {'n': total.toString()}),
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
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
                      Text(loc.t('stats.visit.hourly'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _daily.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final item = _daily[i];
                            final hour = item['hour'] as int? ?? i;
                            final count = item['count'] as int? ?? 0;
                            final ratio = maxVal == 0 ? 0.0 : count / maxVal;
                            return Row(children: [
                              SizedBox(
                                width: 60,
                                child: Text('${hour.toString().padLeft(2,'0')}:00',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.right),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Stack(alignment: Alignment.centerLeft, children: [
                                  Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: ratio,
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _color(hour),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(width: 44,
                                child: Text(loc.t('stats.visit.personCount', params: {'n': count.toString()}),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
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

  Color _color(int h) {
    if (h >= 6 && h < 10) return Colors.orange.shade400;
    if (h >= 10 && h < 13) return Colors.blue.shade400;
    if (h >= 13 && h < 17) return Colors.teal.shade400;
    if (h >= 17 && h < 21) return Colors.deepPurple.shade400;
    return Colors.grey.shade400;
  }
}
