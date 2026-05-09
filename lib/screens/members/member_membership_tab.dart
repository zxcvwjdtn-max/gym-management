// 회원 상세 > 탭 1: 이용권 목록, 연장/정지/일시정지/추가 다이얼로그
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_select.dart';

// ──────────────────────────────────────────────────────────────
// 탭 1: 이용권 목록
// ──────────────────────────────────────────────────────────────
class MemberMembershipTab extends StatefulWidget {
  final int memberId;
  final MemberModel member;
  const MemberMembershipTab({required this.memberId, required this.member});

  @override
  State<MemberMembershipTab> createState() => _MembershipTabState();
}

class _MembershipTabState extends State<MemberMembershipTab>
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
    final loc = context.watch<LocaleProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text(loc.t('member.ms.history'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddMembershipDialog(memberId: widget.memberId, onSaved: _load),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(loc.t('member.ms.add')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_list.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(loc.t('member.ms.empty'),
                style: const TextStyle(color: Colors.grey)),
          ))
        else
          ..._list.map((ms) => _MembershipCard(membership: ms, onAction: _load)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 이용권 카드
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
          _ActionBtn(label: loc.t('member.ms.btn.extend'), icon: Icons.add,
              onTap: () => _extend(context)),
          const SizedBox(width: 4),
          _ActionBtn(label: loc.t('common.delete'), icon: Icons.delete_outline,
            onTap: () => _delete(context), color: Colors.red.shade700),
        ]),

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
                child: Text(
                  loc.t('member.ms.remain.count',
                      params: {'n': membership.remainCount.toString()}),
                  style: TextStyle(color: Colors.purple.shade700,
                      fontSize: 12, fontWeight: FontWeight.w600)),
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
                child: Text(
                  loc.t('member.ms.remain.days',
                      params: {'n': membership.remainDays.toString()}),
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12)),
              ),
              const SizedBox(width: 10),
            ],
            if (membership.status == 'PAUSED')
              _ActionBtn(label: loc.t('member.ms.btn.resume'), icon: Icons.play_arrow,
                  onTap: () => _resume(context)),
            if (membership.status != 'PAUSED') ...[
              _ActionBtn(label: loc.t('member.ms.btn.pause'), icon: Icons.pause,
                  onTap: () => _pause(context)),
              const SizedBox(width: 4),
              _ActionBtn(label: loc.t('member.ms.btn.suspend'), icon: Icons.block,
                  onTap: () => _suspend(context), color: Colors.red.shade400),
            ],
          ]),
          if (membership.status == 'PAUSED' && membership.pauseStartDate != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.pause_circle_outline, size: 13, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text(
                loc.t('member.ms.pauseInfo', params: {
                  'start': membership.pauseStartDate!,
                  'end': membership.pauseEndDate != null
                      ? loc.t('member.ms.pauseInfoEnd',
                          params: {'end': membership.pauseEndDate!})
                      : '',
                }),
                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
              ),
            ]),
          ],
        ],
      ]),
    );
  }

  void _extend(BuildContext context) async {
    final loc = context.read<LocaleProvider>();
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _ExtendDialog(membership: membership),
    );
    if (days == null) return;
    try {
      await context.read<ApiService>().extendMembership(membership.membershipId!, days);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context,
          loc.t('member.ms.extend.fail', params: {'e': e.toString()}));
    }
  }

  void _pause(BuildContext context) async {
    final loc = context.read<LocaleProvider>();
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
      if (context.mounted) showErrorSnack(context,
          loc.t('member.ms.pause.fail', params: {'e': e.toString()}));
    }
  }

  void _resume(BuildContext context) async {
    await context.read<ApiService>().resumeMembership(membership.membershipId!);
    onAction();
  }

  void _suspend(BuildContext context) async {
    final loc = context.read<LocaleProvider>();
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _SuspendDialog(membership: membership),
    );
    if (days == null) return;
    try {
      await context.read<ApiService>().suspendMembership(membership.membershipId!, days: days);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context,
          loc.t('member.ms.suspend.fail', params: {'e': e.toString()}));
    }
  }

  void _delete(BuildContext context) async {
    final loc = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('member.ms.delete.title')),
        content: Text(loc.t('member.ms.delete.confirm',
            params: {'name': membership.ticketName ?? '-'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<ApiService>().deleteMembership(membership.membershipId!);
      onAction();
    } catch (e) {
      if (context.mounted) showErrorSnack(context,
          loc.t('member.ms.delete.fail', params: {'e': e.toString()}));
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
    final loc = context.watch<LocaleProvider>();
    final newEnd = _newEnd;
    return AlertDialog(
      title: Text(loc.t('member.ms.extend.title')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(loc.t('member.ms.extend.modeLabel'),
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text(loc.t('member.ms.extend.mode.days')),
                selected: !_usePicker,
                onSelected: (_) => setState(() { _usePicker = false; _pickedDate = null; }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(loc.t('member.ms.extend.mode.cal')),
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
                decoration: InputDecoration(
                  labelText: loc.t('member.ms.extend.daysLabel'),
                  hintText: '예: 30',
                  border: const OutlineInputBorder(),
                  suffixText: loc.t('common.days'),
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
                label: Text(_pickedDate != null
                    ? _fmt(_pickedDate!)
                    : loc.t('member.ms.extend.selectDate')),
              ),
            const SizedBox(height: 16),
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
                    Text(loc.t('member.ms.extend.currentEnd'),
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(widget.membership.endDate ?? '-',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.event_available, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(loc.t('member.ms.extend.newEnd'),
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
                      child: Text(
                        loc.t('member.ms.extend.daysSuffix',
                            params: {'n': _days.toString()}),
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
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _valid ? () => Navigator.pop(context, _days) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          child: Text(loc.t('member.ms.extend.btn')),
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
    final loc = context.watch<LocaleProvider>();
    final endDate = _endDate;
    return AlertDialog(
      title: Text(loc.t('member.ms.suspend.title')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loc.t('member.ms.suspend.indefinite'),
                  style: const TextStyle(fontSize: 16)),
              subtitle: Text(loc.t('member.ms.suspend.indefiniteDesc'),
                  style: const TextStyle(fontSize: 16)),
              value: _indefinite,
              onChanged: (v) => setState(() {
                _indefinite = v;
                if (v) { _daysCtrl.clear(); _pickedEnd = null; }
              }),
            ),
            if (!_indefinite) ...[
              const Divider(),
              const SizedBox(height: 4),
              Row(children: [
                Text(loc.t('member.ms.suspend.modeLabel'),
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Text(loc.t('member.ms.suspend.mode.days')),
                  selected: !_usePicker,
                  onSelected: (_) => setState(() { _usePicker = false; _pickedEnd = null; }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(loc.t('member.ms.suspend.mode.cal')),
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
                  decoration: InputDecoration(
                    labelText: loc.t('member.ms.suspend.daysLabel'),
                    hintText: '예: 14',
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('common.days'),
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
                  label: Text(_pickedEnd != null
                      ? _fmt(_pickedEnd!)
                      : loc.t('member.ms.suspend.selectDate')),
                ),
            ],
            const SizedBox(height: 16),
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
                    Text(loc.t('member.ms.suspend.startDate'),
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(_fmt(_startDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.event_busy, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(loc.t('member.ms.suspend.endDate'),
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text(
                      _indefinite
                          ? loc.t('member.ms.suspend.indefiniteLabel')
                          : (endDate != null ? _fmt(endDate) : '-'),
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
                      child: Text(
                        loc.t('member.ms.suspend.daysSuffix',
                            params: {'n': _days.toString()}),
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
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _valid ? () => Navigator.pop(context, _days) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
          child: Text(loc.t('member.ms.suspend.btn')),
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
    final loc = context.watch<LocaleProvider>();
    return AlertDialog(
      title: Text(loc.t('member.ms.pause.title')),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loc.t('member.ms.pause.specify')),
              subtitle: Text(loc.t('member.ms.pause.specifyDesc')),
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
                decoration: InputDecoration(
                  labelText: loc.t('member.ms.pause.daysLabel'),
                  hintText: '예: 14',
                  border: const OutlineInputBorder(),
                  suffixText: loc.t('common.days'),
                ),
              ),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final d = int.tryParse(_daysCtrl.text);
                if (d == null || d <= 0) return const SizedBox.shrink();
                final endDate = DateTime.now().add(Duration(days: d));
                return Text(
                  loc.t('member.ms.pause.resumeDate', params: {
                    'date': '${endDate.year}-'
                        '${endDate.month.toString().padLeft(2, '0')}-'
                        '${endDate.day.toString().padLeft(2, '0')}',
                  }),
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 16),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
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
          child: Text(loc.t('member.ms.pause.btn')),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 이용권 추가 다이얼로그 (public — 회원 리스트에서도 호출됨)
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
      end = DateTime(_startDate.year, _startDate.month + months,
          _startDate.day + days - 1);
    } else {
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

  Future<void> _save(LocaleProvider loc) async {
    if (_ticket == null) {
      showErrorSnack(context, loc.t('member.ms.addDialog.ticketRequired'));
      return;
    }
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
      if (mounted) showErrorSnack(context,
          loc.t('member.ms.addDialog.fail', params: {'e': e.toString()}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final methodLabel = {
      'CARD': loc.t('member.ms.addDialog.methodCard'),
      'CASH': loc.t('member.ms.addDialog.methodCash'),
      'TRANSFER': loc.t('member.ms.addDialog.methodTransfer'),
    }[_method];

    return AlertDialog(
      title: Text(loc.t('member.ms.addDialog.title')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FormSelect<TicketModel>(
              label: loc.t('member.ms.addDialog.ticket'),
              isRequired: true,
              currentLabel: _ticket == null ? null
                  : '${_ticket!.isCommon ? '[공통] ' : ''}${_ticket!.ticketName}  (${_fmtPrice(_ticket!.price)})',
              hint: loc.t('member.ms.addDialog.ticketHint'),
              options: _tickets.map((t) => (
                '${t.isCommon ? '[공통] ' : ''}${t.ticketName}  (${_fmtPrice(t.price)})',
                t as TicketModel?,
              )).toList(),
              onSelected: _onTicketChanged,
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStart,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: loc.t('member.ms.addDialog.startDate'),
                      border: const OutlineInputBorder()),
                    child: Row(children: [
                      Text(_fmt(_startDate), style: const TextStyle(fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickEnd,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: _ticket?.isCount == true
                          ? (_endDate != null
                              ? loc.t('member.ms.addDialog.validEndManual')
                              : loc.t('member.ms.addDialog.validEndAuto'))
                          : (_endDate != null
                              ? loc.t('member.ms.addDialog.endDateManual')
                              : loc.t('member.ms.addDialog.endDateAuto')),
                      border: const OutlineInputBorder()),
                    child: Row(children: [
                      Text(
                        _endDate != null
                            ? _fmt(_endDate!)
                            : loc.t('member.ms.addDialog.endAfterSelect'),
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

            if (_ticket != null && _endDate != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _ticket!.isCount ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _ticket!.isCount
                      ? Colors.purple.shade200 : Colors.blue.shade200),
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

            Row(children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: loc.t('member.ms.addDialog.amount'),
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('common.won'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormSelect<String>(
                  label: loc.t('member.ms.addDialog.method'),
                  currentLabel: methodLabel,
                  hint: loc.t('member.ms.addDialog.methodHint'),
                  options: [
                    (loc.t('member.ms.addDialog.methodCard'), 'CARD'),
                    (loc.t('member.ms.addDialog.methodCash'), 'CASH'),
                    (loc.t('member.ms.addDialog.methodTransfer'), 'TRANSFER'),
                  ],
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

            if (_method == 'CARD') ...[
              FormSelect<String>(
                label: loc.t('member.ms.addDialog.cardCompany'),
                currentLabel: _cardCompany,
                hint: loc.t('member.ms.addDialog.cardCompanyHint'),
                options: _cardCompanies.map((c) => (c, c)).toList(),
                onSelected: (v) => setState(() => _cardCompany = v),
              ),
              const SizedBox(height: 10),
            ],

            TextField(
              controller: _unpaidCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: loc.t('member.ms.addDialog.unpaid'),
                border: const OutlineInputBorder(),
                suffixText: loc.t('common.won'),
                helperText: loc.t('member.ms.addDialog.unpaidHelper'),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _memoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: loc.t('member.ms.addDialog.memo'),
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(loc),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(loc.t('member.ms.addDialog.btn')),
        ),
      ],
    );
  }

  String _fmtPrice(int p) =>
      '${p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}
