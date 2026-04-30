import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

/// 출석 체크 화면 — 달력에서 날짜 선택 후 여러 회원을 검색해 출석 처리
class AttendanceCheckScreen extends StatefulWidget {
  const AttendanceCheckScreen({super.key});
  @override
  State<AttendanceCheckScreen> createState() => _AttendanceCheckScreenState();
}

class _AttendanceCheckScreenState extends State<AttendanceCheckScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _searchCtrl = TextEditingController();
  List<MemberModel> _members = [];
  List<AttendanceModel> _dayAttendance = [];
  Set<int> _attendedMemberIds = {};
  bool _loadingMembers = false;
  bool _loadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _loadDayAttendance();
    _searchMembers('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  // 선택 날짜의 출석 명단 로드
  Future<void> _loadDayAttendance() async {
    setState(() => _loadingAttendance = true);
    try {
      final list = await context.read<ApiService>().getAttendanceByDate(_fmt(_selectedDate));
      if (mounted) {
        setState(() {
          _dayAttendance = list;
          _attendedMemberIds = list.map((a) => a.memberId!).toSet();
          _loadingAttendance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  // 회원 검색
  Future<void> _searchMembers(String keyword) async {
    setState(() => _loadingMembers = true);
    try {
      final list = await context.read<ApiService>().getMembers(keyword: keyword);
      if (mounted) setState(() { _members = list; _loadingMembers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  // 출석 처리 — 시간 지정 다이얼로그 표시
  Future<void> _checkIn(MemberModel m) async {
    final loc = context.read<LocaleProvider>();
    final now = TimeOfDay.now();
    final nowDt = DateTime.now();
    final plusOne = nowDt.add(const Duration(hours: 1));
    TimeOfDay inTime = now;
    TimeOfDay outTime = TimeOfDay(hour: plusOne.hour, minute: plusOne.minute);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(loc.t('attCheck.dialog.title', params: {'name': m.memberName})),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.t('attCheck.dialog.date', params: {'d': _fmt(_selectedDate)}),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              const SizedBox(height: 16),
              _timeRow(loc.t('attCheck.dialog.inTime'), inTime, Icons.login, const Color(0xFF1565C0), () async {
                final picked = await showTimePicker(context: ctx, initialTime: inTime);
                if (picked != null) setS(() => inTime = picked);
              }),
              const SizedBox(height: 12),
              _timeRow(loc.t('attCheck.dialog.outTime'), outTime, Icons.logout, Colors.orange.shade700, () async {
                final picked = await showTimePicker(context: ctx, initialTime: outTime);
                if (picked != null) setS(() => outTime = picked);
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.t('common.cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: Text(loc.t('attCheck.dialog.submit')),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      await context.read<ApiService>().createManualAttendance(
        memberId: m.memberId!,
        date: _fmt(_selectedDate),
        inTime: _fmtTime(inTime),
        outTime: _fmtTime(outTime),
      );
      if (mounted) showSuccessSnack(context, loc.t('attCheck.snack.done', params: {'name': m.memberName}));
      await _loadDayAttendance();
    } catch (e) {
      if (mounted) showErrorSnack(context, '${loc.t('attCheck.snack.fail')}: $e');
    }
  }

  Widget _timeRow(String label, TimeOfDay t, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_fmtTime(t),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 6),
            Icon(Icons.edit, size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  // 출석 해제
  Future<void> _cancel(MemberModel m) async {
    final loc = context.read<LocaleProvider>();
    final record = _dayAttendance.firstWhere(
      (a) => a.memberId == m.memberId,
      orElse: () => AttendanceModel(memberName: '', memberNo: ''),
    );
    if (record.attendanceId == null) return;
    try {
      await context.read<ApiService>().deleteAttendance(record.attendanceId!);
      if (mounted) showSuccessSnack(context, loc.t('attCheck.snack.removed', params: {'name': m.memberName}));
      await _loadDayAttendance();
    } catch (e) {
      if (mounted) showErrorSnack(context, '${loc.t('attCheck.snack.rmFail')}: $e');
    }
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('attCheck.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 좌측: 달력
                SizedBox(width: 400, child: _buildCalendar(loc)),
                const SizedBox(width: 20),
                // 우측: 검색 + 회원 리스트
                Expanded(child: _buildMemberPanel(loc)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 달력 ─────────────────────────────────────────────────
  Widget _buildCalendar(LocaleProvider loc) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 월 이동 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Text(loc.t('common.monthHeader', params: {'y': _month.year.toString(), 'm': _month.month.toString()}),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),
            // 요일 헤더
            Row(
              children: List.generate(7, (i) => Expanded(
                    child: Center(child: Text(loc.t('common.weekday.short.$i'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: i == 0 ? Colors.red
                            : i == 6 ? Colors.blue : Colors.black87,
                      ))),
                  )),
            ),
            const SizedBox(height: 4),
            // 날짜 그리드
            Expanded(child: _buildDateGrid()),
            const SizedBox(height: 8),
            // 선택된 날짜 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event, color: Color(0xFF1565C0), size: 18),
                  const SizedBox(width: 8),
                  Text(loc.t('attCheck.selected', params: {'d': _fmt(_selectedDate)}),
                    style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Text(loc.t('attCheck.checkCount', params: {'n': _dayAttendance.length.toString()}),
                    style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateGrid() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final leading = firstDay.weekday % 7; // 일=0
    final total = leading + lastDay.day;
    final rows = (total / 7).ceil();
    final today = DateTime.now();
    final isSelectedMonth = _selectedDate.year == _month.year &&
        _selectedDate.month == _month.month;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, i) {
        final dayNum = i - leading + 1;
        if (dayNum < 1 || dayNum > lastDay.day) {
          return const SizedBox.shrink();
        }
        final d = DateTime(_month.year, _month.month, dayNum);
        final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
        final isSelected = isSelectedMonth && _selectedDate.day == dayNum;
        final isFuture = d.isAfter(DateTime(today.year, today.month, today.day));
        final dow = d.weekday % 7;

        return InkWell(
          onTap: isFuture ? null : () {
            setState(() => _selectedDate = d);
            _loadDayAttendance();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1565C0)
                  : isToday ? Colors.blue.shade50 : null,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: const Color(0xFF1565C0), width: 1)
                  : null,
            ),
            child: Center(
              child: Text('$dayNum',
                style: TextStyle(
                  color: isSelected ? Colors.white
                      : isFuture ? Colors.grey.shade300
                      : dow == 0 ? Colors.red
                      : dow == 6 ? Colors.blue
                      : Colors.black87,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                )),
            ),
          ),
        );
      },
    );
  }

  // ── 회원 검색 + 리스트 ──────────────────────────────────
  Widget _buildMemberPanel(LocaleProvider loc) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 검색 바
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: loc.t('common.searchMemberHint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchMembers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {});
                _searchMembers(v);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(loc.t('attCheck.searchResults', params: {'n': _members.length.toString()}),
                  style: TextStyle(color: Colors.grey.shade700)),
                const Spacer(),
                Text(loc.t('attCheck.done', params: {'n': _attendedMemberIds.length.toString()}),
                  style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _loadingMembers || _loadingAttendance
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                      ? Center(
                          child: Text(loc.t('common.noMembers'),
                            style: const TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: _members.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final m = _members[i];
                            final attended = _attendedMemberIds.contains(m.memberId);
                            return _buildMemberRow(loc, m, attended);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(LocaleProvider loc, MemberModel m, bool attended) {
    final hasPhoto = m.photoUrl != null && m.photoUrl!.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.blue.shade50,
        backgroundImage: hasPhoto ? NetworkImage(m.photoUrl!) : null,
        child: hasPhoto ? null
            : Text(m.memberName.isNotEmpty ? m.memberName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
      ),
      title: Text(m.memberName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        '${m.memberNo}${m.ticketName != null ? ' · ${m.ticketName}' : ''}',
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: attended
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                      const SizedBox(width: 4),
                      Text(loc.t('attCheck.badge.present'),
                        style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _cancel(m),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(loc.t('attCheck.btn.release'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            )
          : ElevatedButton.icon(
              onPressed: () => _checkIn(m),
              icon: const Icon(Icons.how_to_reg, size: 16),
              label: Text(loc.t('attCheck.btn.check'), style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
            ),
    );
  }
}
