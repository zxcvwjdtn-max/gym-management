import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// 사전 정의 색상 팔레트
const _palette = [
  '#1565C0', '#2E7D32', '#6A1B9A', '#C62828', '#E65100',
  '#0277BD', '#00695C', '#4527A0', '#AD1457', '#37474F',
];

class GroupDefScreen extends StatefulWidget {
  const GroupDefScreen({super.key});

  @override
  State<GroupDefScreen> createState() => _GroupDefScreenState();
}

class _GroupDefScreenState extends State<GroupDefScreen> {
  List<MemberGroupDefModel> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getMemberGroupDefs();
      if (mounted) setState(() { _groups = list; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); showErrorSnack(context, '불러오기 실패: $e'); }
    }
  }

  Future<void> _openForm({MemberGroupDefModel? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GroupDefDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(MemberGroupDefModel g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('구분 삭제'),
        content: Text('"${g.groupName}" 구분을 삭제하시겠습니까?\n해당 구분에 배정된 회원의 소속이 해제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteMemberGroupDef(g.groupDefId!);
      if (mounted) { showSuccessSnack(context, '삭제했습니다.'); _load(); }
    } catch (e) {
      if (mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(children: [
            const Icon(Icons.label, color: Color(0xFF1565C0), size: 26),
            const SizedBox(width: 10),
            const Text('고객 구분 관리',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('구분 추가'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 8),
          Text('센터만의 고객 구분을 정의하고 회원에게 여러 구분을 동시에 지정할 수 있습니다.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 20),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_groups.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_off, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('등록된 고객 구분이 없습니다.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _openForm(),
                      child: const Text('첫 구분 추가하기'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _GroupTile(
                  group: _groups[i],
                  onEdit: () => _openForm(existing: _groups[i]),
                  onDelete: () => _delete(_groups[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 구분 항목 타일 ────────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final MemberGroupDefModel group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupTile({required this.group, required this.onEdit, required this.onDelete});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(group.groupColor);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(group.groupName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${group.memberCount}명',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('수정'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: onDelete,
            icon: Icon(Icons.delete, size: 16, color: Colors.red.shade400),
            label: Text('삭제', style: TextStyle(color: Colors.red.shade400)),
          ),
        ]),
      ),
    );
  }
}

// ─── 구분 등록/수정 다이얼로그 ─────────────────────────────────────
class _GroupDefDialog extends StatefulWidget {
  final MemberGroupDefModel? existing;
  const _GroupDefDialog({this.existing});

  @override
  State<_GroupDefDialog> createState() => _GroupDefDialogState();
}

class _GroupDefDialogState extends State<_GroupDefDialog> {
  final _nameCtrl = TextEditingController();
  String _color = _palette[0];
  final _sortCtrl = TextEditingController(text: '0');
  bool _saving = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final e = widget.existing!;
      _nameCtrl.text = e.groupName;
      _color = e.groupColor;
      _sortCtrl.text = '${e.sortOrder}';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.blue; }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showErrorSnack(context, '구분 이름을 입력하세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final body = {
        'groupName': name,
        'groupColor': _color,
        'sortOrder': int.tryParse(_sortCtrl.text) ?? 0,
      };
      if (isEdit) {
        await api.updateMemberGroupDef(widget.existing!.groupDefId!, body);
      } else {
        await api.createMemberGroupDef(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdit ? '고객 구분 수정' : '고객 구분 추가'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '구분 이름',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('색상', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((hex) {
                final c = _parseColor(hex);
                final selected = _color == hex;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '정렬 순서',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
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
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEdit ? '수정' : '추가'),
        ),
      ],
    );
  }
}
