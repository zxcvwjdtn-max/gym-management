import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import 'member_form_screen.dart';
import '../../widgets/app_select.dart';

// ──────────────────────────────────────────────────────────────
// 회원 상세 화면
// 상단: 회원 기본 정보 헤더
// 하단: 탭 (이용권 | 매출현황 | 출석현황 | 라커 | PT목록 | PT스케줄)
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
    const Tab(text: '상담'),
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
                _MembershipTab(memberId: _member.memberId!, member: _member),
                _AccountingTab(memberId: _member.memberId!),
                _AttendanceTab(memberId: _member.memberId!),
                _LockerTab(memberId: _member.memberId!),
                _PtContractTab(memberId: _member.memberId!),
                _PtSessionTab(memberId: _member.memberId!),
                _PointTab(memberId: _member.memberId!, memberName: _member.memberName),
                _ConsultationTab(memberId: _member.memberId!),
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

// ──────────────────────────────────────────────────────────────
// 탭 1: 이용권 목록
// ──────────────────────────────────────────────────────────────
class _MembershipTab extends StatefulWidget {
  final int memberId;
  final MemberModel member;
  const _MembershipTab({required this.memberId, required this.member});

  @override
  State<_MembershipTab> createState() => _MembershipTabState();
}

class _MembershipTabState extends State<_MembershipTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<MembershipModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getMemberships(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Text('이용권 이력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddMembershipDialog(memberId: widget.memberId, onSaved: _load),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('이용권 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_list.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('등록된 이용권이 없습니다.', style: TextStyle(color: Colors.grey)),
          ))
        else
          ..._list.map((ms) => _MembershipCard(membership: ms, onAction: _load)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 탭 2: 매출현황
// ──────────────────────────────────────────────────────────────
class _AccountingTab extends StatefulWidget {
  final int memberId;
  const _AccountingTab({required this.memberId});

  @override
  State<_AccountingTab> createState() => _AccountingTabState();
}

class _AccountingTabState extends State<_AccountingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<AccountingModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiService>().getMemberAccounting(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    final total = _list.fold<int>(0, (s, e) {
      if (e.accountingType == 'INCOME') return s + (e.amount ?? 0);
      return s - (e.amount ?? 0);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 합계 카드
        Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              const Text('총 매출', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_fmt(total)}원',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: total >= 0 ? const Color(0xFF1565C0) : Colors.red,
                )),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (_list.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('매출 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
          ))
        else
          ..._list.map((acc) => _AccountingRow(acc: acc)),
      ],
    );
  }

  String _fmt(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return (v < 0 ? '-' : '') + buf.toString();
  }
}

class _AccountingRow extends StatelessWidget {
  final AccountingModel acc;
  const _AccountingRow({required this.acc});

  @override
  Widget build(BuildContext context) {
    final isIncome = acc.accountingType == 'INCOME';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(acc.description ?? _categoryText(acc.category),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            Text(acc.accountingDate ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        )),
        Text(
          '${isIncome ? '+' : '-'}${_fmtNum(acc.amount ?? 0)}원',
          style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16,
            color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ]),
    );
  }

  String _categoryText(String? c) {
    switch (c) {
      case 'TICKET': return '이용권';
      case 'ETC_INCOME': return '기타수입';
      case 'PURCHASE': return '매입';
      case 'UNPAID': return '미수금';
      default: return c ?? '-';
    }
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
// 탭 3: 출석현황 (달력)
// ──────────────────────────────────────────────────────────────
class _AttendanceTab extends StatefulWidget {
  final int memberId;
  const _AttendanceTab({required this.memberId});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<AttendanceModel> _list = [];
  bool _loading = true;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

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

    // 출석 날짜 Set
    final attendedDays = <int>{};
    for (final a in _list) {
      if (a.attendanceDate != null) {
        final d = DateTime.tryParse(a.attendanceDate!);
        if (d != null) attendedDays.add(d.day);
      }
    }

    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7; // 0=일

    return SingleChildScrollView(
      child: Column(
        children: [
          // 월 네비게이션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
              Expanded(
                child: Center(child: Text(
                  '${_month.year}년 ${_month.month}월  (출석 ${attendedDays.length}일)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showManualAddDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('수동 출석'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
              ),
            ]),
          ),
          // 요일 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['일','월','화','수','목','금','토'].map((d) => Expanded(
                child: Center(child: Text(d,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: d == '일' ? Colors.red : d == '토' ? Colors.blue : Colors.grey.shade700,
                  ))),
              )).toList(),
            ),
          ),
          const Divider(height: 8),
          // 달력 그리드
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
                        if (isAttended) ...[
                          Text('입 ${inTime != null ? fmt(inTime) : '-'}',
                            style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: Color(0xFF1565C0),
                            )),
                          Text('퇴 ${outTime != null ? fmt(outTime) : '-'}',
                            style: TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: outTime != null ? Colors.teal.shade700 : Colors.grey,
                            )),
                        ],
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
                              child: const Text('해제'),
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
                              child: const Text('출석'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 16),
          // 출석 목록
          if (_list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('출석 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
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
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16, backgroundColor: const Color(0xFF1565C0),
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  title: Text(a.attendanceDate ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  subtitle: Text(
                    '입장 $timeStr${checkoutStr != null ? '  퇴장 $checkoutStr' : '  퇴장 -'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('출석', style: TextStyle(color: Colors.green, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: '삭제',
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

  /// 해당 일자의 출석 기록 (없으면 null)
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

  Future<void> _showQuickAddDialog(int day) async {
    final target = DateTime(_month.year, _month.month, day);
    TimeOfDay inTime = TimeOfDay.now();
    TimeOfDay? outTime;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('${target.year}년 ${target.month}월 ${target.day}일 출석 등록'),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login, size: 20),
                title: const Text('입장 시각'),
                trailing: Text(
                  '${inTime.hour.toString().padLeft(2,'0')}:${inTime.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: inTime);
                  if (t != null) setSt(() => inTime = t);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, size: 20),
                title: const Text('퇴장 시각 (선택)'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    outTime == null ? '미입력'
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('등록')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    if (outTime != null) {
      final inM = inTime.hour * 60 + inTime.minute;
      final outM = outTime!.hour * 60 + outTime!.minute;
      if (outM <= inM) {
        showErrorSnack(context, '퇴장 시각은 입장 시각보다 늦어야 합니다.');
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
      if (mounted) showSuccessSnack(context, '출석이 등록되었습니다.');
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, '등록 실패: $e');
    }
  }

  Future<void> _confirmDelete(AttendanceModel a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('출석 기록 삭제'),
        content: Text('${a.attendanceDate} 출석 기록을 삭제하시겠습니까?\n횟수제 이용권인 경우 1회가 복구됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteAttendance(a.attendanceId!);
      if (mounted) showSuccessSnack(context, '삭제되었습니다.');
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }

  Future<void> _showManualAddDialog() async {
    DateTime selectedDate = DateTime(_month.year, _month.month,
        DateTime.now().month == _month.month ? DateTime.now().day : 1);
    TimeOfDay inTime = TimeOfDay.now();
    TimeOfDay? outTime;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('수동 출석 등록'),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: const Text('날짜'),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login, size: 20),
                title: const Text('입장 시각'),
                trailing: Text(
                  '${inTime.hour.toString().padLeft(2,'0')}:${inTime.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: inTime);
                  if (t != null) setSt(() => inTime = t);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, size: 20),
                title: const Text('퇴장 시각 (선택)'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    outTime == null ? '미입력'
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('등록'),
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
        showErrorSnack(context, '퇴장 시각은 입장 시각보다 늦어야 합니다.');
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
      if (mounted) showSuccessSnack(context, '출석이 등록되었습니다.');
      // 등록된 날짜의 월로 이동 후 재조회
      if (selectedDate.year != _month.year || selectedDate.month != _month.month) {
        setState(() => _month = DateTime(selectedDate.year, selectedDate.month));
      }
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, '등록 실패: $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────
// 탭 4: 라커 목록
// ──────────────────────────────────────────────────────────────
class _LockerTab extends StatefulWidget {
  final int memberId;
  const _LockerTab({required this.memberId});

  @override
  State<_LockerTab> createState() => _LockerTabState();
}

class _LockerTabState extends State<_LockerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<LockerModel> _allLockers = [];
  List<LockerModel> _memberLockers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getLockers(),
        api.getLockersByMember(widget.memberId),
      ]);
      if (mounted) setState(() {
        _allLockers = results[0] as List<LockerModel>;
        _memberLockers = results[1] as List<LockerModel>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Text('배정된 라커', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _showAssignDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('라커 배정'),
          ),
        ]),
        const SizedBox(height: 10),
        if (_memberLockers.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('배정된 라커가 없습니다.', style: TextStyle(color: Colors.grey)),
          ))
        else
          ..._memberLockers.map((l) => _LockerCard(locker: l, onAction: _load)),
      ],
    );
  }

  void _showAssignDialog() {
    final available = _allLockers.where((l) => l.status == 'AVAILABLE').toList();
    if (available.isEmpty) {
      showErrorSnack(context, '배정 가능한 라커가 없습니다.');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _AssignLockerDialog(
        memberId: widget.memberId,
        availableLockers: available,
        onSaved: _load,
      ),
    );
  }
}

class _LockerCard extends StatelessWidget {
  final LockerModel locker;
  final VoidCallback onAction;
  const _LockerCard({required this.locker, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(locker.lockerNo ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('라커 ${locker.lockerNo}번', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (locker.startDate != null)
              Text('${locker.startDate} ~ ${locker.endDate ?? '기간 미정'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            if (locker.monthlyFee != null && locker.monthlyFee! > 0)
              Text('월 ${locker.monthlyFee}원', style: const TextStyle(fontSize: 16)),
          ],
        )),
        OutlinedButton(
          onPressed: () => _release(context),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('해제', style: TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }

  void _release(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('라커 배정 해제'),
        content: Text('라커 ${locker.lockerNo}번 배정을 해제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<ApiService>().releaseLocker(locker.lockerId!);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '실패: $e');
    }
  }
}

class _AssignLockerDialog extends StatefulWidget {
  final int memberId;
  final List<LockerModel> availableLockers;
  final VoidCallback onSaved;
  const _AssignLockerDialog({
    required this.memberId,
    required this.availableLockers,
    required this.onSaved,
  });

  @override
  State<_AssignLockerDialog> createState() => _AssignLockerDialogState();
}

class _AssignLockerDialogState extends State<_AssignLockerDialog> {
  int? _selectedLockerId;
  DateTime? _startDate;
  DateTime? _endDate;
  final _feeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _feeCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (_selectedLockerId == null) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().assignLocker(_selectedLockerId!, {
        'memberId': widget.memberId,
        'startDate': _fmt(_startDate).isNotEmpty ? _fmt(_startDate) : null,
        'endDate': _fmt(_endDate).isNotEmpty ? _fmt(_endDate) : null,
        'monthlyFee': int.tryParse(_feeCtrl.text) ?? 0,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, '실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('라커 배정'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FormSelect<int>(
              label: '라커 선택',
              isRequired: true,
              currentLabel: _selectedLockerId == null ? null
                  : '${widget.availableLockers.firstWhere((l) => l.lockerId == _selectedLockerId, orElse: () => widget.availableLockers.first).lockerNo}번',
              hint: '라커 선택',
              options: widget.availableLockers.map((l) => ('${l.lockerNo}번', l.lockerId as int?)).toList(),
              onSelected: (v) => setState(() => _selectedLockerId = v),
            ),
            const SizedBox(height: 12),
            // 시작일 달력 선택
            InkWell(
              onTap: _pickStart,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '시작일',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_startDate != null ? _fmt(_startDate) : '선택하세요',
                    style: TextStyle(color: _startDate != null ? Colors.black87 : Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            // 종료일 달력 선택
            InkWell(
              onTap: _pickEnd,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '종료일',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_endDate != null ? _fmt(_endDate) : '선택하세요',
                    style: TextStyle(color: _endDate != null ? Colors.black87 : Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _feeCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '월 이용료', border: OutlineInputBorder(), suffixText: '원')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('배정'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 탭 5: PT 계약 목록
// ──────────────────────────────────────────────────────────────
class _PtContractTab extends StatefulWidget {
  final int memberId;
  const _PtContractTab({required this.memberId});

  @override
  State<_PtContractTab> createState() => _PtContractTabState();
}

class _PtContractTabState extends State<_PtContractTab>
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('PT 계약 목록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_list.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('PT 계약 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
          ))
        else
          ..._list.map((c) => _PtContractCard(contract: c)),
      ],
    );
  }
}

class _PtContractCard extends StatelessWidget {
  final PtContractModel contract;
  const _PtContractCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    final statusColor = contract.status == 'ACTIVE' ? Colors.green
        : contract.status == 'COMPLETED' ? Colors.blue : Colors.grey;
    final statusText = contract.status == 'ACTIVE' ? '진행중'
        : contract.status == 'COMPLETED' ? '완료' : '취소';
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
            Text('$used / $total 회',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text('잔여 ${contract.remainSessions ?? 0}회  |  ${_fmtNum(contract.price ?? 0)}원',
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
class _PtSessionTab extends StatefulWidget {
  final int memberId;
  const _PtSessionTab({required this.memberId});

  @override
  State<_PtSessionTab> createState() => _PtSessionTabState();
}

class _PtSessionTabState extends State<_PtSessionTab>
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

    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final monthSessions = _monthSessions;
    final displaySessions = _selectedDay != null ? _daySessions(_selectedDay!) : monthSessions;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 월 네비게이션
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() { _month = DateTime(_month.year, _month.month - 1); _selectedDay = null; }),
              ),
              Expanded(
                child: Center(child: Text(
                  '${_month.year}년 ${_month.month}월  (${monthSessions.length}건)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() { _month = DateTime(_month.year, _month.month + 1); _selectedDay = null; }),
              ),
            ]),
          ),
          // 범례
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _legend(const Color(0xFF4527A0), '예정'),
              const SizedBox(width: 14),
              _legend(Colors.green, '완료'),
              const SizedBox(width: 14),
              _legend(Colors.red, '노쇼'),
              const SizedBox(width: 14),
              _legend(Colors.grey, '취소'),
            ]),
          ),
          const SizedBox(height: 8),
          // 요일 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['일','월','화','수','목','금','토'].map((d) => Expanded(
                child: Center(child: Text(d,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: d == '일' ? Colors.red : d == '토' ? Colors.blue : Colors.grey.shade700,
                  ))),
              )).toList(),
            ),
          ),
          const Divider(height: 8),
          // 달력 그리드
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
          // 세션 목록 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(
                _selectedDay != null
                    ? '${_month.month}월 ${_selectedDay}일 세션'
                    : '${_month.month}월 전체 세션',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text('(${displaySessions.length}건)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              if (_selectedDay != null) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: const Text('전체보기', style: TextStyle(fontSize: 16)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 6),
          // 세션 목록
          if (displaySessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('세션이 없습니다.', style: TextStyle(color: Colors.grey))),
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

class _PtSessionRow extends StatelessWidget {
  final PtSessionModel session;
  final VoidCallback onAction;
  const _PtSessionRow({required this.session, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final statusColor = _sessionColor(session.status);
    final statusText = _sessionText(session.status);
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
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'complete', child: Text('완료')),
              PopupMenuItem(value: 'no-show', child: Text('노쇼')),
              PopupMenuItem(value: 'cancel', child: Text('취소')),
            ],
            onSelected: (action) => _changeStatus(context, action),
          ),
        ],
      ]),
    );
  }

  void _changeStatus(BuildContext context, String action) async {
    try {
      final api = context.read<ApiService>();
      if (action == 'complete') await api.completePtSession(session.sessionId!);
      if (action == 'no-show') await api.noShowPtSession(session.sessionId!);
      if (action == 'cancel') await api.cancelPtSession(session.sessionId!);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '실패: $e');
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

  String _sessionText(String? s) {
    switch (s) {
      case 'SCHEDULED': return '예정';
      case 'COMPLETED': return '완료';
      case 'NO_SHOW': return '노쇼';
      case 'CANCELLED': return '취소';
      default: return '-';
    }
  }
}

// ──────────────────────────────────────────────────────────────
// 이용권 카드 (기존 코드 이전)
// ──────────────────────────────────────────────────────────────
class _MembershipCard extends StatelessWidget {
  final MembershipModel membership;
  final VoidCallback onAction;
  const _MembershipCard({required this.membership, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final statusColor = _statusColor(membership.status);
    final isValid = membership.status == 'ACTIVE' ||
        membership.status == 'EXPIRING_SOON' ||
        membership.status == 'PAUSED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: isValid ? Colors.grey.shade300 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
        color: isValid ? Colors.white : Colors.grey.shade50,
      ),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isValid ? 14 : 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── 공통 첫 줄: 이름(+기간) | 상태뱃지 | 연장 | 삭제
        Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(child: Text(membership.ticketName ?? '-',
                style: TextStyle(
                  fontWeight: isValid ? FontWeight.bold : FontWeight.w600,
                  fontSize: isValid ? 14 : 13,
                  color: isValid ? Colors.black87 : Colors.grey.shade700),
                overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Text('${membership.startDate} ~ ${membership.endDate}',
                style: TextStyle(
                  color: isValid ? Colors.grey.shade600 : Colors.grey.shade500,
                  fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(isValid ? 40 : 25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_statusText(loc, membership.status),
              style: TextStyle(color: statusColor,
                fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          _ActionBtn(label: '연장', icon: Icons.add, onTap: () => _extend(context)),
          const SizedBox(width: 4),
          _ActionBtn(label: '삭제', icon: Icons.delete_outline,
            onTap: () => _delete(context), color: Colors.red.shade700),
        ]),

        // ── 유효 이용권만: 잔여일/잔여횟수 + 상태 버튼 (두 번째 줄)
        if (isValid) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (membership.remainCount != null) ...[
              Icon(Icons.tag, size: 13, color: Colors.purple.shade600),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('잔여 ${membership.remainCount}회',
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
            ],
            if (membership.remainDays != null && membership.remainDays! >= 0) ...[
              Icon(Icons.timelapse, size: 13, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('잔여 ${membership.remainDays}일',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
              ),
              const SizedBox(width: 10),
            ],
            if (membership.status == 'PAUSED')
              _ActionBtn(label: '재개', icon: Icons.play_arrow, onTap: () => _resume(context)),
            if (membership.status != 'PAUSED') ...[
              _ActionBtn(label: '일시정지', icon: Icons.pause, onTap: () => _pause(context)),
              const SizedBox(width: 4),
              _ActionBtn(label: '정지', icon: Icons.block, onTap: () => _suspend(context),
                color: Colors.red.shade400),
            ],
          ]),
          // 일시정지 기간 정보
          if (membership.status == 'PAUSED' && membership.pauseStartDate != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.pause_circle_outline, size: 13, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text(
                '정지 시작: ${membership.pauseStartDate}'
                '${membership.pauseEndDate != null ? ' ~ ${membership.pauseEndDate} (재개 예정)' : ''}',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ]),
          ],
        ],
      ]),
    );
  }

  void _extend(BuildContext context) async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _ExtendDialog(membership: membership),
    );
    if (days == null) return;
    try {
      await context.read<ApiService>().extendMembership(membership.membershipId!, days);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '실패: $e');
    }
  }

  void _pause(BuildContext context) async {
    final result = await showDialog<_PauseResult>(
      context: context,
      builder: (_) => const _PauseDialog(),
    );
    if (result == null) return;
    try {
      await context.read<ApiService>().pauseMembership(
        membership.membershipId!, days: result.days);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '실패: $e');
    }
  }

  void _resume(BuildContext context) async {
    await context.read<ApiService>().resumeMembership(membership.membershipId!);
    onAction();
  }

  void _suspend(BuildContext context) async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _SuspendDialog(membership: membership),
    );
    if (days == null) return;
    try {
      await context.read<ApiService>().suspendMembership(membership.membershipId!, days: days);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '실패: $e');
    }
  }

  void _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이용권 삭제'),
        content: Text('「${membership.ticketName ?? '-'}」 이용권을 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<ApiService>().deleteMembership(membership.membershipId!);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '삭제 실패: $e');
    }
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

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _ActionBtn({required this.label, required this.icon,
      required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blue.shade700;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: c),
      label: Text(label, style: TextStyle(fontSize: 16, color: c)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withAlpha(128)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 연장 다이얼로그
// ──────────────────────────────────────────────────────────────
class _ExtendDialog extends StatefulWidget {
  final MembershipModel membership;
  const _ExtendDialog({required this.membership});
  @override
  State<_ExtendDialog> createState() => _ExtendDialogState();
}

class _ExtendDialogState extends State<_ExtendDialog> {
  bool _usePicker = false;
  final _daysCtrl = TextEditingController();
  DateTime? _pickedDate;

  @override
  void dispose() { _daysCtrl.dispose(); super.dispose(); }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  DateTime? get _currentEnd {
    final s = widget.membership.endDate;
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  DateTime? get _newEnd {
    if (_usePicker) return _pickedDate;
    final d = int.tryParse(_daysCtrl.text);
    if (d == null || d <= 0) return null;
    final base = _currentEnd ?? DateTime.now();
    return base.add(Duration(days: d));
  }

  int? get _days {
    if (_usePicker) {
      if (_pickedDate == null) return null;
      final base = _currentEnd ?? DateTime.now();
      return _pickedDate!.difference(base).inDays;
    }
    return int.tryParse(_daysCtrl.text);
  }

  bool get _valid => (_days ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final newEnd = _newEnd;
    return AlertDialog(
      title: const Text('이용권 연장'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 입력 방식 토글
            Row(children: [
              const Text('입력 방식:', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('일수 입력'),
                selected: !_usePicker,
                onSelected: (_) => setState(() { _usePicker = false; _pickedDate = null; }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('달력 선택'),
                selected: _usePicker,
                onSelected: (_) => setState(() { _usePicker = true; _daysCtrl.clear(); }),
              ),
            ]),
            const SizedBox(height: 16),
            if (!_usePicker)
              TextField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '연장 일수', hintText: '예: 30',
                  border: OutlineInputBorder(), suffixText: '일',
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () async {
                  final base = _currentEnd ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: base.add(const Duration(days: 30)),
                    firstDate: base.add(const Duration(days: 1)),
                    lastDate: DateTime(2099),
                  );
                  if (picked != null) setState(() => _pickedDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_pickedDate != null ? _fmt(_pickedDate!) : '새 종료일 선택'),
              ),
            const SizedBox(height: 16),
            // 계산 결과 요약
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.event, size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Text('현재 종료일',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(widget.membership.endDate ?? '-',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.event_available, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text('연장 후 종료일',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(
                      newEnd != null ? _fmt(newEnd) : '-',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: newEnd != null ? Colors.blue.shade700 : Colors.grey,
                      ),
                    ),
                  ]),
                  if (_days != null && _days! > 0) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('+${_days}일 연장',
                        style: TextStyle(fontSize: 16, color: Colors.blue.shade600)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _valid ? () => Navigator.pop(context, _days) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          child: const Text('연장'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 정지 다이얼로그
// ──────────────────────────────────────────────────────────────
class _SuspendDialog extends StatefulWidget {
  final MembershipModel membership;
  const _SuspendDialog({required this.membership});
  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  bool _usePicker = false;
  bool _indefinite = false;
  final _daysCtrl = TextEditingController();
  DateTime? _pickedEnd;
  final DateTime _startDate = DateTime.now();

  @override
  void dispose() { _daysCtrl.dispose(); super.dispose(); }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  DateTime? get _endDate {
    if (_indefinite) return null;
    if (_usePicker) return _pickedEnd;
    final d = int.tryParse(_daysCtrl.text);
    if (d == null || d <= 0) return null;
    return _startDate.add(Duration(days: d));
  }

  int get _days {
    if (_indefinite) return 0;
    if (_usePicker) {
      if (_pickedEnd == null) return 0;
      return _pickedEnd!.difference(_startDate).inDays;
    }
    return int.tryParse(_daysCtrl.text) ?? 0;
  }

  bool get _valid => _indefinite || _days > 0;

  @override
  Widget build(BuildContext context) {
    final endDate = _endDate;
    return AlertDialog(
      title: const Text('이용권 정지'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 무기한 정지 토글
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('무기한 정지', style: TextStyle(fontSize: 16)),
              subtitle: const Text('수동으로 재개할 때까지 정지', style: TextStyle(fontSize: 16)),
              value: _indefinite,
              onChanged: (v) => setState(() {
                _indefinite = v;
                if (v) { _daysCtrl.clear(); _pickedEnd = null; }
              }),
            ),
            if (!_indefinite) ...[
              const Divider(),
              const SizedBox(height: 4),
              // 입력 방식 토글
              Row(children: [
                const Text('입력 방식:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('일수 입력'),
                  selected: !_usePicker,
                  onSelected: (_) => setState(() { _usePicker = false; _pickedEnd = null; }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('달력 선택'),
                  selected: _usePicker,
                  onSelected: (_) => setState(() { _usePicker = true; _daysCtrl.clear(); }),
                ),
              ]),
              const SizedBox(height: 12),
              if (!_usePicker)
                TextField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '정지 일수', hintText: '예: 14',
                    border: OutlineInputBorder(), suffixText: '일',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate.add(const Duration(days: 7)),
                      firstDate: _startDate.add(const Duration(days: 1)),
                      lastDate: DateTime(2099),
                    );
                    if (picked != null) setState(() => _pickedEnd = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_pickedEnd != null ? _fmt(_pickedEnd!) : '정지 종료일 선택'),
                ),
            ],
            const SizedBox(height: 16),
            // 계산 결과 요약
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.block, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Text('정지 시작일',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(_fmt(_startDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.event_busy, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text('정지 종료일',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(
                      _indefinite ? '무기한' : (endDate != null ? _fmt(endDate) : '-'),
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: _indefinite ? Colors.grey.shade600
                            : (endDate != null ? Colors.red.shade700 : Colors.grey),
                      ),
                    ),
                  ]),
                  if (!_indefinite && _days > 0) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('${_days}일 정지',
                        style: TextStyle(fontSize: 16, color: Colors.red.shade600)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _valid ? () => Navigator.pop(context, _days) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
          child: const Text('정지'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 일시정지 다이얼로그
// ──────────────────────────────────────────────────────────────
class _PauseResult {
  final int days;
  const _PauseResult(this.days);
}

class _PauseDialog extends StatefulWidget {
  const _PauseDialog();
  @override
  State<_PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<_PauseDialog> {
  bool _useEndDate = false;
  final _daysCtrl = TextEditingController();

  @override
  void dispose() {
    _daysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('일시정지'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('정지 기간 지정'),
              subtitle: const Text('꺼짐: 수동으로 재개할 때까지 정지'),
              value: _useEndDate,
              onChanged: (v) => setState(() {
                _useEndDate = v;
                if (!v) _daysCtrl.clear();
              }),
            ),
            if (_useEndDate) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '정지 일수', hintText: '예: 14',
                  border: OutlineInputBorder(), suffixText: '일',
                ),
              ),
              const SizedBox(height: 6),
              () {
                final d = int.tryParse(_daysCtrl.text);
                if (d == null || d <= 0) return const SizedBox.shrink();
                final endDate = DateTime.now().add(Duration(days: d));
                return Text(
                  '재개 예정일: ${endDate.year}-'
                  '${endDate.month.toString().padLeft(2,'0')}-'
                  '${endDate.day.toString().padLeft(2,'0')}',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 16),
                );
              }(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            int days = 0;
            if (_useEndDate) {
              days = int.tryParse(_daysCtrl.text) ?? 0;
              if (days <= 0) return;
            }
            Navigator.pop(context, _PauseResult(days));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
          child: const Text('정지'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 이용권 추가 다이얼로그
// ──────────────────────────────────────────────────────────────
class AddMembershipDialog extends StatefulWidget {
  final int memberId;
  final VoidCallback onSaved;
  const AddMembershipDialog({super.key, required this.memberId, required this.onSaved});

  @override
  State<AddMembershipDialog> createState() => _AddMembershipDialogState();
}

class _AddMembershipDialogState extends State<AddMembershipDialog> {
  List<TicketModel> _tickets = [];
  TicketModel? _ticket;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final _amountCtrl  = TextEditingController();
  final _unpaidCtrl  = TextEditingController();
  final _memoCtrl    = TextEditingController();
  String _method = 'TRANSFER';
  String? _cardCompany;
  bool _saving = false;

  static const _cardCompanies = [
    'BC카드', '신한카드', '현대카드', '삼성카드', '롯데카드',
    '하나카드', 'NH농협카드', 'KB국민카드', '씨티카드', '우리카드', '카카오뱅크',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _unpaidCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await context.read<ApiService>().getTickets(scope: 'GYM');
    if (mounted) setState(() => _tickets = t);
  }

  void _onTicketChanged(TicketModel? t) {
    if (t == null) return;
    setState(() {
      _ticket = t;
      _amountCtrl.text = t.price.toString();
      _recalcEnd();
    });
  }

  void _recalcEnd() {
    if (_ticket == null) return;
    final int months = _ticket!.durationMonths;
    final int days   = _ticket!.durationDays ?? 0;
    final DateTime end;
    if (months > 0 || days > 0) {
      // 기간제/횟수제 공통: 시작일 + 개월 + 일수 - 1일 (백엔드와 동일)
      end = DateTime(_startDate.year, _startDate.month + months,
          _startDate.day + days - 1);
    } else {
      // duration 미설정 시 기본 1년
      end = DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
    }
    setState(() => _endDate = end);
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ko'),
    );
    if (picked != null) {
      setState(() { _startDate = picked; _recalcEnd(); });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2035),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _save() async {
    if (_ticket == null) { showErrorSnack(context, '이용권을 선택해주세요.'); return; }
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().createMembership({
        'memberId'      : widget.memberId,
        'ticketId'      : _ticket!.ticketId,
        'startDate'     : _fmt(_startDate),
        if (_endDate != null) 'endDate': _fmt(_endDate!),
        'paymentAmount' : int.tryParse(_amountCtrl.text) ?? 0,
        'paymentMethod' : _method,
        if (_method == 'CARD' && _cardCompany != null) 'cardCompany': _cardCompany,
        if ((int.tryParse(_unpaidCtrl.text) ?? 0) > 0) 'unpaidAmount': int.tryParse(_unpaidCtrl.text),
        if (_memoCtrl.text.trim().isNotEmpty) 'memo': _memoCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, '실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이용권 추가'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 이용권 선택
            FormSelect<TicketModel>(
              label: '이용권',
              isRequired: true,
              currentLabel: _ticket == null ? null
                  : '${_ticket!.isCommon ? '[공통] ' : ''}${_ticket!.ticketName}  (${_fmtPrice(_ticket!.price)})',
              hint: '이용권 선택',
              options: _tickets.map((t) => (
                '${t.isCommon ? '[공통] ' : ''}${t.ticketName}  (${_fmtPrice(t.price)})',
                t as TicketModel?,
              )).toList(),
              onSelected: _onTicketChanged,
            ),
            const SizedBox(height: 14),

            // 시작일
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStart,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '시작일', border: OutlineInputBorder()),
                    child: Row(children: [
                      Text(_fmt(_startDate), style: const TextStyle(fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 종료일
              Expanded(
                child: InkWell(
                  onTap: _pickEnd,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: _ticket?.isCount == true
                          ? (_endDate != null ? '유효기간 마감일 (직접변경 가능)' : '유효기간 마감일 (자동계산)')
                          : (_endDate != null ? '종료일 (직접변경 가능)' : '종료일 (자동계산)'),
                      border: const OutlineInputBorder()),
                    child: Row(children: [
                      Text(
                        _endDate != null ? _fmt(_endDate!) : '이용권 선택 후 표시',
                        style: TextStyle(
                          fontSize: 15,
                          color: _endDate != null ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar, size: 18, color: Colors.grey),
                    ]),
                  ),
                ),
              ),
            ]),

            // 요약 정보
            if (_ticket != null && _endDate != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _ticket!.isCount ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _ticket!.isCount ? Colors.purple.shade200 : Colors.blue.shade200),
                ),
                child: _ticket!.isCount
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.fitness_center, size: 15, color: Colors.purple.shade700),
                        const SizedBox(width: 6),
                        Text(
                          _ticket!.totalCount != null ? '총 ${_ticket!.totalCount}회' : '횟수제',
                          style: TextStyle(color: Colors.purple.shade800,
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.event_available, size: 15, color: Colors.purple.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '유효기간 ${_fmt(_startDate)}  ~  ${_fmt(_endDate!)}',
                          style: TextStyle(color: Colors.purple.shade800,
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ])
                    : Text(
                        '${_fmt(_startDate)}  ~  ${_fmt(_endDate!)}',
                        style: TextStyle(color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
              ),
            ],
            const SizedBox(height: 14),

            // 결제금액 / 결제방법
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '결제금액', border: OutlineInputBorder(), suffixText: '원'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormSelect<String>(
                  label: '결제방법',
                  currentLabel: const {'CARD': '카드', 'CASH': '현금', 'TRANSFER': '계좌이체'}[_method],
                  hint: '선택',
                  options: const [('카드', 'CARD'), ('현금', 'CASH'), ('계좌이체', 'TRANSFER')],
                  onSelected: (v) {
                    if (v != null) setState(() {
                      _method = v;
                      if (v != 'CARD') _cardCompany = null;
                    });
                  },
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // 카드사 선택 (카드 결제 시)
            if (_method == 'CARD') ...[
              FormSelect<String>(
                label: '카드사',
                currentLabel: _cardCompany,
                hint: '카드사 선택 (선택사항)',
                options: _cardCompanies.map((c) => (c, c)).toList(),
                onSelected: (v) => setState(() => _cardCompany = v),
              ),
              const SizedBox(height: 10),
            ],

            // 미수금
            TextField(
              controller: _unpaidCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '미수금',
                border: OutlineInputBorder(),
                suffixText: '원',
                helperText: '미납 금액 (없으면 비워두세요)',
              ),
            ),
            const SizedBox(height: 14),

            // 메모
            TextField(
              controller: _memoCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '메모', border: OutlineInputBorder()),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('등록'),
        ),
      ],
    );
  }

  String _fmtPrice(int p) =>
      p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},') + '원';
}

// ══════════════════════════════════════════════════════════════
// 포인트 탭
// ══════════════════════════════════════════════════════════════
class _PointTab extends StatefulWidget {
  final int memberId;
  final String memberName;
  const _PointTab({required this.memberId, required this.memberName});

  @override
  State<_PointTab> createState() => _PointTabState();
}

class _PointTabState extends State<_PointTab> {
  int _balance = 0;
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getMemberPoint(widget.memberId);
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;
        final list = data['ledger'] as List? ?? [];
        _ledger = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, '불러오기 실패: $e');
      }
    }
  }

  Future<void> _adjust({required bool isEarn}) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEarn ? '포인트 수동 적립' : '포인트 차감'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isEarn ? '적립 포인트' : '차감 포인트',
                  border: const OutlineInputBorder(),
                  suffixText: 'P',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '사유',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEarn ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isEarn ? '적립' : '차감'),
          ),
        ],
      ),
    );
    if (result != true) return;

    final raw = int.tryParse(amountCtrl.text.trim());
    if (raw == null || raw <= 0) {
      if (mounted) showErrorSnack(context, '올바른 포인트 값을 입력하세요.');
      return;
    }
    final amount = isEarn ? raw : -raw;
    final desc = descCtrl.text.trim();
    if (desc.isEmpty) {
      if (mounted) showErrorSnack(context, '사유를 입력하세요.');
      return;
    }

    try {
      await context.read<ApiService>().adjustPoint(widget.memberId, amount, desc);
      if (mounted) {
        showSuccessSnack(context, '처리 완료');
        await _load();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.stars, color: Colors.orange, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.memberName}님의 포인트 잔액',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${_fmtNumber(_balance)} P',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _adjust(isEarn: true),
                  icon: const Icon(Icons.add),
                  label: const Text('적립'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _adjust(isEarn: false),
                  icon: const Icon(Icons.remove),
                  label: const Text('차감'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('포인트 이력',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: _ledger.isEmpty
                  ? const Center(
                      child: Text('포인트 이력이 없습니다.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _ledger.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = _ledger[i];
                        final amount = (e['pointAmount'] as num?)?.toInt() ?? 0;
                        final isEarn = amount >= 0;
                        final type = e['pointType'] ?? '';
                        final source = e['sourceType'] ?? '';
                        final desc = e['description'] ?? '';
                        final balanceAfter = (e['balanceAfter'] as num?)?.toInt() ?? 0;
                        final createdAt = e['createdAt'] ?? '';
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isEarn ? Colors.green : Colors.red).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEarn ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isEarn ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Row(children: [
                            _typeBadge(type, source),
                            const SizedBox(width: 8),
                            Expanded(child: Text(desc.toString(),
                                overflow: TextOverflow.ellipsis)),
                          ]),
                          subtitle: Text(_fmtDate(createdAt.toString()),
                              style: const TextStyle(fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isEarn ? '+' : ''}${_fmtNumber(amount)} P',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isEarn ? Colors.green : Colors.red,
                                ),
                              ),
                              Text('잔액 ${_fmtNumber(balanceAfter)}P',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type, String source) {
    Color c;
    String label;
    if (source == 'TICKET_SALE') { c = Colors.blue; label = '이용권 적립'; }
    else if (source == 'MANUAL') { c = type == 'EARN' ? Colors.green : Colors.red; label = '수동'; }
    else if (type == 'USE') { c = Colors.orange; label = '사용'; }
    else { c = Colors.grey; label = type; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _fmtNumber(int n) {
    final neg = n < 0;
    final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return neg ? '-$s' : s;
  }

  String _fmtDate(String s) {
    if (s.isEmpty) return '-';
    if (s.length >= 19) return s.substring(0, 16).replaceAll('T', ' ');
    return s;
  }
}

// ──────────────────────────────────────────────────────────────
// 탭 8: 상담 내역
// ──────────────────────────────────────────────────────────────
class _ConsultationTab extends StatefulWidget {
  final int memberId;
  const _ConsultationTab({required this.memberId});

  @override
  State<_ConsultationTab> createState() => _ConsultationTabState();
}

class _ConsultationTabState extends State<_ConsultationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<ConsultationModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getConsultations(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog({ConsultationModel? existing}) {
    showDialog(
      context: context,
      builder: (_) => _ConsultationDialog(
        memberId: widget.memberId,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(ConsultationModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('상담 삭제'),
        content: const Text('이 상담 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteConsultation(c.consultationId!);
      _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Text('상담 내역 (${_list.length}건)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('상담 등록'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),
        Expanded(
          child: _list.isEmpty
              ? const Center(child: Text('상담 내역이 없습니다.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = _list[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4, offset: const Offset(0, 2),
                        )],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 16, color: Colors.blue.shade400),
                            const SizedBox(width: 6),
                            Text(c.consultDate ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            if (c.createdBy != null)
                              Text(c.createdBy!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade500)),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showAddDialog(existing: c),
                              child: Icon(Icons.edit_outlined,
                                  size: 18, color: Colors.grey.shade500),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _delete(c),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red.shade300),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(c.content ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.5)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── 상담 등록/수정 다이얼로그 ────────────────────────────────────
class _ConsultationDialog extends StatefulWidget {
  final int memberId;
  final ConsultationModel? existing;
  final VoidCallback onSaved;
  const _ConsultationDialog({
    required this.memberId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_ConsultationDialog> createState() => _ConsultationDialogState();
}

class _ConsultationDialogState extends State<_ConsultationDialog> {
  late DateTime _date;
  late TextEditingController _contentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final d = DateTime.tryParse(widget.existing!.consultDate ?? '');
      _date = d ?? DateTime.now();
      _contentCtrl = TextEditingController(text: widget.existing!.content ?? '');
    } else {
      _date = DateTime.now();
      _contentCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      showErrorSnack(context, '상담 내용을 입력하세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'memberId': widget.memberId,
        'consultDate': _fmt(_date),
        'content': content,
      };
      if (widget.existing != null) {
        await context.read<ApiService>()
            .updateConsultation(widget.existing!.consultationId!, body);
      } else {
        await context.read<ApiService>().createConsultation(body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? '상담 수정' : '상담 등록'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상담일 달력 선택
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '상담일',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_fmt(_date),
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '상담 내용',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }
}
