import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class HourlyAttendanceScreen extends StatefulWidget {
  const HourlyAttendanceScreen({super.key});
  @override
  State<HourlyAttendanceScreen> createState() => _HourlyAttendanceScreenState();
}

class _HourlyAttendanceScreenState extends State<HourlyAttendanceScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // DateTime을 yyyy-MM-dd 문자열로 포맷
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // 시간대별 출석 통계 데이터 로드
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getHourlyStats(_fmt(_date));
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 날짜 선택 피커 표시 후 데이터 재로드
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null) { setState(() => _date = picked); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final maxCount = _data.isEmpty ? 1
        : _data.map((e) => (e['count'] as int? ?? 0)).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('hourlyAtt.title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_fmt(_date)),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 24),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_data.isEmpty)
            Expanded(child: Center(
              child: Text(loc.t('hourlyAtt.empty'), style: const TextStyle(color: Colors.grey))))
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
                      Text(loc.t('hourlyAtt.subtitle'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _data.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item = _data[i];
                            final hour = item['hour'] as int? ?? i;
                            final count = item['count'] as int? ?? 0;
                            final ratio = maxCount == 0 ? 0.0 : count / maxCount;
                            return Row(children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  '${hour.toString().padLeft(2,'0')}:00',
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 28,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _barColor(hour)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 56,
                                child: Text(loc.t('hourlyAtt.personCount', params: {'n': count.toString()}),
                                  style: const TextStyle(fontWeight: FontWeight.bold,
                                      fontSize: 14)),
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

  // 시간대별 막대 그래프 색상 반환
  Color _barColor(int hour) {
    if (hour >= 6 && hour < 10) return Colors.orange;
    if (hour >= 10 && hour < 13) return Colors.blue;
    if (hour >= 13 && hour < 17) return Colors.teal;
    if (hour >= 17 && hour < 21) return Colors.deepPurple;
    return Colors.grey;
  }
}
