import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/locale_provider.dart';
import '../screens/members/member_detail_screen.dart';
import '../screens/members/member_membership_tab.dart';

// 컬럼 flex 비율 (순번, 체크, 이름, 이용권명, 이용날짜, 잔여, 옷, 락카, 이용권등록, 회원번호, 담당자, 가입일, 마지막출석)
const _colFlex = [1, 1, 2, 3, 4, 2, 1, 1, 2, 2, 2, 2, 2];

/// 회원 목록 테이블 — 여러 화면에서 공용으로 사용
class MemberTable extends StatelessWidget {
  final List<MemberModel> members;
  final Set<int> selected;
  final void Function(int idx, bool checked) onSelectionChanged;
  final VoidCallback onRefresh;

  const MemberTable({
    super.key,
    required this.members,
    this.selected = const {},
    this.onSelectionChanged = _noop,
    required this.onRefresh,
  });

  static void _noop(int i, bool v) {}

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    if (members.isEmpty) {
      return Center(
        child: Text(loc.t('memberList.empty'),
            style: const TextStyle(color: Colors.grey)));
    }
    final headers = [
      loc.t('memberList.col.index'),
      '',
      loc.t('memberList.col.name'),
      loc.t('memberList.col.ticketName'),
      loc.t('memberList.col.dateRange'),
      loc.t('memberList.col.remain'),
      loc.t('memberList.col.cloth'),
      loc.t('memberList.col.locker'),
      loc.t('memberList.col.addMs'),
      loc.t('memberList.col.memberNo'),
      loc.t('memberList.col.manager'),
      loc.t('memberList.col.joinDate'),
      loc.t('memberList.col.lastAttendance'),
    ];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            // 헤더 행
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: List.generate(headers.length, (i) => Expanded(
                  flex: _colFlex[i],
                  child: Text(headers[i],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                )),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // 데이터 행
            Expanded(
              child: ListView.separated(
                itemCount: members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.5),
                itemBuilder: (context, index) {
                  final m = members[index];
                  final isSelected = selected.contains(index);
                  final dateRange = _dateRange(m);
                  return InkWell(
                    onTap: () => _openDetail(context, m),
                    child: Container(
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        child: Row(children: [
                          // 순번
                          Expanded(flex: 1,
                            child: Text('${index + 1}',
                              style: TextStyle(fontSize: 13,
                                  color: Colors.grey.shade600))),
                          // 체크박스
                          Expanded(flex: 1,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (v) =>
                                  onSelectionChanged(index, v ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            )),
                          // 이름
                          Expanded(flex: 2,
                            child: Text(m.memberName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                          // 이용권명
                          Expanded(flex: 3,
                            child: Text(m.ticketName ?? '-',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                          // 이용날짜
                          Expanded(flex: 4,
                            child: Text(dateRange,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                          // 잔여
                          Expanded(flex: 2,
                            child: MemberRemainCell(member: m)),
                          // 옷대여
                          Expanded(flex: 1,
                            child: Text(
                              m.clothRentalYn == 'Y' ? 'O' : 'X',
                              style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: m.clothRentalYn == 'Y'
                                    ? Colors.blue : Colors.grey.shade400))),
                          // 락카
                          Expanded(flex: 1,
                            child: Text(
                              m.lockerRentalYn == 'Y' ? 'O' : 'X',
                              style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: m.lockerRentalYn == 'Y'
                                    ? Colors.blue : Colors.grey.shade400))),
                          // 이용권 등록 버튼
                          Expanded(flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 4, right: 15),
                              child: SizedBox(
                                height: 22,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _addMembership(context, m),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    textStyle:
                                        const TextStyle(fontSize: 11),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero),
                                  ),
                                  child: Text(
                                      loc.t('memberList.btn.addMembershipShort')),
                                ),
                              ),
                            )),
                          // 회원번호
                          Expanded(flex: 2,
                            child: Text(m.memberNo,
                              style: TextStyle(fontSize: 13,
                                  color: Colors.grey.shade700))),
                          // 담당자
                          Expanded(flex: 2,
                            child: Text(m.managerName ?? '-',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                          // 가입일
                          Expanded(flex: 2,
                            child: Text(m.joinDate ?? '-',
                              style: const TextStyle(fontSize: 13))),
                          // 마지막 출석일
                          Expanded(flex: 2,
                            child: Text(m.lastAttendanceDate ?? '-',
                              style: TextStyle(
                                fontSize: 13,
                                color: m.lastAttendanceDate != null
                                    ? Colors.black87 : Colors.grey.shade400))),
                        ]),
                      ),
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

  String _dateRange(MemberModel m) {
    final start = m.membershipStartDate;
    final end   = m.membershipEndDate;
    if (start == null && end == null) return '-';
    if (start == null) return end!;
    if (end == null) return start;
    return '$start ~ $end';
  }

  void _openDetail(BuildContext context, MemberModel m) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: m)),
    );
    if (deleted == true && context.mounted) onRefresh();
  }

  void _addMembership(BuildContext context, MemberModel m) {
    if (m.memberId == null) return;
    showDialog(
      context: context,
      builder: (_) => AddMembershipDialog(
        memberId: m.memberId!,
        onSaved: onRefresh,
      ),
    );
  }
}

/// 잔여 셀: 횟수이용권=잔여횟수(회), 기간이용권=잔여일수(일)
class MemberRemainCell extends StatelessWidget {
  final MemberModel member;
  const MemberRemainCell({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final String text;
    Color color = Colors.black87;

    if (member.ticketType == 'COUNT') {
      final c = member.remainCount;
      if (c == null) {
        text = '-'; color = Colors.grey;
      } else if (c <= 0) {
        text = loc.t('memberList.remain.expired'); color = Colors.red;
      } else {
        text = loc.t('memberList.remain.counts', params: {'n': c.toString()});
        if (c <= 3) color = Colors.orange;
      }
    } else if (member.ticketType == 'PERIOD') {
      final d = member.remainDays;
      if (d == null) {
        text = '-'; color = Colors.grey;
      } else if (d < 0) {
        text = loc.t('memberList.remain.expired'); color = Colors.red;
      } else if (d == 0) {
        text = loc.t('memberList.remain.expireToday'); color = Colors.red;
      } else {
        text = loc.t('memberList.remain.days', params: {'n': d.toString()});
        if (d <= 3) color = Colors.orange;
      }
    } else {
      text = '-'; color = Colors.grey;
    }

    return Text(text,
        style: TextStyle(fontSize: 13, color: color,
            fontWeight: FontWeight.w600));
  }
}
