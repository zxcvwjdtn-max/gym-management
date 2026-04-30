import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/member_table_group.dart';

class MemberGroupScreen extends StatefulWidget {
  const MemberGroupScreen({super.key});
  @override
  State<MemberGroupScreen> createState() => _MemberGroupScreenState();
}

class _MemberGroupScreenState extends State<MemberGroupScreen> {
  List<MemberModel> _all = [];
  List<MemberGroupDefModel> _groupDefs = [];
  bool _loading = true;

  // null = 전체 보기
  int? _filterGroupDefId;

  final Set<int> _selected = {}; // memberId

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _selected.clear(); });
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getMembers(),
        api.getMemberGroupDefs(),
      ]);
      if (mounted) {
        setState(() {
          _all = results[0] as List<MemberModel>;
          _groupDefs = results[1] as List<MemberGroupDefModel>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MemberModel> get _filtered {
    if (_filterGroupDefId == null) return _all;
    return _all.where((m) => m.groupDefIds.contains(_filterGroupDefId)).toList();
  }

  int _count(int? groupDefId) {
    if (groupDefId == null) return _all.length;
    return _all.where((m) => m.groupDefIds.contains(groupDefId)).length;
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.blue; }
  }

  Future<void> _changeGroups() async {
    if (_selected.isEmpty) return;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _ChangeGroupsDialog(groupDefs: _groupDefs),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<ApiService>()
          .bulkUpdateMemberGroups(_selected.toList(), result);
      if (mounted) {
        final groupNames = result.isEmpty
            ? '없음'
            : _groupDefs
                .where((g) => result.contains(g.groupDefId))
                .map((g) => g.groupName)
                .join(', ');
        showSuccessSnack(context,
            '${_selected.length}명의 구분을 [$groupNames](으)로 변경했습니다.');
        _load();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '그룹 변경 실패: $e');
    }
  }

  // 색상 맵 (groupDefId → Color) 빌드
  Map<int, Color> get _colorMap => {
    for (final g in _groupDefs)
      if (g.groupDefId != null) g.groupDefId!: _parseColor(g.groupColor),
  };

  // 이름 맵 (groupDefId → name) 빌드
  Map<int, String> get _nameMap => {
    for (final g in _groupDefs)
      if (g.groupDefId != null) g.groupDefId!: g.groupName,
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──────────────────────────────────────────
          Row(children: [
            const Icon(Icons.group, color: Color(0xFF1565C0), size: 26),
            const SizedBox(width: 10),
            const Text('회원 그룹 관리',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            if (!_loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('전체 ${_all.length}명',
                    style: const TextStyle(
                        color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            if (_selected.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text('${_selected.length}명 선택됨',
                    style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _changeGroups,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('구분 변경'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => _selected.clear()),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600),
                child: const Text('선택 해제'),
              ),
              const SizedBox(width: 12),
            ],
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // ── 그룹 필터 칩 ───────────────────────────────────
          if (_loading)
            const SizedBox()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip(null, '전체', _count(null), Colors.blueGrey),
                const SizedBox(width: 8),
                for (final g in _groupDefs) ...[
                  if (g.groupDefId != null) ...[
                    _filterChip(g.groupDefId, g.groupName, _count(g.groupDefId),
                        _parseColor(g.groupColor)),
                    const SizedBox(width: 8),
                  ],
                ],
              ]),
            ),
          const SizedBox(height: 12),

          // ── 고객 구분이 없는 경우 안내 ──────────────────────
          if (!_loading && _groupDefs.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '고객 구분이 없습니다. 센터 관리 > 고객 구분 관리에서 구분을 먼저 등록해 주세요.',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
                  ),
                ),
              ]),
            ),

          // ── 테이블 ─────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            const Expanded(child: Center(
              child: Text('해당 구분에 회원이 없습니다.',
                  style: TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: MemberGroupTable(
                members: filtered,
                selected: _selected,
                onSelectionChanged: (id, v) => setState(() {
                  if (v) { _selected.add(id); } else { _selected.remove(id); }
                }),
                onSelectAll: (v) => setState(() {
                  if (v) {
                    _selected.addAll(
                        filtered.map((m) => m.memberId!).whereType<int>());
                  } else {
                    _selected.removeAll(
                        filtered.map((m) => m.memberId!).whereType<int>());
                  }
                }),
                onRefresh: _load,
                groupDefs: _groupDefs,
                colorMap: _colorMap,
                nameMap: _nameMap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(int? groupDefId, String label, int count, Color color) {
    final sel = _filterGroupDefId == groupDefId;
    return GestureDetector(
      onTap: () => setState(() {
        _filterGroupDefId = groupDefId;
        _selected.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color : Colors.grey.shade300,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? color : Colors.black87,
                fontSize: 13,
              )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: sel ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                  fontSize: 11,
                  color: sel ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ]),
      ),
    );
  }
}

// ─── 구분 변경 다이얼로그 (멀티-선택) ─────────────────────────────
class _ChangeGroupsDialog extends StatefulWidget {
  final List<MemberGroupDefModel> groupDefs;
  const _ChangeGroupsDialog({required this.groupDefs});

  @override
  State<_ChangeGroupsDialog> createState() => _ChangeGroupsDialogState();
}

class _ChangeGroupsDialogState extends State<_ChangeGroupsDialog> {
  final Set<int> _selected = {};

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.blue; }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('고객 구분 변경'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택한 회원들의 구분을 일괄 교체합니다.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 4),
            Text('(기존 구분 배정이 모두 초기화됩니다)',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
            const SizedBox(height: 16),
            if (widget.groupDefs.isEmpty)
              const Text('등록된 구분이 없습니다.', style: TextStyle(color: Colors.grey))
            else
              for (final g in widget.groupDefs)
                if (g.groupDefId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => setState(() {
                        if (_selected.contains(g.groupDefId!)) {
                          _selected.remove(g.groupDefId!);
                        } else {
                          _selected.add(g.groupDefId!);
                        }
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: _groupOption(g),
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          child: const Text('변경'),
        ),
      ],
    );
  }

  Widget _groupOption(MemberGroupDefModel g) {
    final color = _parseColor(g.groupColor);
    final sel = _selected.contains(g.groupDefId!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: sel ? color.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: sel ? color : Colors.grey.shade300,
          width: sel ? 2 : 1,
        ),
      ),
      child: Row(children: [
        Icon(
          sel ? Icons.check_box : Icons.check_box_outline_blank,
          color: sel ? color : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 10),
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(g.groupName,
            style: TextStyle(
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              color: sel ? color : Colors.black87,
            )),
      ]),
    );
  }
}
