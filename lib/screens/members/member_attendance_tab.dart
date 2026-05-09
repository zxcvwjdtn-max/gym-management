// ──────────────────────────────────────────────────────────────
// member_attendance_tab.dart
// 회원 상세 > 탭 3: 출석현황
// _AttendanceTab, _AttendanceTabState
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// ──────────────────────────────────────────────────────────────
// 탭 3: 출석현황 (달력)
// ──────────────────────────────────────────────────────────────
class MemberAttendanceTab extends StatefulWidget {
  final int memberId;
  const MemberAttendanceTab({required this.memberId});

  @override
  State<MemberAttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<MemberAttendanceTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<AttendanceModel> _list = [];
  bool _loading = true;

  /// 현재 조회 중인 월 (기본값: 이번 달)
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 선택된 월의 출석 기록 조회
  Future<void> _load() async {
    setState(() => _loading = true);
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0);
    final fromStr = '${from.year}-${from.month.toString().padLeft(2,'0')}-01';
    final toStr = '${to.year}-${to.month.toString().padLeft(2,'0')}-${to.day.toString().padLeft(2,'0')}';
    try {
      final data = await context.read<ApiService>()
          .getMemberAttendance(widget.memberId, from: fromStr, to: toStr);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 이전 달로 이동
  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  /// 다음 달로 이동 (현재 달 이후는 이동 불가)
  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = context.watch<LocaleProvider>();

    // 출석 날짜 Set (달력 셀 강조에 사용)
    final attendedDays = <int>{};
    for (final a in _list) {
      if (a.attendanceDate != null) {
        final d = DateTime.tryParse(a.attendanceDate!);
        if (d != null) attendedDays.add(d.day);
      }
    }

    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    // 0 = 일요일 기준으로 첫째 날 오프셋 계산
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── 월 네비게이션 + 수동 출석 버튼 ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
              Expanded(
                child: Center(child: Text(
                  loc.t('member.att.monthHeader', params: {
                    'y': _month.year.toString(),
                    'm': _month.month.toString(),
                    'n': attendedDays.length.toString(),
                  }),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showManualAddDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text(loc.t('member.att.manualBtn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
              ),
            ]),
          ),
          // ── 요일 헤더 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(7, (i) {
                final dayKey = 'common.weekday.short.$i';
                final label = loc.t(dayKey);
                return Expanded(
                  child: Center(child: Text(label,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: i == 0 ? Colors.red : i == 6 ? Colors.blue : Colors.grey.shade700,
                    ))),
                );
              }),
            ),
          ),
          const Divider(height: 8),
          // ── 달력 그리드 ────────────────────────────────────────
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, childAspectRatio: 1.15),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (_, i) {
                  if (i < firstWeekday) return const SizedBox.shrink();
                  final day = i - firstWeekday + 1;
                  final isToday = DateTime.now().year == _month.year &&
                      DateTime.now().month == _month.month &&
                      DateTime.now().day == day;
                  final weekday = (firstWeekday + day - 1) % 7;
                  final cellDate = DateTime(_month.year, _month.month, day);
                  final today = DateTime.now();
                  final todayOnly = DateTime(today.year, today.month, today.day);
                  final isFuture = cellDate.isAfter(todayOnly);
                  final record = _recordByDay(day);
                  final isAttended = record != null;
                  final inTime = record?.attendanceTime;
                  final outTime = record?.checkoutTime;

                  /// 시각 포맷 (HH:mm)
                  String fmt(DateTime t) =>
                      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

                  return Container(
                    margin: const EdgeInsets.all(1),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAttended ? const Color(0xFF1565C0).withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      border: Border.all(
                        color: isToday ? Colors.orange : Colors.grey.shade200,
                        width: isToday ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 날짜 숫자
                        Text('$day',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isFuture ? Colors.grey.shade400
                                : weekday == 0 ? Colors.red
                                : weekday == 6 ? Colors.blue
                                : Colors.black87,
                          ),
                        ),
                        // 출석 시 입/퇴장 시각 표시
                        if (isAttended) ...[
                          Text('${loc.t('member.att.checkInShort')} ${inTime != null ? fmt(inTime) : '-'}',
                            style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: Color(0xFF1565C0),
                            )),
                          Text('${loc.t('member.att.checkOutShort')} ${outTime != null ? fmt(outTime) : '-'}',
                            style: TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: outTime != null ? Colors.teal.shade700 : Colors.grey,
                            )),
                        ],
                        // 버튼: 미래 = 빈 공간, 출석 = 해제, 미출석 = 출석 등록
                        if (isFuture)
                          const SizedBox(height: 30)
                        else if (isAttended)
                          SizedBox(
                            height: 30, width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _confirmDelete(record),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3)),
                              ),
                              child: Text(loc.t('member.att.releaseBtn')),
                            ),
                          )
                        else
                          SizedBox(
                            height: 30, width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _showQuickAddDialog(day),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3)),
                              ),
                              child: Text(loc.t('member.att.addBtn')),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 16),
          // ── 출석 목록 (리스트뷰) ───────────────────────────────
          if (_list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(loc.t('member.att.empty'), style: const TextStyle(color: Colors.grey)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final a = _list[i];
                final timeStr = a.attendanceTime != null
                    ? '${a.attendanceTime!.hour.toString().padLeft(2,'0')}:'
                      '${a.attendanceTime!.minute.toString().padLeft(2,'0')}'
                    : '-';
                final checkoutStr = a.checkoutTime != null
                    ? '${a.checkoutTime!.hour.toString().padLeft(2,'0')}:'
                      '${a.checkoutTime!.minute.toString().padLeft(2,'0')}'
                    : null;
                final subtitle = checkoutStr != null
                    ? loc.t('member.att.inOutStr', params: {'inT': timeStr, 'outT': checkoutStr})
                    : loc.t('member.att.inOnlyStr', params: {'inT': timeStr});
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16, backgroundColor: const Color(0xFF1565C0),
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  title: Text(a.attendanceDate ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(loc.t('member.att.badge.attended'),
                          style: TextStyle(color: Colors.green, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: loc.t('member.att.tooltip.delete'),
                      onPressed: a.attendanceId == null ? null : () => _confirmDelete(a),
                    ),
                  ]),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 해당 일자의 출석 기록 반환 (없으면 null)
  AttendanceModel? _recordByDay(int day) {
    for (final a in _list) {
      if (a.attendanceDate == null) continue;
      final d = DateTime.tryParse(a.attendanceDate!);
      if (d != null && d.year == _month.year && d.month == _month.month && d.day == day) {
        return a;
      }
    }
    return null;
  }

  /// 달력 셀에서 날짜를 탭했을 때 출석 빠른 등록 다이얼로그
  Future<void> _showQuickAddDialog(int day) async {
    final loc = context.read<LocaleProvider>();
    final target = DateTime(_month.year, _month.month, day);
    TimeOfDay inTime = TimeOfDay.now();
    TimeOfDay? outTime;
    final dateLabel = '${target.year}-${target.month.toString().padLeft(2,'0')}-${target.day.toString().padLeft(2,'0')}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(loc.t('member.att.quickAdd.title', params: {'date': dateLabel})),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // 입장 시각
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login, size: 20),
                title: Text(loc.t('member.att.inTimeLabel')),
                trailing: Text(
                  '${inTime.hour.toString().padLeft(2,'0')}:${inTime.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: inTime);
                  if (t != null) setSt(() => inTime = t);
                },
              ),
              // 퇴장 시각 (선택)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, size: 20),
                title: Text(loc.t('member.att.outTimeLabel')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    outTime == null ? loc.t('member.att.outTimeNone')
                        : '${outTime!.hour.toString().padLeft(2,'0')}:${outTime!.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (outTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setSt(() => outTime = null),
                    ),
                ]),
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: outTime ?? const TimeOfDay(hour: 18, minute: 0));
                  if (t != null) setSt(() => outTime = t);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.t('common.cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.t('common.add'))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    // 퇴장이 입장보다 빠를 수 없음
    if (outTime != null) {
      final inM = inTime.hour * 60 + inTime.minute;
      final outM = outTime!.hour * 60 + outTime!.minute;
      if (outM <= inM) {
        showErrorSnack(context, loc.t('member.att.outTimeError'));
        return;
      }
    }

    final dateStr = '${target.year}-${target.month.toString().padLeft(2,'0')}-${target.day.toString().padLeft(2,'0')}';
    final inStr = '${inTime.hour.toString().padLeft(2,'0')}:${inTime.minute.toString().padLeft(2,'0')}';
    final outStr = outTime == null ? null
        : '${outTime!.hour.toString().padLeft(2,'0')}:${outTime!.minute.toString().padLeft(2,'0')}';
    try {
      await context.read<ApiService>().createManualAttendance(
        memberId: widget.memberId,
        date: dateStr,
        inTime: inStr,
        outTime: outStr,
      );
      if (mounted) showSuccessSnack(context, loc.t('member.att.addSuccess'));
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, loc.t('member.att.addFail', params: {'e': e.toString()}));
    }
  }

  /// 출석 기록 삭제 확인 다이얼로그 (횟수제 회수 안내 포함)
  Future<void> _confirmDelete(AttendanceModel a) async {
    final loc = context.read<LocaleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('member.att.delete.title')),
        content: Text(loc.t('member.att.delete.confirm', params: {'date': a.attendanceDate ?? ''})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteAttendance(a.attendanceId!);
      if (mounted) showSuccessSnack(context, loc.t('member.att.deleteSuccess'));
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, loc.t('member.att.deleteFail', params: {'e': e.toString()}));
    }
  }

  /// 날짜를 직접 선택하는 수동 출석 등록 다이얼로그
  Future<void> _showManualAddDialog() async {
    final loc = context.read<LocaleProvider>();
    DateTime selectedDate = DateTime(_month.year, _month.month,
        DateTime.now().month == _month.month ? DateTime.now().day : 1);
    TimeOfDay inTime = TimeOfDay.now();
    TimeOfDay? outTime;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(loc.t('member.att.manualAdd.title')),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // 날짜 선택
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: Text(loc.t('member.att.manualAdd.dateLabel')),
                trailing: Text(
                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setSt(() => selectedDate = d);
                },
              ),
              // 입장 시각
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login, size: 20),
                title: Text(loc.t('member.att.inTimeLabel')),
                trailing: Text(
                  '${inTime.hour.toString().padLeft(2,'0')}:${inTime.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: inTime);
                  if (t != null) setSt(() => inTime = t);
                },
              ),
              // 퇴장 시각 (선택)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, size: 20),
                title: Text(loc.t('member.att.outTimeLabel')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    outTime == null ? loc.t('member.att.outTimeNone')
                        : '${outTime!.hour.toString().padLeft(2,'0')}:${outTime!.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (outTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setSt(() => outTime = null),
                    ),
                ]),
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: outTime ?? const TimeOfDay(hour: 18, minute: 0));
                  if (t != null) setSt(() => outTime = t);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.t('common.cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.t('common.add')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    // 입장 < 퇴장 검증
    if (outTime != null) {
      final inM = inTime.hour * 60 + inTime.minute;
      final outM = outTime!.hour * 60 + outTime!.minute;
      if (outM <= inM) {
        showErrorSnack(context, loc.t('member.att.outTimeError'));
        return;
      }
    }

    final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}';
    final inStr = '${inTime.hour.toString().padLeft(2,'0')}:${inTime.minute.toString().padLeft(2,'0')}';
    final outStr = outTime == null ? null
        : '${outTime!.hour.toString().padLeft(2,'0')}:${outTime!.minute.toString().padLeft(2,'0')}';
    try {
      await context.read<ApiService>().createManualAttendance(
        memberId: widget.memberId,
        date: dateStr,
        inTime: inStr,
        outTime: outStr,
      );
      if (mounted) showSuccessSnack(context, loc.t('member.att.addSuccess'));
      // 등록된 날짜의 월로 이동 후 재조회
      if (selectedDate.year != _month.year || selectedDate.month != _month.month) {
        setState(() => _month = DateTime(selectedDate.year, selectedDate.month));
      }
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, loc.t('member.att.addFail', params: {'e': e.toString()}));
    }
  }
}
