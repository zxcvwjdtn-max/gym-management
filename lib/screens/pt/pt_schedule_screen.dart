import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

const _primary = Color(0xFF4527A0);

/// PT 스케줄 화면 — 주간 타임라인 뷰
/// 현재 주의 월~일 7일간 트레이너별 PT 일정을 보여줍니다.
class PtScheduleScreen extends StatefulWidget {
  const PtScheduleScreen({super.key});
  @override
  State<PtScheduleScreen> createState() => _PtScheduleScreenState();
}

class _PtScheduleScreenState extends State<PtScheduleScreen> {
  late DateTime _weekStart;
  List<PtSessionModel> _sessions = [];
  List<Map<String, dynamic>> _trainers = [];
  bool _loading = true;

  // 표시할 시간대: 06~22시
  static const _startHour = 6;
  static const _endHour = 22;
  static const _hourHeight = 56.0; // 1시간 = 56px

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 이번 주 월요일
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final weekEnd = _weekStart.add(const Duration(days: 6));
      final from = DateFormat('yyyy-MM-dd').format(_weekStart);
      final to = DateFormat('yyyy-MM-dd').format(weekEnd);

      final results = await Future.wait([
        api.getTrainers(),
        api.getPtSessions(from: from, to: to),
      ]);
      if (mounted) {
        setState(() {
          _trainers = results[0] as List<Map<String, dynamic>>;
          _sessions = results[1] as List<PtSessionModel>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadAll();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadAll();
  }

  void _thisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    setState(() => _weekStart = DateTime(start.year, start.month, start.day));
    _loadAll();
  }

  bool get _isThisWeek {
    final now = DateTime.now();
    final thisStart = now.subtract(Duration(days: now.weekday - 1));
    return _weekStart.year == thisStart.year &&
        _weekStart.month == thisStart.month &&
        _weekStart.day == thisStart.day;
  }

  /// 특정 날짜+트레이너의 세션 목록
  List<PtSessionModel> _sessionsFor(DateTime date, int trainerId) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _sessions
        .where((s) => s.sessionDate == dateStr && s.trainerId == trainerId)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final localeCode = loc.locale.languageCode;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(children: [
            const Icon(Icons.schedule, color: _primary, size: 26),
            const SizedBox(width: 10),
            Text(loc.t('ptSchedule.title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: _prevWeek),
            TextButton(
              onPressed: _thisWeek,
              child: Text(
                loc.t('ptSchedule.weekRange', params: {
                  'from': DateFormat('yyyy.MM.dd').format(_weekStart),
                  'to': DateFormat('MM.dd').format(weekEnd),
                }),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isThisWeek ? _primary : Colors.black87,
                ),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right), onPressed: _nextWeek),
            if (!_isThisWeek)
              TextButton(onPressed: _thisWeek, child: Text(loc.t('ptSchedule.thisWeek'))),
          ]),
          const SizedBox(height: 8),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_trainers.isEmpty)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(loc.t('ptSchedule.noTrainer'),
                    style: TextStyle(color: Colors.grey.shade500)),
              ]),
            ))
          else
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  // 날짜 헤더 행
                  Container(
                    color: Colors.grey.shade100,
                    child: Row(children: [
                      // 트레이너 라벨 열 너비
                      const SizedBox(width: 100),
                      const VerticalDivider(width: 1),
                      ...days.map((d) {
                        final isToday = DateFormat('yyyy-MM-dd').format(d) ==
                            DateFormat('yyyy-MM-dd').format(DateTime.now());
                        return Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: isToday ? _primary.withOpacity(0.08) : null,
                          alignment: Alignment.center,
                          child: Column(children: [
                            Text(
                              DateFormat('E', localeCode).format(d),
                              style: TextStyle(
                                fontSize: 11,
                                color: d.weekday == 7 ? Colors.red
                                    : d.weekday == 6 ? Colors.blue
                                    : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              DateFormat('d').format(d),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday ? _primary : Colors.black87,
                              ),
                            ),
                          ]),
                        ));
                      }),
                    ]),
                  ),
                  const Divider(height: 1),

                  // 스크롤 가능한 시간표 본문
                  Expanded(
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 트레이너 열
                          SizedBox(
                            width: 100,
                            child: Column(
                              children: _trainers.map((t) => Container(
                                height: (_endHour - _startHour) * _hourHeight + 1,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade200),
                                    right: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    t['adminName'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold,
                                        color: _primary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),

                          // 날짜 × 트레이너 그리드
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: days.map((day) {
                                return Expanded(child: Column(
                                  children: _trainers.map((trainer) {
                                    final trainerId = trainer['adminId'] as int;
                                    final sessionsForDay = _sessionsFor(day, trainerId);
                                    return _TimelineCell(
                                      sessions: sessionsForDay,
                                      startHour: _startHour,
                                      endHour: _endHour,
                                      hourHeight: _hourHeight,
                                    );
                                  }).toList(),
                                ));
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),

          // 범례
          const SizedBox(height: 12),
          Row(children: [
            _legend(loc.t('pt.status.scheduled'), Colors.blue),
            const SizedBox(width: 16),
            _legend(loc.t('pt.status.completed'), Colors.green),
            const SizedBox(width: 16),
            _legend(loc.t('pt.status.noshow'), Colors.red),
            const SizedBox(width: 16),
            _legend(loc.t('pt.status.cancelled'), Colors.grey),
          ]),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
  ]);
}

/// 한 트레이너 × 하루 타임라인 셀
class _TimelineCell extends StatelessWidget {
  final List<PtSessionModel> sessions;
  final int startHour;
  final int endHour;
  final double hourHeight;

  const _TimelineCell({
    required this.sessions,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
  });

  @override
  Widget build(BuildContext context) {
    final totalHeight = (endHour - startHour) * hourHeight;

    return Container(
      height: totalHeight + 1,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Stack(
        children: [
          // 시간 격자선
          for (int h = startHour; h < endHour; h++)
            Positioned(
              top: (h - startHour) * hourHeight,
              left: 0, right: 0,
              child: Container(
                height: 1,
                color: h == startHour ? Colors.transparent : Colors.grey.shade100,
              ),
            ),

          // 세션 블록
          for (final s in sessions)
            Positioned(
              top: _topOffset(s.startTime),
              left: 2,
              right: 2,
              height: _blockHeight(s.startTime, s.endTime).clamp(20.0, totalHeight),
              child: _SessionBlock(session: s),
            ),
        ],
      ),
    );
  }

  double _topOffset(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? startHour;
    final min = int.tryParse(parts[1]) ?? 0;
    return ((hour - startHour) + min / 60.0) * hourHeight;
  }

  double _blockHeight(String start, String end) {
    final s = _toMinutes(start);
    final e = _toMinutes(end);
    return ((e - s) / 60.0) * hourHeight;
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}

class _SessionBlock extends StatelessWidget {
  final PtSessionModel session;
  const _SessionBlock({required this.session});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final color = _statusColor(session.status);
    return Tooltip(
      message: loc.t('ptSchedule.tooltip', params: {
        'name': session.memberName ?? '',
        'n': session.sessionNo.toString(),
        'start': session.startTime,
        'end': session.endTime,
        'status': _statusLabel(loc, session.status),
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.memberName ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            if (_blockHeight(session.startTime, session.endTime) > 30)
              Text('${session.startTime}~${session.endTime}',
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  double _blockHeight(String start, String end) {
    final s = _toMin(start);
    final e = _toMin(end);
    return ((e - s) / 60.0) * 56.0;
  }

  int _toMin(String t) {
    final p = t.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  Color _statusColor(String s) => switch (s) {
    'COMPLETED' => Colors.green.shade600,
    'CANCELLED' => Colors.grey,
    'NO_SHOW' => Colors.red.shade600,
    _ => const Color(0xFF4527A0),
  };

  String _statusLabel(LocaleProvider loc, String s) => switch (s) {
    'COMPLETED' => loc.t('pt.status.completed'),
    'CANCELLED' => loc.t('pt.status.cancelled'),
    'NO_SHOW' => loc.t('pt.status.noshow'),
    _ => loc.t('pt.status.scheduled'),
  };
}
