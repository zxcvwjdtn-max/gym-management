import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/app_select.dart';

const _primary = Color(0xFF4527A0);

class PtContractScreen extends StatefulWidget {
  const PtContractScreen({super.key});
  @override
  State<PtContractScreen> createState() => _PtContractScreenState();
}

class _PtContractScreenState extends State<PtContractScreen> {
  List<PtContractModel> _contracts = [];
  List<Map<String, dynamic>> _trainers = [];
  Map<String, dynamic>? _selectedTrainer;
  bool _loading = true;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getTrainers(),
        api.getPtContracts(trainerId: _selectedTrainer?['adminId']),
      ]);
      if (mounted) {
        setState(() {
          _trainers = results[0] as List<Map<String, dynamic>>;
          _contracts = results[1] as List<PtContractModel>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContracts() async {
    try {
      final contracts = await context.read<ApiService>().getPtContracts(
        trainerId: _selectedTrainer?['adminId'],
      );
      if (mounted) setState(() => _contracts = contracts);
    } catch (_) {}
  }

  List<PtContractModel> get _filtered {
    if (_statusFilter == 'ALL') return _contracts;
    return _contracts.where((c) => c.status == _statusFilter).toList();
  }

  void _showContractForm([PtContractModel? contract]) {
    showDialog(
      context: context,
      builder: (_) => _ContractFormDialog(
        trainers: _trainers,
        contract: contract,
        onSaved: _loadContracts,
      ),
    );
  }

  Future<void> _cancelContract(PtContractModel c) async {
    final loc = context.read<LocaleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('ptContract.cancelTitle')),
        content: Text(loc.t('ptContract.cancelConfirm', params: {
          'n': c.memberName ?? '',
          'r': c.remainSessions.toString(),
        })),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('ptContract.close'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('ptContract.cancelBtn')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().cancelPtContract(c.contractId!);
      _loadContracts();
    } catch (e) {
      if (mounted) showErrorSnack(context,
        loc.t('ptContract.cancelFail', params: {'e': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.assignment_ind, color: _primary, size: 26),
            const SizedBox(width: 10),
            Text(loc.t('ptContract.title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _trainers.isEmpty ? null : () => _showContractForm(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('ptContract.add')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            FilterPill<Map<String, dynamic>>(
              label: loc.t('ptContract.filter.trainer'),
              selectedLabel: _selectedTrainer?['adminName'] as String? ?? loc.t('ptContract.filter.all'),
              isActive: _selectedTrainer != null,
              options: [
                (loc.t('ptContract.filter.all'), null),
                ..._trainers.map((t) => (t['adminName'] as String? ?? '', t as Map<String, dynamic>?)),
              ],
              onSelected: (v) { setState(() => _selectedTrainer = v); _loadContracts(); },
              activeColor: _primary,
            ),
            const SizedBox(width: 16),
            for (final s in ['ALL', 'ACTIVE', 'COMPLETED', 'CANCELLED'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(loc.t('ptContract.status.$s')),
                  selected: _statusFilter == s,
                  onSelected: (_) => setState(() => _statusFilter = s),
                  selectedColor: _primary.withOpacity(0.2),
                  checkmarkColor: _primary,
                  labelStyle: TextStyle(
                    color: _statusFilter == s ? _primary : Colors.grey.shade600,
                    fontWeight: _statusFilter == s ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            const Spacer(),
            Text(loc.t('ptContract.countN', params: {'n': _filtered.length.toString()}),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(loc.t('ptContract.empty'),
                    style: TextStyle(color: Colors.grey.shade500)),
              ]),
            ))
          else
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(children: [
                      _th(loc.t('ptContract.col.member'), flex: 2),
                      _th(loc.t('ptContract.col.trainer'), flex: 2),
                      _th(loc.t('ptContract.col.period'), flex: 3),
                      _th(loc.t('ptContract.col.sessions'), flex: 2),
                      _th(loc.t('ptContract.col.price'), flex: 2),
                      _th(loc.t('ptContract.col.status'), flex: 1),
                      _th('', flex: 1),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = _filtered[i];
                        return _ContractRow(
                          contract: c,
                          onEdit: () => _showContractForm(c),
                          onCancel: () => _cancelContract(c),
                          onDetail: () => _showSessionsDialog(c),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _showSessionsDialog(PtContractModel c) {
    showDialog(
      context: context,
      builder: (_) => _SessionsDialog(contract: c),
    ).then((_) => _loadContracts());
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(label,
        style: TextStyle(fontWeight: FontWeight.bold,
            color: Colors.grey.shade600, fontSize: 12)),
  );
}

class _ContractRow extends StatelessWidget {
  final PtContractModel contract;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDetail;

  const _ContractRow({
    required this.contract,
    required this.onEdit,
    required this.onCancel,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final c = contract;
    final progressPct = c.totalSessions > 0
        ? c.usedSessions / c.totalSessions
        : 0.0;

    return InkWell(
      onTap: onDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(flex: 2, child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _primary.withOpacity(0.12),
              backgroundImage: c.photoUrl != null ? NetworkImage(c.photoUrl!) : null,
              child: c.photoUrl == null
                  ? Text((c.memberName ?? '?')[0],
                      style: const TextStyle(color: _primary, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.memberName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (c.memberNo != null)
                Text(c.memberNo!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ])),
          ])),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.trainerName ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            if (c.trainerSpecialty != null && c.trainerSpecialty!.isNotEmpty)
              Text(c.trainerSpecialty!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ])),
          Expanded(flex: 3, child: Text(
            '${c.startDate} ~ ${c.endDate}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          )),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(loc.t('ptContract.sessionsN',
                params: {'u': c.usedSessions.toString(), 't': c.totalSessions.toString()}),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progressPct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: _primary,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            Text(loc.t('ptContract.remainN', params: {'n': c.remainSessions.toString()}),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ])),
          Expanded(flex: 2, child: Text(
            loc.t('acc.wonAmount', params: {'v': _fmtPrice(c.price)}),
            style: const TextStyle(fontWeight: FontWeight.w600),
          )),
          Expanded(flex: 1, child: _statusBadge(loc, c.status)),
          Expanded(flex: 1, child: Row(children: [
            if (c.status == 'ACTIVE') ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                onPressed: onEdit,
                tooltip: loc.t('ptContract.edit'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                onPressed: onCancel,
                tooltip: loc.t('ptContract.cancelTip'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ])),
        ]),
      ),
    );
  }

  Widget _statusBadge(LocaleProvider loc, String status) {
    final color = switch (status) {
      'ACTIVE' => Colors.green,
      'COMPLETED' => Colors.blue,
      'CANCELLED' => Colors.grey,
      _ => Colors.grey,
    };
    final label = loc.t('ptContract.status.$status');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _fmtPrice(int v) =>
      v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _ContractFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> trainers;
  final PtContractModel? contract;
  final VoidCallback onSaved;

  const _ContractFormDialog({
    required this.trainers,
    this.contract,
    required this.onSaved,
  });

  @override
  State<_ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends State<_ContractFormDialog> {
  Map<String, dynamic>? _selectedTrainer;
  Map<String, dynamic>? _selectedMember;
  List<Map<String, dynamic>> _members = [];

  final _sessionsCtrl = TextEditingController(text: '10');
  final _priceCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startCtrl.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final end = DateTime(now.year, now.month + 3, now.day);
    _endCtrl.text = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

    if (widget.contract != null) {
      final c = widget.contract!;
      _sessionsCtrl.text = c.totalSessions.toString();
      _priceCtrl.text = c.price.toString();
      _memoCtrl.text = c.memo ?? '';
      _startCtrl.text = c.startDate;
      _endCtrl.text = c.endDate;
      _selectedTrainer = widget.trainers.firstWhere(
        (t) => t['adminId'] == c.trainerId,
        orElse: () => widget.trainers.isNotEmpty ? widget.trainers.first : {},
      );
    } else if (widget.trainers.isNotEmpty) {
      _selectedTrainer = widget.trainers.first;
    }
    _loadMembers();
  }

  @override
  void dispose() {
    _sessionsCtrl.dispose();
    _priceCtrl.dispose();
    _memoCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final data = await context.read<ApiService>().getMembers();
      if (mounted) setState(() { _members = data.map((m) => {
        'memberId': m.memberId,
        'memberName': m.memberName,
        'memberNo': m.memberNo,
      }).toList(); _loadingMembers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _save() async {
    final loc = context.read<LocaleProvider>();
    if (_selectedTrainer == null || _selectedMember == null) {
      showErrorSnack(context, loc.t('ptContract.form.errSelect'));
      return;
    }
    final sessions = int.tryParse(_sessionsCtrl.text) ?? 0;
    if (sessions <= 0) {
      showErrorSnack(context, loc.t('ptContract.form.errSessions'));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final body = {
        'trainerId': _selectedTrainer!['adminId'],
        'memberId': _selectedMember!['memberId'],
        'totalSessions': sessions,
        'startDate': _startCtrl.text.trim(),
        'endDate': _endCtrl.text.trim(),
        'price': int.tryParse(_priceCtrl.text) ?? 0,
        if (_memoCtrl.text.trim().isNotEmpty) 'memo': _memoCtrl.text.trim(),
      };
      if (widget.contract == null) {
        await api.createPtContract(body);
      } else {
        await api.updatePtContract(widget.contract!.contractId!, body);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context,
        loc.t('ptContract.form.saveFail', params: {'e': e.toString()}));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final isEdit = widget.contract != null;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.assignment_ind, color: _primary, size: 20),
        const SizedBox(width: 8),
        Text(isEdit ? loc.t('ptContract.editTitle') : loc.t('ptContract.add')),
      ]),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FormSelect<Map<String, dynamic>>(
              label: loc.t('ptContract.form.trainer'),
              isRequired: true,
              currentLabel: _selectedTrainer == null ? null
                  : '${_selectedTrainer!['adminName']}${_selectedTrainer!['specialty'] != null && _selectedTrainer!['specialty'].toString().isNotEmpty ? ' (${_selectedTrainer!['specialty']})' : ''}',
              hint: loc.t('ptContract.form.selectTrainer'),
              options: widget.trainers.map((t) => (
                '${t['adminName']}${t['specialty'] != null && t['specialty'].toString().isNotEmpty ? ' (${t['specialty']})' : ''}',
                t as Map<String, dynamic>?,
              )).toList(),
              onSelected: (v) => setState(() => _selectedTrainer = v),
            ),
            const SizedBox(height: 12),
            if (_loadingMembers)
              const LinearProgressIndicator()
            else
              IgnorePointer(
                ignoring: isEdit,
                child: Opacity(
                  opacity: isEdit ? 0.6 : 1.0,
                  child: FormSelect<Map<String, dynamic>>(
                    label: loc.t('ptContract.form.member'),
                    isRequired: true,
                    currentLabel: _selectedMember == null ? null
                        : '${_selectedMember!['memberName']} (${_selectedMember!['memberNo']})',
                    hint: loc.t('ptContract.form.selectMember'),
                    options: _members.map((m) => (
                      '${m['memberName']} (${m['memberNo']})',
                      m as Map<String, dynamic>?,
                    )).toList(),
                    onSelected: (v) => setState(() => _selectedMember = v),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(
                controller: _sessionsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: loc.t('ptContract.form.sessionsLabel'),
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('ptContract.form.sessionsSuffix')),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: loc.t('ptContract.form.priceLabel'),
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('ptContract.form.priceSuffix')),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(
                controller: _startCtrl,
                decoration: InputDecoration(
                    labelText: loc.t('ptContract.form.startLabel'),
                    border: const OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD'),
              )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('~', style: TextStyle(fontSize: 18)),
              ),
              Expanded(child: TextField(
                controller: _endCtrl,
                decoration: InputDecoration(
                    labelText: loc.t('ptContract.form.endLabel'),
                    border: const OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD'),
              )),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _memoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: loc.t('ptContract.form.memoLabel'),
                  border: const OutlineInputBorder()),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(loc.t('common.save')),
        ),
      ],
    );
  }
}

class _SessionsDialog extends StatefulWidget {
  final PtContractModel contract;
  const _SessionsDialog({required this.contract});
  @override
  State<_SessionsDialog> createState() => _SessionsDialogState();
}

class _SessionsDialogState extends State<_SessionsDialog> {
  List<PtSessionModel> _sessions = [];
  bool _loading = true;
  bool _showForm = false;

  final _dateCtrl  = TextEditingController();
  final _startCtrl = TextEditingController(text: '10:00');
  final _endCtrl   = TextEditingController(text: '11:00');
  final _memoCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateCtrl.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadSessions();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>()
          .getPtSessionsByContract(widget.contract.contractId!);
      if (mounted) setState(() { _sessions = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSession() async {
    final loc = context.read<LocaleProvider>();
    try {
      await context.read<ApiService>().createPtSession({
        'contractId': widget.contract.contractId,
        'trainerId': widget.contract.trainerId,
        'memberId': widget.contract.memberId,
        'sessionDate': _dateCtrl.text.trim(),
        'startTime': _startCtrl.text.trim(),
        'endTime': _endCtrl.text.trim(),
        'status': 'SCHEDULED',
        if (_memoCtrl.text.trim().isNotEmpty) 'memo': _memoCtrl.text.trim(),
      });
      _memoCtrl.clear();
      setState(() => _showForm = false);
      _loadSessions();
    } catch (e) {
      if (mounted) showErrorSnack(context,
        loc.t('ptContract.sessions.createFail', params: {'e': e.toString()}));
    }
  }

  Future<void> _updateStatus(PtSessionModel s, String status) async {
    final loc = context.read<LocaleProvider>();
    try {
      final api = context.read<ApiService>();
      if (status == 'COMPLETED') await api.completePtSession(s.sessionId!);
      else if (status == 'CANCELLED') await api.cancelPtSession(s.sessionId!);
      else if (status == 'NO_SHOW') await api.noShowPtSession(s.sessionId!);
      _loadSessions();
    } catch (e) {
      if (mounted) showErrorSnack(context,
        loc.t('ptContract.sessions.statusFail', params: {'e': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final c = widget.contract;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.list_alt, color: _primary, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(loc.t('ptContract.sessions.title', params: {
          'm': c.memberName ?? '',
          't': c.trainerName ?? '',
        }))),
        TextButton.icon(
          onPressed: () => setState(() => _showForm = !_showForm),
          icon: Icon(_showForm ? Icons.close : Icons.add, size: 16),
          label: Text(_showForm
              ? loc.t('ptContract.sessions.cancelAdd')
              : loc.t('ptContract.sessions.addBtn')),
          style: TextButton.styleFrom(foregroundColor: _primary),
        ),
      ]),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                _statItem(loc.t('ptContract.sessions.sumTotal'),
                    loc.t('ptContract.sessions.countN', params: {'n': c.totalSessions.toString()}),
                    Colors.grey.shade700),
                const SizedBox(width: 20),
                _statItem(loc.t('ptContract.sessions.sumCompleted'),
                    loc.t('ptContract.sessions.countN', params: {'n': c.usedSessions.toString()}),
                    Colors.green),
                const SizedBox(width: 20),
                _statItem(loc.t('ptContract.sessions.sumRemain'),
                    loc.t('ptContract.sessions.countN', params: {'n': c.remainSessions.toString()}),
                    _primary),
                const Spacer(),
                Text('${c.startDate} ~ ${c.endDate}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
            if (_showForm) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: _dateCtrl,
                  decoration: InputDecoration(
                      labelText: loc.t('ptContract.sessions.dateLabel'),
                      border: const OutlineInputBorder(), isDense: true,
                      hintText: 'YYYY-MM-DD'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _startCtrl,
                  decoration: InputDecoration(
                      labelText: loc.t('ptContract.sessions.startLabel'),
                      border: const OutlineInputBorder(), isDense: true,
                      hintText: 'HH:mm'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _endCtrl,
                  decoration: InputDecoration(
                      labelText: loc.t('ptContract.sessions.endLabel'),
                      border: const OutlineInputBorder(), isDense: true,
                      hintText: 'HH:mm'),
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addSession,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                  child: Text(loc.t('ptContract.sessions.addAction')),
                ),
              ]),
              TextField(
                controller: _memoCtrl,
                decoration: InputDecoration(
                    labelText: loc.t('ptContract.sessions.memoLabel'),
                    border: const OutlineInputBorder(), isDense: true),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const CircularProgressIndicator()
            else if (_sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(loc.t('ptContract.sessions.empty'),
                    style: TextStyle(color: Colors.grey.shade500)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    return _SessionRow(session: s, onStatusChange: _updateStatus);
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white),
          child: Text(loc.t('ptContract.close')),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
    ],
  );
}

class _SessionRow extends StatelessWidget {
  final PtSessionModel session;
  final void Function(PtSessionModel, String) onStatusChange;

  const _SessionRow({required this.session, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final s = session;
    final statusColor = _statusColor(s.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(loc.t('ptContract.sessions.rowN', params: {'n': s.sessionNo.toString()}),
              style: const TextStyle(color: _primary, fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.sessionDate}  ${s.startTime} ~ ${s.endTime}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (s.memo != null && s.memo!.isNotEmpty)
            Text(s.memo!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(loc.t('ptContract.sessions.status.${s.status}'),
              style: TextStyle(color: statusColor, fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        if (s.status == 'SCHEDULED') ...[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 16),
            onSelected: (v) => onStatusChange(s, v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'COMPLETED',
                child: Text(loc.t('ptContract.sessions.menu.complete'))),
              PopupMenuItem(value: 'NO_SHOW',
                child: Text(loc.t('ptContract.sessions.menu.noshow'))),
              PopupMenuItem(value: 'CANCELLED',
                child: Text(loc.t('ptContract.sessions.menu.cancel'))),
            ],
          ),
        ],
      ]),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'COMPLETED' => Colors.green,
    'CANCELLED' => Colors.grey,
    'NO_SHOW' => Colors.red,
    _ => Colors.blue,
  };
}
