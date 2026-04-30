import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/locale_provider.dart';
import '../screens/members/member_detail_screen.dart';
import 'member_table.dart' show MemberRemainCell;

// 컬럼 flex (체크, 순번, 이름, 구분태그, 이용권명, 이용날짜, 잔여, 옷, 락카, 이용권등록, 회원번호, 담당자, 가입일)
const _flex = [1, 1, 2, 3, 3, 4, 2, 1, 1, 2, 2, 2, 2];

/// 회원 그룹 화면 전용 테이블 — 커스텀 구분 태그 + memberId 기반 선택
class MemberGroupTable extends StatelessWidget {
  final List<MemberModel> members;
  final Set<int> selected; // memberId
  final void Function(int memberId, bool checked) onSelectionChanged;
  final void Function(bool selectAll) onSelectAll;
  final VoidCallback onRefresh;
  final List<MemberGroupDefModel> groupDefs;
  final Map<int, Color> colorMap;   // groupDefId → Color
  final Map<int, String> nameMap;   // groupDefId → name

  const MemberGroupTable({
    super.key,
    required this.members,
    required this.selected,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onRefresh,
    required this.groupDefs,
    required this.colorMap,
    required this.nameMap,
  });

  bool get _allSelected =>
      members.isNotEmpty &&
      members.every((m) => m.memberId != null && selected.contains(m.memberId));

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // 헤더
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: _allSelected,
                    tristate: selected.isNotEmpty && !_allSelected,
                    onChanged: (v) => onSelectAll(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                ..._header('순번',      _flex[1]),
                ..._header('이름',      _flex[2]),
                ..._header('고객 구분', _flex[3]),
                ..._header(loc.t('memberList.col.ticketName'), _flex[4]),
                ..._header(loc.t('memberList.col.dateRange'),  _flex[5]),
                ..._header(loc.t('memberList.col.remain'),     _flex[6]),
                ..._header(loc.t('memberList.col.cloth'),      _flex[7]),
                ..._header(loc.t('memberList.col.locker'),     _flex[8]),
                ..._header(loc.t('memberList.col.addMs'),      _flex[9]),
                ..._header(loc.t('memberList.col.memberNo'),   _flex[10]),
                ..._header(loc.t('memberList.col.manager'),    _flex[11]),
                ..._header(loc.t('memberList.col.joinDate'),   _flex[12]),
              ]),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView.separated(
                itemCount: members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.5),
                itemBuilder: (ctx, i) => _Row(
                  index: i,
                  member: members[i],
                  isSelected: members[i].memberId != null &&
                      selected.contains(members[i].memberId),
                  onSelectionChanged: onSelectionChanged,
                  onRefresh: onRefresh,
                  colorMap: colorMap,
                  nameMap: nameMap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _header(String label, int flex) => [
    Expanded(
      flex: flex,
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.ellipsis),
    ),
  ];
}

// ─── 데이터 행 ──────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final int index;
  final MemberModel member;
  final bool isSelected;
  final void Function(int memberId, bool checked) onSelectionChanged;
  final VoidCallback onRefresh;
  final Map<int, Color> colorMap;
  final Map<int, String> nameMap;

  const _Row({
    required this.index,
    required this.member,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onRefresh,
    required this.colorMap,
    required this.nameMap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final m = member;
    final id = m.memberId;

    final start = m.membershipStartDate;
    final end = m.membershipEndDate;
    final dateRange = (start == null && end == null)
        ? '-'
        : (start == null ? (end ?? '-')
            : end == null ? start : '$start ~ $end');

    return InkWell(
      onTap: () => _openDetail(context, m),
      child: Container(
        color: isSelected ? Colors.orange.shade50 : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(children: [
          // 체크박스
          SizedBox(
            width: 32,
            child: Checkbox(
              value: isSelected,
              onChanged: id == null ? null : (v) =>
                  onSelectionChanged(id, v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          // 순번
          Expanded(flex: _flex[1],
            child: Text('${index + 1}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          // 이름
          Expanded(flex: _flex[2],
            child: Text(m.memberName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          // 고객 구분 태그들
          Expanded(flex: _flex[3],
            child: m.groupDefIds.isEmpty
                ? Text('-', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
                : Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: m.groupDefIds.map((gid) {
                      final color = colorMap[gid] ?? Colors.grey;
                      final name = nameMap[gid] ?? '#$gid';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 10, color: color,
                                fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  )),
          // 이용권명
          Expanded(flex: _flex[4],
            child: Text(m.ticketName ?? '-',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          // 이용날짜
          Expanded(flex: _flex[5],
            child: Text(dateRange,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          // 잔여
          Expanded(flex: _flex[6],
            child: MemberRemainCell(member: m)),
          // 옷대여
          Expanded(flex: _flex[7],
            child: Text(m.clothRentalYn == 'Y' ? 'O' : 'X',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: m.clothRentalYn == 'Y'
                        ? Colors.blue : Colors.grey.shade400))),
          // 락카
          Expanded(flex: _flex[8],
            child: Text(m.lockerRentalYn == 'Y' ? 'O' : 'X',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: m.lockerRentalYn == 'Y'
                        ? Colors.blue : Colors.grey.shade400))),
          // 이용권 등록 버튼
          Expanded(flex: _flex[9],
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 15),
              child: SizedBox(
                height: 22,
                child: ElevatedButton(
                  onPressed: id == null ? null : () => _addMembership(context, m),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 11),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: Text(loc.t('memberList.btn.addMembershipShort')),
                ),
              ),
            )),
          // 회원번호
          Expanded(flex: _flex[10],
            child: Text(m.memberNo,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          // 담당자
          Expanded(flex: _flex[11],
            child: Text(m.managerName ?? '-',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          // 가입일
          Expanded(flex: _flex[12],
            child: Text(m.joinDate ?? '-',
                style: const TextStyle(fontSize: 13))),
        ]),
      ),
    );
  }

  void _openDetail(BuildContext context, MemberModel m) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m)),
    );
    if (deleted == true && context.mounted) onRefresh();
  }

  void _addMembership(BuildContext context, MemberModel m) {
    showDialog(
      context: context,
      builder: (_) => AddMembershipDialog(
        memberId: m.memberId!,
        onSaved: onRefresh,
      ),
    );
  }
}
