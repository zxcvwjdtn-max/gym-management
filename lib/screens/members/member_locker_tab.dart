// ──────────────────────────────────────────────────────────────
// member_locker_tab.dart
// 회원 상세 > 탭 4: 라커
// _LockerTab, _LockerTabState, _LockerCard, _AssignLockerDialog, _AssignLockerDialogState
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/app_select.dart';

// ──────────────────────────────────────────────────────────────
// 탭 4: 라커 목록
// ──────────────────────────────────────────────────────────────
class MemberLockerTab extends StatefulWidget {
  final int memberId;
  const MemberLockerTab({required this.memberId});

  @override
  State<MemberLockerTab> createState() => _LockerTabState();
}

class _LockerTabState extends State<MemberLockerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// 헬스장 전체 라커 목록 (배정 가능 여부 판단에 사용)
  List<LockerModel> _allLockers = [];

  /// 이 회원에게 배정된 라커 목록
  List<LockerModel> _memberLockers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 전체 라커 및 회원 배정 라커 동시 조회
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
    final loc = context.watch<LocaleProvider>();
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text(loc.t('member.locker.assigned'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _showAssignDialog(loc),
            icon: const Icon(Icons.add, size: 16),
            label: Text(loc.t('member.locker.assignBtn')),
          ),
        ]),
        const SizedBox(height: 10),
        if (_memberLockers.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(loc.t('member.locker.empty'), style: const TextStyle(color: Colors.grey)),
          ))
        else
          ..._memberLockers.map((l) => _LockerCard(locker: l, onAction: _load)),
      ],
    );
  }

  /// AVAILABLE 상태 라커가 있을 때만 배정 다이얼로그 표시
  void _showAssignDialog(LocaleProvider loc) {
    final available = _allLockers.where((l) => l.status == 'AVAILABLE').toList();
    if (available.isEmpty) {
      showErrorSnack(context, loc.t('member.locker.noAvailable'));
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

/// 배정된 라커 한 장 카드
class _LockerCard extends StatelessWidget {
  final LockerModel locker;
  final VoidCallback onAction;
  const _LockerCard({required this.locker, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        // 라커 번호 박스
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
            Text(loc.t('member.locker.lockerNo', params: {'no': locker.lockerNo ?? '-'}),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (locker.startDate != null)
              Text('${locker.startDate} ~ ${locker.endDate ?? loc.t('member.locker.noEndDate')}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            if (locker.monthlyFee != null && locker.monthlyFee! > 0)
              Text(loc.t('member.locker.monthlyFee', params: {'n': locker.monthlyFee.toString()}),
                  style: const TextStyle(fontSize: 16)),
          ],
        )),
        OutlinedButton(
          onPressed: () => _release(context, loc),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: Text(loc.t('member.locker.releaseBtn'), style: const TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }

  /// 라커 배정 해제 확인 후 API 호출
  void _release(BuildContext context, LocaleProvider loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('member.locker.release.title')),
        content: Text(loc.t('member.locker.release.confirm', params: {'no': locker.lockerNo ?? '-'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('member.locker.releaseBtn')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<ApiService>().releaseLocker(locker.lockerId!);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context,
          loc.t('member.locker.release.fail', params: {'e': e.toString()}));
    }
  }
}

/// 라커 배정 다이얼로그
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

  /// DateTime → 'YYYY-MM-DD' 포맷
  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  /// 시작일 달력 선택
  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// 종료일 달력 선택
  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  /// 배정 저장
  Future<void> _save(LocaleProvider loc) async {
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
      if (mounted) showErrorSnack(context,
          loc.t('member.locker.dialog.fail', params: {'e': e.toString()}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return AlertDialog(
      title: Text(loc.t('member.locker.dialog.title')),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 라커 선택
            FormSelect<int>(
              label: loc.t('member.locker.dialog.selectLabel'),
              isRequired: true,
              currentLabel: _selectedLockerId == null ? null
                  : '${widget.availableLockers.firstWhere((l) => l.lockerId == _selectedLockerId, orElse: () => widget.availableLockers.first).lockerNo}번',
              hint: loc.t('member.locker.dialog.selectHint'),
              options: widget.availableLockers.map((l) => ('${l.lockerNo}번', l.lockerId as int?)).toList(),
              onSelected: (v) => setState(() => _selectedLockerId = v),
            ),
            const SizedBox(height: 12),
            // 시작일 달력 선택
            InkWell(
              onTap: _pickStart,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: loc.t('member.locker.dialog.startDate'),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_startDate != null ? _fmt(_startDate) : loc.t('member.locker.dialog.selectPlaceholder'),
                    style: TextStyle(color: _startDate != null ? Colors.black87 : Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            // 종료일 달력 선택
            InkWell(
              onTap: _pickEnd,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: loc.t('member.locker.dialog.endDate'),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_endDate != null ? _fmt(_endDate) : loc.t('member.locker.dialog.selectPlaceholder'),
                    style: TextStyle(color: _endDate != null ? Colors.black87 : Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            // 월 이용료
            TextField(controller: _feeCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: loc.t('member.locker.dialog.monthlyFee'),
                  border: const OutlineInputBorder(),
                  suffixText: loc.t('common.won'))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(loc),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(loc.t('member.locker.dialog.assignBtn')),
        ),
      ],
    );
  }
}
