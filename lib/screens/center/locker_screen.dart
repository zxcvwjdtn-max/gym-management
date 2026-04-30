import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// ──────────────────────────────────────────────────────────────
// 라커 관리 화면
// 탭: 사용중 | 곧 만료 | 사용가능(+점검중)
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
  List<LockerModel> _lockers = [];
  bool _loading = true;
  late TabController _tabCtrl;

  static const _tabCount = 2;

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getLockers();
      if (mounted) setState(() { _lockers = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, '라커 조회 실패: $e');
      }
    }
  }

  bool _isExpiringSoon(LockerModel l) {
    if (l.status != 'OCCUPIED' || l.endDate == null) return false;
    final end = DateTime.tryParse(l.endDate!);
    if (end == null) return false;
    return end.difference(DateTime.now()).inDays <= 3;
  }

  List<LockerModel> _listForTab(int index) {
    switch (index) {
      case 0: return _lockers.where((l) => l.groupId != null).toList();  // 그룹 라커
      case 1: return _lockers.where((l) => l.groupId == null).toList();  // 개별 라커
      default: return [];
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddLockerDialog(onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // 헤더
          Row(children: [
            const Text('라커 관리',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('라커 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // 요약 카드
          Row(children: [
            _SummaryCard(label: '전체',     count: _lockers.length, color: Colors.blueGrey),
            const SizedBox(width: 12),
            _SummaryCard(label: '사용중',   count: occupied,        color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            _SummaryCard(label: '만료임박', count: expiring,        color: Colors.orange),
            const SizedBox(width: 12),
            _SummaryCard(label: '사용가능', count: available,       color: Colors.green),
            const SizedBox(width: 12),
            _SummaryCard(label: '점검중',   count: maintenance,     color: Colors.red),
          ]),
          const SizedBox(height: 16),

          // 탭바
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: '그룹 라커 ($groupCount)'),
                Tab(text: '개별 라커 ($indivCount)'),
              ],
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF1565C0),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // 탭 콘텐츠
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
// 탭 콘텐츠: 격자 그룹 + 개별 라커 구분 표시
// ──────────────────────────────────────────────────────────────
class _LockerTabContent extends StatefulWidget {
  final List<LockerModel> lockers;
  final bool canDelete;
  final bool showExpiring;
  final VoidCallback onRefresh;

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
  final Set<int> _selectedIds = {};
  bool _selectMode = false;

  // group_id → lockers
  Map<int, List<LockerModel>> get _groups {
    final Map<int, List<LockerModel>> m = {};
    for (final l in widget.lockers) {
      if (l.groupId != null) {
        m.putIfAbsent(l.groupId!, () => []).add(l);
      }
    }
    return m;
  }

  List<LockerModel> get _individuals =>
      widget.lockers.where((l) => l.groupId == null).toList();

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('선택 삭제'),
        content: Text('선택한 ${_selectedIds.length}개의 라커를 삭제하시겠습니까?'),
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
      await context.read<ApiService>().deleteLockerBulk(_selectedIds.toList());
      setState(() { _selectedIds.clear(); _selectMode = false; });
      widget.onRefresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }

  Future<void> _deleteGroup(int groupId, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('그룹 전체 삭제'),
        content: Text('이 그룹의 라커 $count개를 모두 삭제하시겠습니까?\n(사용 중인 라커도 함께 삭제됩니다)'),
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
      await context.read<ApiService>().deleteLockerGroup(groupId);
      widget.onRefresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lockers.isEmpty) {
      return const Center(
        child: Text('해당하는 라커가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    final groups = _groups;
    final sortedGroupIds = groups.keys.toList()..sort();
    final individuals = _individuals;

    return Column(
      children: [
        // 개별 라커 섹션 액션바 (삭제 허용 탭 + 개별 라커가 있을 때)
        if (widget.canDelete && individuals.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(children: [
              if (_selectMode) ...[
                Text('${_selectedIds.length}개 선택됨',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete, size: 15),
                  label: const Text('선택 삭제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _toggleSelectMode,
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  child: const Text('취소'),
                ),
              ] else ...[
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _toggleSelectMode,
                  icon: const Icon(Icons.checklist, size: 15),
                  label: const Text('선택 삭제'),
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
                    Text('개별 라커 (${individuals.length}개)',
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
// 격자 그룹 헤더
// ──────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final int groupId;
  final List<LockerModel> lockers;
  final bool canDelete;
  final VoidCallback onDeleteGroup;

  const _GroupHeader({
    required this.groupId,
    required this.lockers,
    required this.canDelete,
    required this.onDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
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
          '그룹 $groupId  (${lockers.length}개 · ${cols}열 × ${rows}행)',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0)),
        ),
        const Spacer(),
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
                Text('그룹 전체 삭제',
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
// 격자 그룹 GridView (groupCols 열)
// ──────────────────────────────────────────────────────────────
class _GroupGrid extends StatelessWidget {
  final List<LockerModel> lockers;
  final int cols;
  final bool showExpiring;
  final bool canDelete;
  final VoidCallback onRefresh;

  const _GroupGrid({
    required this.lockers,
    required this.cols,
    required this.showExpiring,
    required this.canDelete,
    required this.onRefresh,
  });

  bool _isExpiring(LockerModel l) {
    if (!showExpiring || l.endDate == null) return false;
    final end = DateTime.tryParse(l.endDate!);
    return end != null && end.difference(DateTime.now()).inDays <= 3;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCols = cols.clamp(1, 20);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveCols,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.9,
      ),
      itemCount: lockers.length,
      itemBuilder: (_, i) => _LockerCard(
        locker: lockers[i],
        isExpiring: _isExpiring(lockers[i]),
        canDelete: canDelete,
        inSelectMode: false,
        isSelected: false,
        onToggleSelect: null,
        onRefresh: onRefresh,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 개별 라커 GridView (12열 고정)
// ──────────────────────────────────────────────────────────────
class _IndividualGrid extends StatelessWidget {
  final List<LockerModel> lockers;
  final bool showExpiring;
  final bool canDelete;
  final bool selectMode;
  final Set<int> selectedIds;
  final void Function(int) onToggleSelect;
  final VoidCallback onRefresh;

  const _IndividualGrid({
    required this.lockers,
    required this.showExpiring,
    required this.canDelete,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onRefresh,
  });

  bool _isExpiring(LockerModel l) {
    if (!showExpiring || l.endDate == null) return false;
    final end = DateTime.tryParse(l.endDate!);
    return end != null && end.difference(DateTime.now()).inDays <= 3;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.9,
      ),
      itemCount: lockers.length,
      itemBuilder: (_, i) {
        final l = lockers[i];
        return _LockerCard(
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

// ──────────────────────────────────────────────────────────────
// 라커 카드 (소형)
// ──────────────────────────────────────────────────────────────
class _LockerCard extends StatelessWidget {
  final LockerModel locker;
  final bool isExpiring;
  final bool canDelete;
  final bool inSelectMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final VoidCallback onRefresh;

  const _LockerCard({
    required this.locker,
    required this.onRefresh,
    this.isExpiring = false,
    this.canDelete = false,
    this.inSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  Color get _color {
    if (isExpiring) return Colors.orange.shade700;
    return switch (locker.status) {
      'AVAILABLE'   => Colors.green.shade600,
      'OCCUPIED'    => const Color(0xFF1565C0),
      'MAINTENANCE' => Colors.red.shade600,
      _             => Colors.grey,
    };
  }

  Color get _bgColor {
    if (isExpiring) return Colors.orange.shade50;
    return switch (locker.status) {
      'AVAILABLE'   => Colors.green.shade50,
      'OCCUPIED'    => const Color(0xFFE3F2FD),
      'MAINTENANCE' => Colors.red.shade50,
      _             => Colors.grey.shade50,
    };
  }

  String get _label {
    if (isExpiring) return '만료임박';
    return switch (locker.status) {
      'AVAILABLE'   => '사용가능',
      'OCCUPIED'    => '사용중',
      'MAINTENANCE' => '점검중',
      _             => locker.status ?? '',
    };
  }

  int? get _remainDays {
    if (locker.endDate == null) return null;
    final end = DateTime.tryParse(locker.endDate!);
    return end?.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final days = _remainDays;
    final isAvailable = locker.status == 'AVAILABLE';
    final isOccupied  = locker.status == 'OCCUPIED';

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: EdgeInsets.zero,
      color: _bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue : _color.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: inSelectMode ? onToggleSelect : () => _showDetail(context),
        child: Stack(
          children: [
            // 카드 본문
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 라커 번호
                    Text(locker.lockerNo ?? '-',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _color)),
                    const SizedBox(height: 3),
                    // 상태 라벨 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _color)),
                    ),
                    // 사용중: 회원 이름
                    if (isOccupied && locker.memberName != null) ...[
                      const SizedBox(height: 3),
                      Text(locker.memberName!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _color),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                    // 만료 D-day
                    if (days != null && isOccupied) ...[
                      const SizedBox(height: 2),
                      Text('D-$days',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: days <= 3 ? Colors.red.shade700 : Colors.grey.shade500)),
                    ],
                    // 삭제 아이콘 (사용가능/점검중만)
                    if (canDelete && !inSelectMode && (isAvailable || locker.status == 'MAINTENANCE'))
                      GestureDetector(
                        onTap: () => _deleteOne(context),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: Colors.red.shade400),
                      ),
                  ],
                ),
              ),
            ),
            // 선택 모드 체크박스 (카드 내부 우상단)
            if (inSelectMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade400,
                        width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _LockerDetailDialog(locker: locker, onAction: onRefresh),
    );
  }

  Future<void> _deleteOne(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('라커 삭제'),
        content: Text('라커 ${locker.lockerNo}번을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<ApiService>().deleteLocker(locker.lockerId!);
      onRefresh();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────
// 요약 카드
// ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text('$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 라커 상세/상태 변경 다이얼로그
// ──────────────────────────────────────────────────────────────
class _LockerDetailDialog extends StatefulWidget {
  final LockerModel locker;
  final VoidCallback onAction;
  const _LockerDetailDialog({required this.locker, required this.onAction});

  @override
  State<_LockerDetailDialog> createState() => _LockerDetailDialogState();
}

class _LockerDetailDialogState extends State<_LockerDetailDialog> {
  bool _saving = false;

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      await context.read<ApiService>()
          .updateLocker(widget.locker.lockerId!, {'status': status});
      widget.onAction();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, '변경 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.locker;

    return AlertDialog(
      title: Text('라커 ${l.lockerNo}번'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('상태', _statusLabel(l.status)),
            if (l.memberName != null) _row('사용 회원', l.memberName!),
            if (l.startDate != null) _row('시작일', l.startDate!),
            if (l.endDate != null)   _row('종료일', l.endDate!),
            if (l.monthlyFee != null && l.monthlyFee! > 0)
              _row('월 요금', '${l.monthlyFee}원'),
            const Divider(height: 24),
            const Text('상태 변경', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (l.status != 'AVAILABLE')
                OutlinedButton(
                  onPressed: _saving ? null : () => _setStatus('AVAILABLE'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
                  child: const Text('사용가능'),
                ),
              if (l.status != 'MAINTENANCE')
                OutlinedButton(
                  onPressed: _saving ? null : () => _setStatus('MAINTENANCE'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('점검중'),
                ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 70,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]),
  );

  String _statusLabel(String? s) => switch (s) {
    'AVAILABLE'   => '사용가능',
    'OCCUPIED'    => '사용중',
    'MAINTENANCE' => '점검중',
    _             => s ?? '',
  };
}

// ──────────────────────────────────────────────────────────────
// 라커 추가 다이얼로그 (단건 / 범위 / 격자)
// ──────────────────────────────────────────────────────────────
enum _AddMode { single, range, grid }

class _AddLockerDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddLockerDialog({required this.onSaved});

  @override
  State<_AddLockerDialog> createState() => _AddLockerDialogState();
}

class _AddLockerDialogState extends State<_AddLockerDialog> {
  _AddMode _mode = _AddMode.single;

  final _noCtrl      = TextEditingController();
  final _fromCtrl    = TextEditingController();
  final _toCtrl      = TextEditingController();
  final _startCtrl   = TextEditingController();
  final _perRowCtrl  = TextEditingController();
  final _rowsCtrl    = TextEditingController();
  final _feeCtrl     = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noCtrl.dispose(); _fromCtrl.dispose(); _toCtrl.dispose();
    _startCtrl.dispose(); _perRowCtrl.dispose(); _rowsCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fee = int.tryParse(_feeCtrl.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      switch (_mode) {
        case _AddMode.single:
          final no = _noCtrl.text.trim();
          if (no.isEmpty) { showErrorSnack(context, '라커 번호를 입력하세요.'); return; }
          await api.createLocker({'lockerNo': no, 'monthlyFee': fee});

        case _AddMode.range:
          final from = int.tryParse(_fromCtrl.text.trim());
          final to   = int.tryParse(_toCtrl.text.trim());
          if (from == null || to == null || from > to) {
            showErrorSnack(context, '번호 범위를 올바르게 입력하세요.');
            return;
          }
          for (int n = from; n <= to; n++) {
            await api.createLocker({'lockerNo': '$n', 'monthlyFee': fee});
          }

        case _AddMode.grid:
          final start  = int.tryParse(_startCtrl.text.trim());
          final perRow = int.tryParse(_perRowCtrl.text.trim());
          final rows   = int.tryParse(_rowsCtrl.text.trim());
          if (start == null || perRow == null || rows == null || perRow <= 0 || rows <= 0) {
            showErrorSnack(context, '격자 설정을 올바르게 입력하세요.');
            return;
          }
          final total = perRow * rows;
          final nos = List.generate(total, (n) => '${start + n}');
          await api.createLockerBatch({
            'lockerNos': nos,
            'monthlyFee': fee,
            'groupCols': perRow,
          });
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, '추가 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildGridPreview() {
    final start  = int.tryParse(_startCtrl.text.trim());
    final perRow = int.tryParse(_perRowCtrl.text.trim());
    final rows   = int.tryParse(_rowsCtrl.text.trim());
    if (start == null || perRow == null || rows == null || perRow <= 0 || rows <= 0) {
      return const SizedBox.shrink();
    }
    final total = perRow * rows;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(children: [
              const Icon(Icons.grid_view, size: 15, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Text('총 $total개   ($start번 ~ ${start + total - 1}번)',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0))),
            ]),
          ),
          SizedBox(
            height: (rows * 38 + 28).toDouble().clamp(60.0, 260.0),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const SizedBox(width: 42),
                      for (int c = 1; c <= perRow; c++)
                        SizedBox(
                          width: 46,
                          child: Center(
                            child: Text('$c번째',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade500)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    for (int r = 0; r < rows; r++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          SizedBox(
                            width: 42,
                            child: Text('${r + 1}열',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ),
                          for (int c = 0; c < perRow; c++)
                            Container(
                              width: 42,
                              height: 30,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: const Color(0xFF1565C0)
                                        .withValues(alpha: 0.35)),
                              ),
                              alignment: Alignment.center,
                              child: Text('${start + r * perRow + c}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1565C0))),
                            ),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('라커 추가'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_AddMode>(
                segments: const [
                  ButtonSegment(value: _AddMode.single, label: Text('단건')),
                  ButtonSegment(value: _AddMode.range,  label: Text('범위')),
                  ButtonSegment(value: _AddMode.grid,   label: Text('격자')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 16),

              if (_mode == _AddMode.single)
                TextField(
                  controller: _noCtrl,
                  decoration: const InputDecoration(
                    labelText: '라커 번호 (예: 1, A-1)',
                    border: OutlineInputBorder(),
                  ),
                ),

              if (_mode == _AddMode.range)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _fromCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '시작 번호', border: OutlineInputBorder()),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('~', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _toCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: '끝 번호', border: OutlineInputBorder()),
                    ),
                  ),
                ]),

              if (_mode == _AddMode.grid) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _startCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: '시작 번호', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _perRowCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: '열당 개수', border: OutlineInputBorder()),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('×', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _rowsCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: '열 수', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                _buildGridPreview(),
              ],

              const SizedBox(height: 12),
              TextField(
                controller: _feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '월 요금 (선택사항)',
                  border: OutlineInputBorder(),
                  suffixText: '원',
                ),
              ),
            ],
          ),
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
              : const Text('추가'),
        ),
      ],
    );
  }
}
