import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

/// 출석 현황 — 탭 1: 날짜별 출석자 목록 / 탭 2: 회원별 출석 이력
class AttendanceStatusScreen extends StatefulWidget {
  const AttendanceStatusScreen({super.key});
  @override
  State<AttendanceStatusScreen> createState() => _AttendanceStatusScreenState();
}

class _AttendanceStatusScreenState extends State<AttendanceStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('attStatus.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade700,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: loc.t('attStatus.tab.date')),
                Tab(text: loc.t('attStatus.tab.member')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: const [
                _DateView(),
                _MemberView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// 날짜별 뷰
// ═════════════════════════════════════════════════════════
class _DateView extends StatefulWidget {
  const _DateView();
  @override
  State<_DateView> createState() => _DateViewState();
}

class _DateViewState extends State<_DateView> {
  List<AttendanceModel> _list = [];
  bool _loading = true;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final today = DateTime.now();
      final isToday = _date.year == today.year &&
          _date.month == today.month && _date.day == today.day;
      final list = isToday
          ? await api.getTodayAttendance()
          : await api.getAttendanceByDate(_fmt(_date));
      if (mounted) setState(() { _list = list; _loading = false; });
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
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_fmt(_date)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(loc.t('attStatus.totalCount', params: {'n': _list.length.toString()}),
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
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
        const SizedBox(height: 16),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_list.isEmpty)
          Expanded(child: Center(
            child: Text(loc.t('attStatus.empty'), style: const TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columns: [
                      DataColumn(label: Text(loc.t('attStatus.col.index'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('attStatus.col.memberNo'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('attStatus.col.name'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('attStatus.col.ticket'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('attStatus.col.state'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('attStatus.col.remainD'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('attStatus.col.time'), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _list.asMap().entries.map((entry) {
                      final i = entry.key;
                      final a = entry.value;
                      final h = a.attendanceTime?.hour.toString().padLeft(2, '0') ?? '--';
                      final m = a.attendanceTime?.minute.toString().padLeft(2, '0') ?? '--';
                      return DataRow(
                        onSelectChanged: (_) => _showDetail(context, a),
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(a.memberNo)),
                          DataCell(Text(a.memberName, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(a.ticketName ?? '-')),
                          DataCell(_badge(loc, a.membershipStatus)),
                          DataCell(Text(a.remainDays != null
                              ? loc.t('attStatus.remainDays', params: {'n': a.remainDays.toString()})
                              : '-')),
                          DataCell(Text('$h:$m')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showDetail(BuildContext context, AttendanceModel a) {
    showDialog(context: context, builder: (_) => _AttendanceDetailDialog(attendance: a));
  }

  Widget _badge(LocaleProvider loc, String? status) {
    Color c;
    String label;
    switch (status) {
      case 'ACTIVE': c = Colors.green; label = loc.t('attStatus.active'); break;
      case 'EXPIRING_SOON': c = Colors.orange; label = loc.t('attStatus.expiringSoon'); break;
      case 'EXPIRED': c = Colors.red; label = loc.t('attStatus.expired'); break;
      default: c = Colors.grey; label = '-'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// ═════════════════════════════════════════════════════════
// 출석 상세 다이얼로그
// ═════════════════════════════════════════════════════════
class _AttendanceDetailDialog extends StatelessWidget {
  final AttendanceModel attendance;
  const _AttendanceDetailDialog({required this.attendance});

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final a = attendance;
    final hasPhoto = a.photoUrl != null && a.photoUrl!.isNotEmpty;
    final isExpiring = a.remainDays != null && a.remainDays! <= 7 && a.remainDays! >= 0;
    final isExpired  = a.remainDays != null && a.remainDays! < 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 헤더 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.how_to_reg, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('출석 상세',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ]),
            ),
            // ── 본문 ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 프로필 행
                  Row(children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage: hasPhoto ? NetworkImage(a.photoUrl!) : null,
                      child: hasPhoto ? null
                          : Text(a.memberName.isNotEmpty ? a.memberName[0] : '?',
                              style: const TextStyle(fontSize: 24,
                                  fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.memberName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('No.${a.memberNo}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  // 정보 그리드
                  _infoRow(Icons.card_membership, '이용권', a.ticketName ?? '-', const Color(0xFF1565C0)),
                  const SizedBox(height: 10),
                  _infoRow(Icons.calendar_today, '출석 날짜', a.attendanceDate ?? '-', Colors.black87),
                  const SizedBox(height: 10),
                  _infoRow(Icons.access_time, '출석 시간', _fmt(a.attendanceTime), Colors.black87),
                  if (a.checkoutTime != null) ...[
                    const SizedBox(height: 10),
                    _infoRow(Icons.logout, '퇴실 시간', _fmt(a.checkoutTime), Colors.orange.shade700),
                  ],
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.timelapse,
                    '잔여 일수',
                    a.remainDays != null
                        ? (isExpired ? '만료됨' : '${a.remainDays}일')
                        : '-',
                    isExpired ? Colors.red : isExpiring ? Colors.orange : Colors.black87,
                  ),
                  if (a.remainCount != null) ...[
                    const SizedBox(height: 10),
                    _infoRow(Icons.tag, '잔여 횟수', '${a.remainCount}회', Colors.purple.shade700),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  // 대여 현황
                  Row(children: [
                    Expanded(child: _rentalChip(
                      icon: Icons.checkroom,
                      label: '옷 대여',
                      active: a.clothRentalYn == 'Y',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _rentalChip(
                      icon: Icons.lock_outline,
                      label: '락카 대여',
                      active: a.lockerRentalYn == 'Y',
                    )),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color valueColor) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade500),
      const SizedBox(width: 10),
      SizedBox(
        width: 72,
        child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ),
      Expanded(
        child: Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ),
    ]);
  }

  Widget _rentalChip({required IconData icon, required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1565C0).withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? const Color(0xFF1565C0).withOpacity(0.4) : Colors.grey.shade300,
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: active ? const Color(0xFF1565C0) : Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF1565C0) : Colors.grey.shade400,
            )),
        const SizedBox(width: 6),
        Icon(
          active ? Icons.check_circle : Icons.cancel_outlined,
          size: 15,
          color: active ? Colors.green : Colors.grey.shade400,
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════
// 회원별 뷰 (회원 검색 → 월별 출석 달력 + 리스트)
// ═════════════════════════════════════════════════════════
class _MemberView extends StatefulWidget {
  const _MemberView();
  @override
  State<_MemberView> createState() => _MemberViewState();
}

class _MemberViewState extends State<_MemberView> {
  final _searchCtrl = TextEditingController();
  List<MemberModel> _members = [];
  MemberModel? _selected;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<AttendanceModel> _attendance = [];
  bool _loadingMembers = false;
  bool _loadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _searchMembers('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchMembers(String keyword) async {
    setState(() => _loadingMembers = true);
    try {
      final list = await context.read<ApiService>().getMembers(keyword: keyword);
      if (mounted) setState(() { _members = list; _loadingMembers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadAttendance() async {
    if (_selected == null) return;
    setState(() => _loadingAttendance = true);
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0);
    final fromStr = '${from.year}-${from.month.toString().padLeft(2,'0')}-01';
    final toStr = '${to.year}-${to.month.toString().padLeft(2,'0')}-${to.day.toString().padLeft(2,'0')}';
    try {
      final list = await context.read<ApiService>()
          .getMemberAttendance(_selected!.memberId!, from: fromStr, to: toStr);
      if (mounted) setState(() { _attendance = list; _loadingAttendance = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  void _selectMember(MemberModel m) {
    setState(() => _selected = m);
    _loadAttendance();
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _loadAttendance();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    _loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 좌측: 회원 검색 리스트
        SizedBox(width: 320, child: _buildMemberList(loc)),
        const SizedBox(width: 20),
        // 우측: 선택된 회원의 월별 출석
        Expanded(child: _buildAttendancePanel(loc)),
      ],
    );
  }

  Widget _buildMemberList(LocaleProvider loc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: loc.t('common.searchMember'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: _searchMembers,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loadingMembers
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
                            final isSelected = _selected?.memberId == m.memberId;
                            final hasPhoto = m.photoUrl != null && m.photoUrl!.isNotEmpty;
                            return Material(
                              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.blue.shade50,
                                  backgroundImage: hasPhoto ? NetworkImage(m.photoUrl!) : null,
                                  child: hasPhoto ? null
                                      : Text(m.memberName.isNotEmpty ? m.memberName[0] : '?',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                                ),
                                title: Text(m.memberName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(m.memberNo, style: const TextStyle(fontSize: 12)),
                                onTap: () => _selectMember(m),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendancePanel(LocaleProvider loc) {
    if (_selected == null) {
      return Card(
        elevation: 1,
        child: Center(
          child: Text(loc.t('attStatus.selectMember'),
            style: const TextStyle(color: Colors.grey, fontSize: 15))),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 회원 정보 헤더
            Row(
              children: [
                Text('${_selected!.memberName} (${_selected!.memberNo})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Text(loc.t('common.monthHeader', params: {'y': _month.year.toString(), 'm': _month.month.toString()}),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(loc.t('attStatus.monthlyCount', params: {'n': _attendance.length.toString()}),
                style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            // 달력 + 리스트
            Expanded(
              child: _loadingAttendance
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _buildCalendar(loc)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildListPanel(loc)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(LocaleProvider loc) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final leading = firstDay.weekday % 7;
    final total = leading + lastDay.day;
    final rows = (total / 7).ceil();
    final today = DateTime.now();

    final attendedDays = _attendance
        .where((a) => a.attendanceDate != null)
        .map((a) => DateTime.parse(a.attendanceDate!).day)
        .toSet();

    return Column(
      children: [
        Row(
          children: List.generate(7, (i) => Expanded(
                child: Center(child: Text(loc.t('common.weekday.short.$i'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: i == 0 ? Colors.red
                        : i == 6 ? Colors.blue : Colors.black87,
                  ))),
              )),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
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
              final attended = attendedDays.contains(dayNum);
              final dow = d.weekday % 7;

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: attended ? const Color(0xFF1565C0) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday && !attended
                      ? Border.all(color: const Color(0xFF1565C0), width: 1)
                      : null,
                ),
                child: Center(
                  child: Text('$dayNum',
                    style: TextStyle(
                      color: attended ? Colors.white
                          : dow == 0 ? Colors.red
                          : dow == 6 ? Colors.blue
                          : Colors.black87,
                      fontWeight: attended || isToday ? FontWeight.bold : FontWeight.normal,
                    )),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListPanel(LocaleProvider loc) {
    if (_attendance.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(loc.t('attStatus.empty'), style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    final sorted = [..._attendance]
      ..sort((a, b) {
        if (a.attendanceDate == null || b.attendanceDate == null) return 0;
        return b.attendanceDate!.compareTo(a.attendanceDate!);
      });
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final a = sorted[i];
          final inH = a.attendanceTime?.hour.toString().padLeft(2, '0') ?? '--';
          final inM = a.attendanceTime?.minute.toString().padLeft(2, '0') ?? '--';
          final outH = a.checkoutTime?.hour.toString().padLeft(2, '0');
          final outM = a.checkoutTime?.minute.toString().padLeft(2, '0');
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            leading: const Icon(Icons.check_circle, color: Color(0xFF1565C0), size: 18),
            title: Text(a.attendanceDate ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              outH != null
                  ? loc.t('attStatus.inOut', params: {'inT': '$inH:$inM', 'outT': '$outH:$outM'})
                  : loc.t('attStatus.inOnly', params: {'inT': '$inH:$inM'}),
              style: const TextStyle(fontSize: 11),
            ),
          );
        },
      ),
    );
  }
}
