// ──────────────────────────────────────────────────────────────
// member_pt_tabs.dart
// 회원 상세 > 탭 5: PT 계약 목록 + 탭 6: PT 스케줄(달력)
// _PtContractTab, _PtContractTabState, _PtContractCard
// _PtSessionTab, _PtSessionTabState, _PtSessionRow
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// ──────────────────────────────────────────────────────────────
// 탭 5: PT 계약 목록
// ──────────────────────────────────────────────────────────────
class MemberPtContractTab extends StatefulWidget {
  final int memberId;
  const MemberPtContractTab({required this.memberId});

  @override
  State<MemberPtContractTab> createState() => _PtContractTabState();
}

class _PtContractTabState extends State<MemberPtContractTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PtContractModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiService>().getPtContractsByMember(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final loc = context.watch<LocaleProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(loc.t('member.pt.contractTitle'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_list.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(loc.t('member.pt.contractEmpty'),
                style: const TextStyle(color: Colors.grey)),
          ))
        else
          ..._list.map((c) => _PtContractCard(contract: c)),
      ],
    );
  }
}

/// PT 계약 한 장 카드 (진행률 표시 포함)
class _PtContractCard extends StatelessWidget {
  final PtContractModel contract;
  const _PtContractCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final statusColor = contract.status == 'ACTIVE' ? Colors.green
        : contract.status == 'COMPLETED' ? Colors.blue : Colors.grey;
    final statusText = contract.status == 'ACTIVE'
        ? loc.t('ptContract.status.ACTIVE')
        : contract.status == 'COMPLETED'
            ? loc.t('ptContract.status.COMPLETED')
            : loc.t('ptContract.status.CANCELLED');
    final total = contract.totalSessions ?? 1;
    final used = contract.usedSessions ?? 0;
    final progress = total > 0 ? used / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF4527A0).withAlpha(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sports, size: 16, color: Color(0xFF4527A0)),
            const SizedBox(width: 6),
            Expanded(child: Text(contract.trainerName ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusText,
                style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${contract.startDate} ~ ${contract.endDate ?? '-'}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF4527A0),
              minHeight: 6,
            )),
            const SizedBox(width: 10),
            Text(loc.t('member.pt.contract.sessions',
                params: {'used': used.toString(), 'total': total.toString()}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text(
            loc.t('member.pt.contract.remain', params: {
              'n': (contract.remainSessions ?? 0).toString(),
              'price': _fmtNum(contract.price ?? 0),
            }),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }

  String _fmtNum(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ──────────────────────────────────────────────────────────────
// 탭 6: PT 스케줄 (달력)
// ──────────────────────────────────────────────────────────────
class MemberPtSessionTab extends StatefulWidget {
  final int memberId;
  const MemberPtSessionTab({required this.memberId});

  @override
  State<MemberPtSessionTab> createState() => _PtSessionTabState();
}

class _PtSessionTabState extends State<MemberPtSessionTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PtSessionModel> _list = [];
  bool _loading = true;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getPtSessionsByMember(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PtSessionModel> get _monthSessions {
    final result = _list.where((s) {
      if (s.sessionDate.isEmpty) return false;
      final d = DateTime.tryParse(s.sessionDate);
      return d != null && d.year == _month.year && d.month == _month.month;
    }).toList();
    result.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return result;
  }

  List<PtSessionModel> _daySessions(int day) => _monthSessions.where((s) {
    final d = DateTime.tryParse(s.sessionDate);
    return d?.day == day;
  }).toList();

  Color? _dayColor(int day) {
    final sessions = _daySessions(day);
    if (sessions.isEmpty) return null;
    if (sessions.any((s) => s.status == 'SCHEDULED')) return const Color(0xFF4527A0);
    if (sessions.any((s) => s.status == 'COMPLETED')) return Colors.green;
    if (sessions.any((s) => s.status == 'NO_SHOW')) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final loc = context.watch<LocaleProvider>();

    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final monthSessions = _monthSessions;
    final displaySessions = _selectedDay != null ? _daySessions(_selectedDay!) : monthSessions;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 월 네비게이션 ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                  _selectedDay = null;
                }),
              ),
              Expanded(
                child: Center(child: Text(
                  loc.t('member.pt.monthHeader', params: {
                    'y': _month.year.toString(),
                    'm': _month.month.toString(),
                    'n': monthSessions.length.toString(),
                  }),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                  _selectedDay = null;
                }),
              ),
            ]),
          ),
          // ── 범례 ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _legend(const Color(0xFF4527A0), loc.t('pt.status.scheduled')),
              const SizedBox(width: 14),
              _legend(Colors.green, loc.t('pt.status.completed')),
              const SizedBox(width: 14),
              _legend(Colors.red, loc.t('pt.status.noshow')),
              const SizedBox(width: 14),
              _legend(Colors.grey, loc.t('pt.status.cancelled')),
            ]),
          ),
          const SizedBox(height: 8),
          // ── 요일 헤더 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(7, (i) => Expanded(
                child: Center(child: Text(
                  loc.t('common.weekday.short.$i'),
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: i == 0 ? Colors.red : i == 6 ? Colors.blue : Colors.grey.shade700,
                  ))),
              )),
            ),
          ),
          const Divider(height: 8),
          // ── 달력 그리드 ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 2.2),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (_, i) {
                if (i < firstWeekday) return const SizedBox.shrink();
                final day = i - firstWeekday + 1;
                final sessionColor = _dayColor(day);
                final hasSession = sessionColor != null;
                final isToday = DateTime.now().year == _month.year &&
                    DateTime.now().month == _month.month &&
                    DateTime.now().day == day;
                final isSelected = _selectedDay == day;
                final weekday = (firstWeekday + day - 1) % 7;
                return GestureDetector(
                  onTap: hasSession
                      ? () => setState(() => _selectedDay = isSelected ? null : day)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: hasSession
                          ? (isSelected ? sessionColor : sessionColor.withAlpha(180))
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday ? Border.all(color: Colors.orange, width: 2) : null,
                    ),
                    child: Center(child: Text('$day',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: hasSession || isToday ? FontWeight.bold : FontWeight.normal,
                        color: hasSession ? Colors.white
                            : weekday == 0 ? Colors.red
                            : weekday == 6 ? Colors.blue
                            : Colors.black87,
                      ),
                    )),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 16),
          // ── 세션 목록 헤더 ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(
                _selectedDay != null
                    ? loc.t('member.pt.sessionHeader.day', params: {
                        'm': _month.month.toString(),
                        'd': _selectedDay.toString(),
                      })
                    : loc.t('member.pt.sessionHeader.all', params: {
                        'm': _month.month.toString(),
                      }),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text('(${displaySessions.length}건)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              if (_selectedDay != null) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: Text(loc.t('member.pt.sessionViewAll'),
                      style: const TextStyle(fontSize: 16)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 6),
          // ── 세션 목록 ──────────────────────────────────────────
          if (displaySessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(loc.t('member.pt.sessionEmpty'),
                  style: const TextStyle(color: Colors.grey))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displaySessions.length,
              itemBuilder: (_, i) => _PtSessionRow(session: displaySessions[i], onAction: _load),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 16)),
    ],
  );
}

/// PT 세션 한 행 (상태 변경 팝업 메뉴 포함)
class _PtSessionRow extends StatelessWidget {
  final PtSessionModel session;
  final VoidCallback onAction;
  const _PtSessionRow({required this.session, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final statusColor = _sessionColor(session.status);
    final statusText = _sessionText(loc, session.status);
    final timeStr = session.startTime != null
        ? '${session.startTime!.substring(0, 5)}'
          '${session.endTime != null ? ' ~ ${session.endTime!.substring(0, 5)}' : ''}'
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('${session.sessionNo ?? '-'}',
            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${session.sessionDate ?? '-'}  $timeStr',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            Text(session.trainerName ?? '-',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusText,
            style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (session.status == 'SCHEDULED') ...[
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'complete', child: Text(loc.t('pt.status.completed'))),
              PopupMenuItem(value: 'no-show', child: Text(loc.t('pt.status.noshow'))),
              PopupMenuItem(value: 'cancel', child: Text(loc.t('pt.status.cancelled'))),
            ],
            onSelected: (action) => _changeStatus(context, action),
          ),
        ],
      ]),
    );
  }

  void _changeStatus(BuildContext context, String action) async {
    final loc = context.read<LocaleProvider>();
    try {
      final api = context.read<ApiService>();
      if (action == 'complete') await api.completePtSession(session.sessionId!);
      if (action == 'no-show') await api.noShowPtSession(session.sessionId!);
      if (action == 'cancel') await api.cancelPtSession(session.sessionId!);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context,
          loc.t('member.pt.changeFail', params: {'e': e.toString()}));
    }
  }

  Color _sessionColor(String? s) {
    switch (s) {
      case 'SCHEDULED': return const Color(0xFF4527A0);
      case 'COMPLETED': return Colors.green;
      case 'NO_SHOW': return Colors.red;
      case 'CANCELLED': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  String _sessionText(LocaleProvider loc, String? s) {
    switch (s) {
      case 'SCHEDULED': return loc.t('pt.status.scheduled');
      case 'COMPLETED': return loc.t('pt.status.completed');
      case 'NO_SHOW': return loc.t('pt.status.noshow');
      case 'CANCELLED': return loc.t('pt.status.cancelled');
      default: return '-';
    }
  }
}
