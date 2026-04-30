import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<WorkoutModel> _workouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getWorkouts();
      if (mounted) setState(() { _workouts = list; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); showErrorSnack(context, '불러오기 실패: $e'); }
    }
  }

  Future<void> _openForm({WorkoutModel? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => WorkoutFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(WorkoutModel w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('운동 삭제'),
        content: Text('"${w.title}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteWorkout(w.workoutId!);
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
          Row(children: [
            const Icon(Icons.fitness_center, color: Color(0xFF6A1B9A), size: 26),
            const SizedBox(width: 10),
            const Text('오늘의 운동', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            if (!_loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('${_workouts.length}건', style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('운동 등록'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 8),
          Text('가장 최근에 등록한 운동이 대시보드에 표시됩니다.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_workouts.isEmpty)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fitness_center, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('등록된 운동이 없습니다.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => _openForm(), child: const Text('첫 운동 등록')),
              ]),
            ))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _workouts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _WorkoutTile(
                  workout: _workouts[i],
                  isLatest: i == 0,
                  onEdit: () => _openForm(existing: _workouts[i]),
                  onDelete: () => _confirmDelete(_workouts[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final WorkoutModel workout;
  final bool isLatest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _WorkoutTile({required this.workout, required this.isLatest, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = workout.createdAt != null && workout.createdAt!.length >= 10
        ? workout.createdAt!.substring(0, 10) : '-';
    return Card(
      elevation: isLatest ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isLatest ? const BorderSide(color: Color(0xFF6A1B9A), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => showDialog(context: context, builder: (_) => WorkoutDetailDialog(workout: workout)),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Icon(Icons.fitness_center, color: isLatest ? const Color(0xFF6A1B9A) : Colors.grey.shade400, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (isLatest) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('최신', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  Expanded(
                    child: Text(workout.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (workout.content != null && workout.content!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(workout.content!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 12),
            TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 14), label: const Text('수정', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete, size: 14, color: Colors.red.shade400),
              label: Text('삭제', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── 운동 상세 팝업 (대시보드·화면 공통) ──────────────────────────
class WorkoutDetailDialog extends StatelessWidget {
  final WorkoutModel workout;
  const WorkoutDetailDialog({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final date = workout.workoutDate ?? (workout.createdAt != null && workout.createdAt!.length >= 10
        ? workout.createdAt!.substring(0, 10) : '-');
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.fitness_center, color: Color(0xFF6A1B9A), size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(workout.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
      ]),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (workout.createdBy != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(workout.createdBy!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ]),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                child: Text(workout.content ?? '', style: const TextStyle(fontSize: 14, height: 1.7)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

// ─── 운동 작성/수정 다이얼로그 (대시보드에서도 재사용 가능) ──────
class WorkoutFormDialog extends StatefulWidget {
  final WorkoutModel? existing;
  const WorkoutFormDialog({super.key, this.existing});
  @override
  State<WorkoutFormDialog> createState() => _WorkoutFormDialogState();
}

class _WorkoutFormDialogState extends State<WorkoutFormDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  bool _saving = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final e = widget.existing!;
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content ?? '';
      _dateCtrl.text = e.workoutDate ?? '';
    } else {
      final now = DateTime.now();
      _dateCtrl.text = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime init;
    try { init = DateTime.parse(_dateCtrl.text); } catch (_) { init = DateTime.now(); }
    final picked = await showDatePicker(
      context: context, initialDate: init,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
      });
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) { showErrorSnack(context, '제목을 입력하세요.'); return; }
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final body = {
        'title': title,
        'content': _contentCtrl.text.trim(),
        if (_dateCtrl.text.isNotEmpty) 'workoutDate': _dateCtrl.text.trim(),
      };
      if (isEdit) {
        await api.updateWorkout(widget.existing!.workoutId!, body);
      } else {
        await api.createWorkout(body);
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
      title: Text(isEdit ? '운동 수정' : '오늘의 운동 등록'),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            maxLines: 10,
            decoration: const InputDecoration(
                labelText: '운동 내용',
                hintText: '세트/횟수, 운동 설명, 주의사항 등을 자유롭게 입력하세요.',
                border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dateCtrl,
            readOnly: true,
            onTap: _pickDate,
            decoration: const InputDecoration(
              labelText: '날짜',
              border: OutlineInputBorder(), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEdit ? '수정' : '등록'),
        ),
      ],
    );
  }
}
