import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/main_layout.dart';
import '../members/member_list_screen.dart';
import '../members/member_group_screen.dart';
import '../members/expiring_today_screen.dart';
import '../members/inactive_members_screen.dart';
import '../members/suspended_members_screen.dart';
import '../members/birthday_members_screen.dart';
import '../attendance/attendance_check_screen.dart';
import '../attendance/attendance_status_screen.dart';
import '../attendance/hourly_attendance_screen.dart';
import '../notifications/send_notification_screen.dart';
import '../notifications/auto_notification_screen.dart';
import '../notifications/notification_template_screen.dart';
import '../notifications/notification_log_screen.dart';
import '../accounting/daily_sales_screen.dart';
import '../accounting/monthly_sales_screen.dart';
import '../accounting/yearly_sales_screen.dart';
import '../accounting/unpaid_screen.dart';
import '../accounting/monthly_settlement_screen.dart';
import '../statistics/visit_stats_screen.dart';
import '../statistics/sales_stats_screen.dart';
import '../center/staff_screen.dart';
import '../pt/pt_contract_screen.dart';
import '../pt/pt_session_screen.dart';
import '../pt/pt_schedule_screen.dart';
import '../center/ticket_screen.dart';
import '../center/bulk_extend_screen.dart';
import '../center/program_screen.dart';
import '../center/center_accounting_screen.dart';
import '../center/settings_screen.dart';
import '../center/excel_upload_screen.dart';
import '../center/locker_screen.dart';
import '../center/group_def_screen.dart';
import '../community/notice_screen.dart';
import '../community/message_screen.dart';
import '../community/workout_screen.dart';
import '../superadmin/gym_ad_screen.dart';
import '../superadmin/super_ticket_screen.dart';
import '../superadmin/super_gym_screen.dart';
import '../contract/contract_template_screen.dart';
import '../contract/contract_waiting_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  String _route = 'dashboard';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthProvider>();
    if (auth.gymId != null) {
      context.read<AttendanceProvider>().init(auth.gymId!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱이 백그라운드에서 복귀할 때도 토큰 체크
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().checkExpiredAndLogout();
    }
  }

  Future<void> _navigate(String route) async {
    final expired = await context.read<AuthProvider>().checkExpiredAndLogout();
    if (expired || !mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _route = route);
  }

  // 현재 라우트에 맞는 화면 위젯 반환
  Widget _buildContent() {
    switch (_route) {
      case 'dashboard': return const _DashboardHome();
      case 'member_list': return const MemberListScreen();
      case 'member_group': return const MemberGroupScreen();
      case 'expiring_today': return const ExpiringTodayScreen();
      case 'inactive': return const InactiveMembersScreen();
      case 'suspended': return const SuspendedMembersScreen();
      case 'birthdays': return const BirthdayMembersScreen();
      case 'attendance_check': return const AttendanceCheckScreen();
      case 'attendance_status': return const AttendanceStatusScreen();
      case 'hourly_attendance': return const HourlyAttendanceScreen();
      case 'notification_send': return const SendNotificationScreen();
      case 'notification_auto': return const AutoNotificationScreen();
      case 'notification_template': return const NotificationTemplateScreen();
      case 'notification_log': return const NotificationLogScreen();
      case 'daily_sales': return const DailySalesScreen();
      case 'monthly_sales': return const MonthlySalesScreen();
      case 'yearly_sales': return const YearlySalesScreen();
      case 'unpaid': return const UnpaidScreen();
      case 'monthly_settlement': return const MonthlySettlementScreen();
      case 'visit_stats': return const VisitStatsScreen();
      case 'sales_stats': return const SalesStatsScreen();
      case 'pt_contracts': return const PtContractScreen();
      case 'pt_sessions': return const PtSessionScreen();
      case 'pt_schedule': return const PtScheduleScreen();
      case 'staff': return const StaffScreen();
      case 'ticket': return const TicketScreen();
      case 'bulk_extend': return const BulkExtendScreen();
      case 'pt_program': return const ProgramScreen();
      case 'center_accounting': return const CenterAccountingScreen();
      case 'locker': return const LockerScreen();
      case 'group_def': return const GroupDefScreen();
      case 'notice': return const NoticeScreen();
      case 'message': return const MessageScreen();
      case 'workout': return const WorkoutScreen();
      case 'settings': return const SettingsScreen();
      case 'excel_upload': return const ExcelUploadScreen();
      case 'super_ticket': return const SuperTicketScreen();
      case 'super_gym_ad': return const GymAdScreen();
      case 'super_gym': return const SuperGymScreen();
      case 'contract_template': return const ContractTemplateScreen();
      case 'contract_waiting': return const ContractWaitingScreen();
      default: return const _DashboardHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      selectedRoute: _route,
      onNavigate: _navigate,
      child: _buildContent(),
    );
  }
}

// ========================= Dashboard Home =========================
class _DashboardHome extends StatefulWidget {
  const _DashboardHome();
  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  GymDashboardModel? _dashboard;
  List<AttendanceModel> _todayAttendance = [];
  AttendanceModel? _selected;
  bool _loading = true;

  // 커뮤니티 데이터
  List<CommunityPostModel> _notices = [];
  List<CommunityPostModel> _messages = [];
  WorkoutModel? _latestWorkout;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AttendanceProvider>().addListener(_onNewAttendance);
    });
  }

  @override
  void dispose() {
    try { context.read<AttendanceProvider>().removeListener(_onNewAttendance); } catch (_) {}
    super.dispose();
  }

  void _onNewAttendance() {
    final latest = context.read<AttendanceProvider>().latestAttendance;
    if (latest == null || !mounted) return;
    setState(() {
      _todayAttendance.removeWhere((a) => a.attendanceId == latest.attendanceId);
      _todayAttendance.insert(0, latest);
    });
  }

  // 대시보드 통계 및 오늘 출석 데이터 로드
  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getDashboard(),
        api.getTodayAttendance(),
        api.getCommunityPosts('NOTICE', limit: 5),
        api.getCommunityPosts('MESSAGE', limit: 5),
        api.getLatestWorkout(),
      ]);
      if (mounted) {
        setState(() {
          _dashboard = results[0] as GymDashboardModel;
          _todayAttendance = results[1] as List<AttendanceModel>;
          _notices = results[2] as List<CommunityPostModel>;
          _messages = results[3] as List<CommunityPostModel>;
          _latestWorkout = results[4] as WorkoutModel?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final latestAttendance = context.watch<AttendanceProvider>().latestAttendance;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 좌측: 헤더 + 최근 출석 + 통계 카드 + 커뮤니티 + 선택 회원 (스크롤)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  if (latestAttendance != null) ...[
                    const SizedBox(height: 16),
                    _buildLatestAttendanceCard(latestAttendance),
                  ],
                  const SizedBox(height: 24),
                  _buildStatCards(),
                  const SizedBox(height: 20),
                  _buildCommunityRow(),
                  if (_selected != null) ...[
                    const SizedBox(height: 20),
                    _buildSelectedMemberCard(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // 우측: 오늘 출석 현황 (세로, 화면 높이 채움)
          SizedBox(
            width: 340,
            child: _buildTodayAttendance(),
          ),
        ],
      ),
    );
  }

  // 체육관명·날짜 헤더 및 새로고침 버튼 빌드
  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    final loc = context.watch<LocaleProvider>();
    final now = DateTime.now();
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dashboard?.gymName ?? auth.adminName ?? 'Gym',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              _fmtDate(loc, now),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(loc.t('common.refresh')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // 통계 카드 (출석·유효회원·만료임박) 빌드
  Widget _buildStatCards() {
    final loc = context.watch<LocaleProvider>();
    final d = _dashboard;
    final suffix = loc.t('common.person');
    final todayCount = _todayAttendance.isNotEmpty
        ? _todayAttendance.length
        : (d?.todayAttendance ?? 0);
    return Row(
      children: [
        Expanded(child: _StatCard(
          label: loc.t('dashboard.todayAttendance'),
          value: '$todayCount$suffix',
          icon: Icons.how_to_reg, color: Colors.blue,
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(
          label: loc.t('dashboard.activeMembers'),
          value: '${d?.activeMembers ?? 0}$suffix',
          icon: Icons.people, color: Colors.green,
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(
          label: loc.t('dashboard.expiringSoon'),
          value: '${d?.expiringSoon ?? 0}$suffix',
          icon: Icons.event_busy, color: Colors.orange,
        )),
      ],
    );
  }

  // 커뮤니티 요약 패널 (공지사항 | 전달사항 | 오늘의 운동)
  Widget _buildCommunityRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _CommunityCard(
          icon: Icons.campaign,
          iconColor: const Color(0xFF1565C0),
          title: '공지사항',
          items: _notices,
          emptyText: '등록된 공지사항이 없습니다.',
          onTapItem: (p) => showDialog(context: context,
              builder: (_) => PostDetailDialog(post: p, title: '공지사항')),
        )),
        const SizedBox(width: 12),
        Expanded(child: _CommunityCard(
          icon: Icons.message,
          iconColor: const Color(0xFF2E7D32),
          title: '전달사항',
          items: _messages,
          emptyText: '등록된 전달사항이 없습니다.',
          onTapItem: (p) => showDialog(context: context,
              builder: (_) => PostDetailDialog(post: p, title: '전달사항')),
        )),
        const SizedBox(width: 12),
        SizedBox(
          width: 260,
          child: _WorkoutCard(workout: _latestWorkout),
        ),
      ],
    );
  }

  // 최근 출석 회원 하이라이트 카드 (WebSocket 실시간)
  Widget _buildLatestAttendanceCard(AttendanceModel a) {
    final hasPhoto = a.photoUrl != null && a.photoUrl!.isNotEmpty;
    final remain = a.remainDays;
    final isExpiring = remain != null && remain <= 7;
    final isExpired = remain != null && remain < 0;
    Color remainColor = Colors.white70;
    if (isExpired) remainColor = Colors.red.shade200;
    else if (isExpiring) remainColor = Colors.orange.shade200;

    final hasCloth = a.clothRentalYn == 'Y';
    final hasLocker = a.lockerRentalYn == 'Y';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 사진
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white24,
                backgroundImage: hasPhoto ? NetworkImage(a.photoUrl!) : null,
                child: hasPhoto ? null
                    : Text(a.memberName.isNotEmpty ? a.memberName[0] : '?',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Positioned(
                bottom: 2, right: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 배지 + 시간 + 회원번호
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(children: [
                      Icon(Icons.how_to_reg, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('최근 출석', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Text(_formatTime(a.attendanceTime),
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const Spacer(),
                  Text('No.${a.memberNo}',
                      style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                // 이름
                Text(a.memberName,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                // 이용권 + 잔여일
                Row(children: [
                  const Icon(Icons.card_membership, color: Colors.white60, size: 15),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(a.ticketName ?? '-',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (remain != null) ...[
                    const SizedBox(width: 14),
                    const Icon(Icons.calendar_today, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      isExpired ? '만료됨' : '${remain}일 남음',
                      style: TextStyle(color: remainColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                // 옷 대여 / 락카 대여 뱃지
                Row(children: [
                  _RentalBadge(
                    icon: Icons.checkroom,
                    label: '옷 대여',
                    active: hasCloth,
                  ),
                  const SizedBox(width: 8),
                  _RentalBadge(
                    icon: Icons.lock_outline,
                    label: '락카 대여',
                    active: hasLocker,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 선택한 회원 출석 상세 카드
  Widget _buildSelectedMemberCard() {
    final loc = context.watch<LocaleProvider>();
    final a = _selected!;
    final hasPhoto = a.photoUrl != null && a.photoUrl!.isNotEmpty;
    final isExpiring = a.remainDays != null && a.remainDays! <= 7 && a.remainDays! >= 0;
    final isExpired  = a.remainDays != null && a.remainDays! < 0;
    final hasCloth  = a.clothRentalYn == 'Y';
    final hasLocker = a.lockerRentalYn == 'Y';

    String fmtTime(DateTime? dt) {
      if (dt == null) return '--:--';
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: hasPhoto ? NetworkImage(a.photoUrl!) : null,
              child: hasPhoto ? null
                  : Text(a.memberName.isNotEmpty ? a.memberName[0] : '?',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0))),
            ),
            const SizedBox(width: 20),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 + 회원번호
                  Row(children: [
                    Text(a.memberName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('No.${a.memberNo}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ]),
                  const SizedBox(height: 10),
                  // 정보 행들
                  Wrap(
                    spacing: 20,
                    runSpacing: 6,
                    children: [
                      _infoChip(Icons.card_membership, a.ticketName ?? '-', const Color(0xFF1565C0)),
                      _infoChip(Icons.access_time, '출석 ${fmtTime(a.attendanceTime)}', Colors.black87),
                      if (a.remainDays != null)
                        _infoChip(
                          Icons.timelapse,
                          isExpired ? '만료됨' : '${a.remainDays}일 남음',
                          isExpired ? Colors.red : isExpiring ? Colors.orange : Colors.grey.shade700,
                        ),
                      if (a.remainCount != null)
                        _infoChip(Icons.tag, '잔여 ${a.remainCount}회', Colors.purple.shade700),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 대여 뱃지
                  Row(children: [
                    _rentalTag(Icons.checkroom,   '옷 대여',   hasCloth),
                    const SizedBox(width: 8),
                    _rentalTag(Icons.lock_outline, '락카 대여', hasLocker),
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => setState(() => _selected = null),
              tooltip: loc.t('common.close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _rentalTag(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1565C0).withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFF1565C0).withOpacity(0.35) : Colors.grey.shade300,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: active ? const Color(0xFF1565C0) : Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF1565C0) : Colors.grey.shade400,
        )),
        const SizedBox(width: 4),
        Icon(active ? Icons.check_circle : Icons.cancel_outlined,
            size: 12, color: active ? Colors.green : Colors.grey.shade300),
      ]),
    );
  }

  // 오늘 출석 현황 목록 빌드 (우측 세로 카드, 부모 높이 채움)
  Widget _buildTodayAttendance() {
    final loc = context.watch<LocaleProvider>();
    final personSuffix = loc.t('common.person');
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(loc.t('dashboard.todayAttendanceList'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_todayAttendance.length}$personSuffix',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: _todayAttendance.isEmpty
                  ? Center(
                      child: Text(loc.t('dashboard.noAttendance'),
                        style: const TextStyle(color: Colors.grey)),
                    )
                  : ListView.separated(
                      itemCount: _todayAttendance.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final a = _todayAttendance[index];
                        final isSelected = _selected?.attendanceId == a.attendanceId;
                        final endDate = a.membershipEndDate;
                        final remain = a.remainDays;
                        final isExpiring = remain != null && remain <= 7;
                        final isExpired = remain != null && remain < 0;
                        return Material(
                          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selected = a),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue.shade50,
                                    backgroundImage: a.photoUrl != null
                                        ? NetworkImage(a.photoUrl!) : null,
                                    child: a.photoUrl == null
                                        ? Text(a.memberName.isNotEmpty ? a.memberName[0] : '?',
                                            style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.memberName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          overflow: TextOverflow.ellipsis),
                                        Text('${a.memberNo} | ${a.ticketName ?? ''}',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis),
                                        if (endDate != null)
                                          Text(
                                            '${loc.t('dashboard.expires')}: $endDate${remain != null ? ' (${isExpired ? loc.t('dashboard.expired') : '$remain${loc.t('common.days')}'})' : ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isExpired ? Colors.red
                                                  : isExpiring ? Colors.orange
                                                  : Colors.grey.shade600,
                                              fontWeight: isExpiring || isExpired
                                                  ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatTime(a.attendanceTime),
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
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

  // 로케일 기반 날짜 문자열
  String _fmtDate(LocaleProvider loc, DateTime now) {
    const wkKeys = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final w = loc.t('dashboard.weekday.${wkKeys[now.weekday]}');
    return loc.t('dashboard.dateFmt', params: {
      'y': now.year.toString(),
      'm': now.month.toString(),
      'd': now.day.toString(),
      'w': w,
    });
  }

  // DateTime을 HH:mm 형식 문자열로 변환
  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _RentalBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _RentalBadge({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.15),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14,
            color: active ? Colors.white : Colors.white38),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.white38,
            )),
        const SizedBox(width: 4),
        Icon(
          active ? Icons.check_circle : Icons.cancel,
          size: 13,
          color: active ? const Color(0xFF69F0AE) : Colors.white24,
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Text(value, style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공지사항/전달사항 요약 카드 ────────────────────────────────────
class _CommunityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<CommunityPostModel> items;
  final String emptyText;
  final void Function(CommunityPostModel) onTapItem;

  const _CommunityCard({
    required this.icon, required this.iconColor, required this.title,
    required this.items, required this.emptyText, required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: iconColor)),
              const Spacer(),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${items.length}건',
                      style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text(emptyText,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
              )
            else
              ...items.map((p) => _PostRow(post: p, color: iconColor, onTap: () => onTapItem(p))),
          ],
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  final CommunityPostModel post;
  final Color color;
  final VoidCallback onTap;
  const _PostRow({required this.post, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPinned = post.isPinned == 'Y';
    final date = post.createdAt != null && post.createdAt!.length >= 10
        ? post.createdAt!.substring(5, 10) : ''; // MM-DD
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 11, color: Colors.red.shade400),
            ),
          Expanded(
            child: Text(post.title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isPinned ? FontWeight.w600 : FontWeight.normal),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }
}

// ── 오늘의 운동 요약 카드 ─────────────────────────────────────────
class _WorkoutCard extends StatelessWidget {
  final WorkoutModel? workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.fitness_center, color: Color(0xFF6A1B9A), size: 18),
              const SizedBox(width: 6),
              const Text('오늘의 운동',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: Color(0xFF6A1B9A))),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (workout == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('등록된 운동이 없습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
              )
            else
              InkWell(
                onTap: () => showDialog(context: context,
                    builder: (_) => WorkoutDetailDialog(workout: workout!)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout!.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: Color(0xFF6A1B9A)),
                          overflow: TextOverflow.ellipsis),
                      if (workout!.content != null && workout!.content!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(workout!.content!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            maxLines: 4, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.touch_app, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text('눌러서 전체 보기',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
