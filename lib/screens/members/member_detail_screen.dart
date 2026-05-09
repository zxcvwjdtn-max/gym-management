// 회원 상세 화면 — MemberDetailScreen, _MemberInfoPanel 및 분리된 탭 파일들을 조합
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import 'member_form_screen.dart';
import 'member_membership_tab.dart';
import 'member_accounting_tab.dart';
import 'member_attendance_tab.dart';
import 'member_locker_tab.dart';
import 'member_pt_tabs.dart';
import 'member_point_tab.dart';
import 'member_consultation_tab.dart';

// ──────────────────────────────────────────────────────────────
// 회원 상세 화면
// 상단: 회원 기본 정보 헤더
// 하단: 탭 (이용권 | 매출현황 | 출석현황 | 라커 | PT목록 | PT스케줄 | 포인트 | 상담)
// ──────────────────────────────────────────────────────────────
class MemberDetailScreen extends StatefulWidget {
  final MemberModel member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SingleTickerProviderStateMixin {
  late MemberModel _member;
  late TabController _tabCtrl;

  static const _tabCount = 8;

  List<Tab> _buildTabs(LocaleProvider loc) => [
    Tab(text: loc.t('member.tab.membership')),
    Tab(text: loc.t('member.tab.accounting')),
    Tab(text: loc.t('member.tab.attendance')),
    Tab(text: loc.t('member.tab.locker')),
    Tab(text: loc.t('member.tab.pt')),
    Tab(text: loc.t('member.tab.ptSchedule')),
    Tab(text: loc.t('member.tab.point')),
    Tab(text: loc.t('member.tab.consultation')),
  ];

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _tabCtrl = TabController(length: _tabCount, vsync: this);
    _refreshMember();
  }

  Future<void> _refreshMember() async {
    try {
      final updated = await context.read<ApiService>().getMemberDetail(_member.memberId!);
      if (mounted) setState(() => _member = updated);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMemo(String memo) async {
    final body = _member.toJson();
    body['memo'] = memo;
    body.remove('photoUrl'); // 사진은 별도 엔드포인트로 관리 — update SQL이 덮어쓰지 않도록
    await context.read<ApiService>().updateMember(_member.memberId!, body);
    final updated = await context.read<ApiService>().getMemberDetail(_member.memberId!);
    if (mounted) setState(() => _member = updated);
  }

  Future<void> _deleteMember() async {
    final loc = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('memberDetail.delete.title')),
        content: Text(loc.t('memberDetail.delete.content', params: {'name': _member.memberName})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteMember(_member.memberId!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, '${loc.t('memberDetail.delete.fail')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('memberDetail.title', params: {'name': _member.memberName})),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => MemberFormScreen(member: _member)),
              );
              if (result == true && mounted) {
                final updated = await context.read<ApiService>().getMemberDetail(_member.memberId!);
                setState(() => _member = updated);
              }
            },
            icon: const Icon(Icons.edit, color: Colors.white, size: 18),
            label: Text(loc.t('memberDetail.action.edit'), style: const TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: _deleteMember,
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: Text(loc.t('memberDetail.action.delete'), style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── 회원 정보 + 메모 패널 ──────────────────────────────
          _MemberInfoPanel(member: _member, onMemoSave: _saveMemo),
          // ── 탭바 ─────────────────────────────────────────────
          Container(
            color: const Color(0xFF0D47A1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TabBar(
              controller: _tabCtrl,
              tabs: _buildTabs(loc),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.transparent,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              splashBorderRadius: BorderRadius.circular(8),
            ),
          ),
          // ── 탭 콘텐츠 ─────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                MemberMembershipTab(memberId: _member.memberId!, member: _member),
                MemberAccountingTab(memberId: _member.memberId!),
                MemberAttendanceTab(memberId: _member.memberId!),
                MemberLockerTab(memberId: _member.memberId!),
                MemberPtContractTab(memberId: _member.memberId!),
                MemberPtSessionTab(memberId: _member.memberId!),
                MemberPointTab(memberId: _member.memberId!, memberName: _member.memberName),
                MemberConsultationTab(memberId: _member.memberId!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 회원 정보 + 메모 통합 패널
// ──────────────────────────────────────────────────────────────
class _MemberInfoPanel extends StatefulWidget {
  final MemberModel member;
  final Future<void> Function(String) onMemoSave;
  const _MemberInfoPanel({required this.member, required this.onMemoSave});

  @override
  State<_MemberInfoPanel> createState() => _MemberInfoPanelState();
}

class _MemberInfoPanelState extends State<_MemberInfoPanel> {
  bool _savingMemo = false;
  late TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    _memoCtrl = TextEditingController(text: widget.member.memo ?? '');
  }

  @override
  void didUpdateWidget(_MemberInfoPanel old) {
    super.didUpdateWidget(old);
    _memoCtrl.text = widget.member.memo ?? '';
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMemo() async {
    setState(() => _savingMemo = true);
    try {
      await widget.onMemoSave(_memoCtrl.text.trim());
      if (mounted) setState(() => _savingMemo = false);
    } catch (e) {
      if (mounted) {
        setState(() => _savingMemo = false);
        final loc = context.read<LocaleProvider>();
        showErrorSnack(context, '${loc.t('memberDetail.memo.saveFail')}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final m = widget.member;
    final statusColor = _statusColor(m.membershipStatus);
    final addressParts = <String>[
      if (m.postalCode != null && m.postalCode!.isNotEmpty) '[${m.postalCode}]',
      if (m.address != null && m.address!.isNotEmpty) m.address!,
      if (m.addressDetail != null && m.addressDetail!.isNotEmpty) m.addressDetail!,
    ];
    final addressStr = addressParts.join(' ');

    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SizedBox(
        height: 195,
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 사진 ──────────────────────────────────────────────
          Container(
            width: 155,
            height: 195,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white24,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            child: m.photoUrl != null
                ? Image.network(
                    m.photoUrl!,
                    key: ValueKey(m.photoUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(m),
                  )
                : _photoPlaceholder(m),
          ),
          const SizedBox(width: 18),

          // ── 회원 정보 ─────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이름 + 상태 뱃지
                Row(children: [
                  Text(m.memberName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  if (m.membershipStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_statusText(loc, m.membershipStatus),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 6),
                // 옷·락카 대여 뱃지
                Row(children: [
                  _rentalBadge(
                    icon: m.clothRentalYn == 'Y' ? Icons.checkroom : Icons.checkroom_outlined,
                    label: m.clothRentalYn == 'Y' ? loc.t('memberDetail.cloth.on') : loc.t('memberDetail.cloth.off'),
                    active: m.clothRentalYn == 'Y',
                    activeColor: Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  _rentalBadge(
                    icon: m.lockerRentalYn == 'Y' ? Icons.lock : Icons.lock_open_outlined,
                    label: m.lockerRentalYn == 'Y' ? loc.t('memberDetail.locker.on') : loc.t('memberDetail.locker.off'),
                    active: m.lockerRentalYn == 'Y',
                    activeColor: Colors.amber,
                  ),
                ]),
                const SizedBox(height: 8),
                // 정보 칩들
                Wrap(spacing: 16, runSpacing: 6, children: [
                  _chip(Icons.tag, loc.t('memberDetail.memberNoPrefix', params: {'no': m.memberNo})),
                  if (m.phone != null && m.phone!.isNotEmpty) _chip(Icons.phone, m.phone!),
                  if (m.parentPhone != null && m.parentPhone!.isNotEmpty)
                    _chip(Icons.phone_in_talk_outlined, loc.t('memberDetail.parentPrefix', params: {'phone': m.parentPhone!})),
                  if (m.birthDate != null && m.birthDate!.isNotEmpty) _chip(Icons.cake_outlined, m.birthDate!),
                  if (m.gender != null && m.gender!.isNotEmpty)
                    _chip(Icons.person_outline, m.gender == 'M' ? loc.t('memberForm.gender.male') : loc.t('memberForm.gender.female')),
                  if (m.ticketName != null) _chip(Icons.card_membership, m.ticketName!),
                  if (m.remainDays != null) _chip(Icons.timer_outlined, loc.t('memberDetail.remainDays', params: {'n': m.remainDays!.clamp(0, 99999).toString()})),
                  if (m.lastAttendanceDate != null)
                    _chip(Icons.event_available_outlined,
                      loc.t('memberDetail.lastAttendance', params: {'date': m.lastAttendanceDate!})),
                  _chip(
                    (m.smsYn == 'Y' || m.smsYn == 'BOTH') ? Icons.sms : Icons.sms_failed_outlined,
                    m.smsYn == 'BOTH' ? loc.t('memberDetail.sms.both')
                        : m.smsYn == 'Y' ? loc.t('memberDetail.sms.on')
                        : loc.t('memberDetail.sms.off'),
                  ),
                ]),
                // 주소
                if (addressStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 22, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(child: Text(addressStr,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                      overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ],
            ),
          ),

          // ── 세로 구분선 ───────────────────────────────────────
          Container(
            width: 1,
            color: Colors.white24,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // ── 메모 ─────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 메모 헤더 + 버튼
                Row(children: [
                  const Icon(Icons.notes, size: 22, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(loc.t('memberDetail.memo'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _memoCtrl.text = widget.member.memo ?? ''),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(loc.t('common.cancel'), style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _savingMemo ? null : _saveMemo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _savingMemo
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(loc.t('common.save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 6),
                // 메모 텍스트 필드 — 고정 높이로 채움
                Expanded(
                  child: TextField(
                    controller: _memoCtrl,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                    cursorColor: Colors.black54,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: loc.t('memberDetail.memo.hint'),
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black45),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(MemberModel m) => Center(
    child: Text(m.memberName.isNotEmpty ? m.memberName[0] : '?',
      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
  );

  Widget _rentalBadge({required IconData icon, required String label, required bool active, required Color activeColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.25) : Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? activeColor.withValues(alpha: 0.6) : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.white54),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.white54,
          )),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 16, color: c)),
      ],
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'ACTIVE': return Colors.green;
      case 'EXPIRING_SOON': return Colors.orange;
      case 'EXPIRED': return Colors.red;
      case 'PAUSED': return Colors.blue;
      case 'SUSPENDED': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  String _statusText(LocaleProvider loc, String? s) {
    switch (s) {
      case 'ACTIVE': return loc.t('memberDetail.status.active');
      case 'EXPIRING_SOON': return loc.t('memberDetail.status.expiringSoon');
      case 'EXPIRED': return loc.t('memberDetail.status.expired');
      case 'PAUSED': return loc.t('memberDetail.status.paused');
      case 'SUSPENDED': return loc.t('memberDetail.status.suspended');
      default: return '-';
    }
  }
}
