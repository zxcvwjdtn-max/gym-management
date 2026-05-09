// 라커 관리 화면 — LockerScreen(탭 화면), _LockerTabContent(탭 콘텐츠), _GroupHeader, _GroupGrid, _IndividualGrid
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import 'locker_card.dart';
import 'locker_dialogs.dart';

// ──────────────────────────────────────────────────────────────
// 라커 관리 화면
// 탭: 그룹 라커 | 개별 라커
// 격자 생성 라커 → group_id로 묶어서 원래 열수대로 표시
// 개별 생성 라커 → 별도 섹션에 표시
// ──────────────────────────────────────────────────────────────
class LockerScreen extends StatefulWidget {
  const LockerScreen({super.key});

  @override
  State<LockerScreen> createState() => _LockerScreenState();
}

class _LockerScreenState extends State<LockerScreen>
    with SingleTickerProviderStateMixin {
  List<LockerModel> _lockers = []; // 전체 라커 목록
  bool _loading = true;            // 데이터 로딩 상태
  late TabController _tabCtrl;     // 탭 컨트롤러

  static const _tabCount = 2; // 탭 개수 (그룹/개별)

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabCount, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// 라커 목록 API 로드
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getLockers();
      if (mounted) setState(() { _lockers = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, context.read<LocaleProvider>().t('center.locker.loadFail', params: {'e': '$e'}));
      }
    }
  }

  /// 종료일이 3일 이내인 사용중 라커 판별
  bool _isExpiringSoon(LockerModel l) {
    if (l.status != 'OCCUPIED' || l.endDate == null) return false;
    final end = DateTime.tryParse(l.endDate!);
    if (end == null) return false;
    return end.difference(DateTime.now()).inDays <= 3;
  }

  /// 탭 인덱스에 따라 라커 목록 필터링 (0: 그룹, 1: 개별)
  List<LockerModel> _listForTab(int index) {
    switch (index) {
      case 0: return _lockers.where((l) => l.groupId != null).toList();  // 그룹 라커
      case 1: return _lockers.where((l) => l.groupId == null).toList();  // 개별 라커
      default: return [];
    }
  }

  /// 라커 추가 다이얼로그 표시
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddLockerDialog(onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();

    // 상단 요약 통계 계산
    final available   = _lockers.where((l) => l.status == 'AVAILABLE').length;
    final occupied    = _lockers.where((l) => l.status == 'OCCUPIED').length;
    final expiring    = _lockers.where(_isExpiringSoon).length;
    final maintenance = _lockers.where((l) => l.status == 'MAINTENANCE').length;
    final groupCount  = _lockers.where((l) => l.groupId != null).length;
    final indivCount  = _lockers.where((l) => l.groupId == null).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 제목 + 라커 추가 버튼
          Row(children: [
            Text(loc.t('center.locker.title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('center.locker.add')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // 요약 카드 행
          Row(children: [
            LockerSummaryCard(label: loc.t('center.locker.status.all'),         count: _lockers.length, color: Colors.blueGrey),
            const SizedBox(width: 12),
            LockerSummaryCard(label: loc.t('center.locker.status.occupied'),    count: occupied,        color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            LockerSummaryCard(label: loc.t('center.locker.status.expiring'),    count: expiring,        color: Colors.orange),
            const SizedBox(width: 12),
            LockerSummaryCard(label: loc.t('center.locker.status.available'),   count: available,       color: Colors.green),
            const SizedBox(width: 12),
            LockerSummaryCard(label: loc.t('center.locker.status.maintenance'), count: maintenance,     color: Colors.red),
          ]),
          const SizedBox(height: 16),

          // 탭바: 그룹 라커 / 개별 라커
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: loc.t('center.locker.tab.group', params: {'n': '$groupCount'})),
                Tab(text: loc.t('center.locker.tab.individual', params: {'n': '$indivCount'})),
              ],
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF1565C0),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // 탭 콘텐츠 (로딩 중이면 인디케이터 표시)
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: List.generate(_tabCount, (i) => _LockerTabContent(
                      key: ValueKey(i),
                      lockers: _listForTab(i),
                      canDelete: true,   // 두 탭 모두 삭제 허용 (AVAILABLE/MAINTENANCE만)
                      showExpiring: true,
                      onRefresh: _load,
                    )),
                  ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 탭 콘텐츠: 격자 그룹 섹션과 개별 라커 섹션을 함께 표시
// ──────────────────────────────────────────────────────────────
class _LockerTabContent extends StatefulWidget {
  final List<LockerModel> lockers;  // 이 탭에 표시할 라커 목록
  final bool canDelete;             // 삭제 기능 활성화 여부
  final bool showExpiring;          // 만료임박 배지 표시 여부
  final VoidCallback onRefresh;     // 목록 새로고침 콜백

  const _LockerTabContent({
    super.key,
    required this.lockers,
    required this.canDelete,
    required this.showExpiring,
    required this.onRefresh,
  });

  @override
  State<_LockerTabContent> createState() => _LockerTabContentState();
}

class _LockerTabContentState extends State<_LockerTabContent> {
  final Set<int> _selectedIds = {}; // 다중 선택된 라커 ID 집합
  bool _selectMode = false;         // 다중 선택 모드 활성화 여부

  /// group_id → 라커 목록 맵 반환
  Map<int, List<LockerModel>> get _groups {
    final Map<int, List<LockerModel>> m = {};
    for (final l in widget.lockers) {
      if (l.groupId != null) {
        m.putIfAbsent(l.groupId!, () => []).add(l);
      }
    }
    return m;
  }

  /// groupId가 없는 개별 라커 목록 반환
  List<LockerModel> get _individuals =>
      widget.lockers.where((l) => l.groupId == null).toList();

  /// 개별 라커 선택 토글
  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// 선택 모드 진입/해제 및 선택 초기화
  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  /// 선택된 라커 일괄 삭제
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final loc = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('center.locker.deleteSelected')),
        content: Text(loc.t('center.locker.deleteSelectedConfirm', params: {'n': '${_selectedIds.length}'})),
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
      await context.read<ApiService>().deleteLockerBulk(_selectedIds.toList());
      setState(() { _selectedIds.clear(); _selectMode = false; });
      widget.onRefresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, context.read<LocaleProvider>().t('center.locker.deleteFail', params: {'e': '$e'}));
    }
  }

  /// 그룹 전체 삭제 (사용 중인 라커 포함)
  Future<void> _deleteGroup(int groupId, int count) async {
    final loc = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('center.locker.deleteGroup')),
        content: Text(loc.t('center.locker.deleteGroupConfirm', params: {'n': '$count'})),
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
      await context.read<ApiService>().deleteLockerGroup(groupId);
      widget.onRefresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, context.read<LocaleProvider>().t('center.locker.deleteFail', params: {'e': '$e'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();

    // 라커가 없으면 안내 메시지 표시
    if (widget.lockers.isEmpty) {
      return Center(
        child: Text(loc.t('center.locker.empty'), style: const TextStyle(color: Colors.grey)),
      );
    }

    final groups = _groups;
    final sortedGroupIds = groups.keys.toList()..sort(); // 그룹 ID 오름차순 정렬
    final individuals = _individuals;

    return Column(
      children: [
        // 개별 라커 섹션 액션바 (삭제 허용 탭 + 개별 라커가 있을 때)
        if (widget.canDelete && individuals.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(children: [
              if (_selectMode) ...[
                // 선택 모드: 선택 수 표시 + 삭제·취소 버튼
                Text(loc.t('center.locker.selectedCount', params: {'n': '${_selectedIds.length}'}),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete, size: 15),
                  label: Text(loc.t('center.locker.deleteSelected')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _toggleSelectMode,
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(loc.t('common.cancel')),
                ),
              ] else ...[
                // 일반 모드: 선택 삭제 진입 버튼
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _toggleSelectMode,
                  icon: const Icon(Icons.checklist, size: 15),
                  label: Text(loc.t('center.locker.deleteSelected')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ]),
          ),

        // 스크롤 가능한 본문
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              // ── 격자 그룹 섹션들 ──
              for (final gid in sortedGroupIds) ...[
                _GroupHeader(
                  groupId: gid,
                  lockers: groups[gid]!,
                  canDelete: widget.canDelete,
                  onDeleteGroup: () => _deleteGroup(gid, groups[gid]!.length),
                ),
                _GroupGrid(
                  lockers: groups[gid]!,
                  cols: groups[gid]!.first.groupCols ?? 6,
                  showExpiring: widget.showExpiring,
                  canDelete: widget.canDelete,
                  onRefresh: widget.onRefresh,
                ),
                const SizedBox(height: 16),
              ],

              // ── 개별 라커 섹션 ──
              if (individuals.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, size: 15, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Text(loc.t('center.locker.indivHeader', params: {'n': '${individuals.length}'}),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey)),
                  ]),
                ),
                _IndividualGrid(
                  lockers: individuals,
                  showExpiring: widget.showExpiring,
                  canDelete: widget.canDelete,
                  selectMode: _selectMode,
                  selectedIds: _selectedIds,
                  onToggleSelect: _toggleSelect,
                  onRefresh: widget.onRefresh,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 격자 그룹 헤더 — 그룹 ID, 총 개수, 열×행 정보 및 그룹 삭제 버튼
// ──────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final int groupId;              // 표시할 그룹 ID
  final List<LockerModel> lockers; // 해당 그룹의 라커 목록
  final bool canDelete;           // 삭제 버튼 노출 여부
  final VoidCallback onDeleteGroup; // 그룹 전체 삭제 콜백

  const _GroupHeader({
    required this.groupId,
    required this.lockers,
    required this.canDelete,
    required this.onDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final cols = lockers.first.groupCols ?? 0;
    final rows = cols > 0 ? (lockers.length / cols).ceil() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.grid_view, size: 15, color: Color(0xFF1565C0)),
        const SizedBox(width: 6),
        Text(
          loc.t('center.locker.groupHeader', params: {
            'id': '$groupId',
            'n': '${lockers.length}',
            'cols': '$cols',
            'rows': '$rows',
          }),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0)),
        ),
        const Spacer(),
        // 삭제 허용 시 그룹 전체 삭제 버튼 표시
        if (canDelete)
          InkWell(
            onTap: onDeleteGroup,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.delete_sweep, size: 14, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text(loc.t('center.locker.deleteGroup'),
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 격자 그룹 GridView — groupCols 값에 따라 열 수를 동적 설정
// ──────────────────────────────────────────────────────────────
class _GroupGrid extends StatelessWidget {
  final List<LockerModel> lockers; // 그룹 내 라커 목록
  final int cols;                  // 격자 열 수
  final bool showExpiring;         // 만료임박 배지 표시 여부
  final bool canDelete;            // 삭제 허용 여부
  final VoidCallback onRefresh;    // 목록 새로고침 콜백

  const _GroupGrid({
    required this.lockers,
    required this.cols,
    required this.showExpiring,
    required this.canDelete,
    required this.onRefresh,
  });

  /// 해당 라커가 만료임박인지 확인
  bool _isExpiring(LockerModel l) {
    if (!showExpiring || l.endDate == null) return false;
    final end = DateTime.tryParse(l.endDate!);
    return end != null && end.difference(DateTime.now()).inDays <= 3;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCols = cols.clamp(1, 20); // 유효 열 수 범위 제한
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // 부모 스크롤 위임
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveCols,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.9,
      ),
      itemCount: lockers.length,
      itemBuilder: (_, i) => LockerCard(
        locker: lockers[i],
        isExpiring: _isExpiring(lockers[i]),
        canDelete: canDelete,
        inSelectMode: false,   // 그룹 라커는 선택 모드 미지원
        isSelected: false,
        onToggleSelect: null,
        onRefresh: onRefresh,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 개별 라커 GridView — 10열 고정, 다중 선택 모드 지원
// ──────────────────────────────────────────────────────────────
class _IndividualGrid extends StatelessWidget {
  final List<LockerModel> lockers;     // 개별 라커 목록
  final bool showExpiring;             // 만료임박 배지 표시 여부
  final bool canDelete;                // 삭제 허용 여부
  final bool selectMode;               // 다중 선택 모드 활성화 여부
  final Set<int> selectedIds;          // 현재 선택된 라커 ID 집합
  final void Function(int) onToggleSelect; // 선택 토글 콜백
  final VoidCallback onRefresh;        // 목록 새로고침 콜백

  const _IndividualGrid({
    required this.lockers,
    required this.showExpiring,
    required this.canDelete,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onRefresh,
  });

  /// 해당 라커가 만료임박인지 확인
  bool _isExpiring(LockerModel l) {
    if (!showExpiring || l.endDate == null) return false;
    final end = DateTime.tryParse(l.endDate!);
    return end != null && end.difference(DateTime.now()).inDays <= 3;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // 부모 스크롤 위임
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10, // 개별 라커는 10열 고정
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.9,
      ),
      itemCount: lockers.length,
      itemBuilder: (_, i) {
        final l = lockers[i];
        return LockerCard(
          locker: l,
          isExpiring: _isExpiring(l),
          canDelete: canDelete,
          inSelectMode: selectMode,
          isSelected: selectedIds.contains(l.lockerId),
          onToggleSelect: l.lockerId != null ? () => onToggleSelect(l.lockerId!) : null,
          onRefresh: onRefresh,
        );
      },
    );
  }
}
