import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/app_select.dart';

const _primary = Color(0xFF4527A0);

class PtSessionScreen extends StatefulWidget {
  const PtSessionScreen({super.key});
  @override
  State<PtSessionScreen> createState() => _PtSessionScreenState();
}

class _PtSessionScreenState extends State<PtSessionScreen> {
  DateTime _selectedDate = DateTime.now();
  List<PtSessionModel> _sessions = [];
  List<Map<String, dynamic>> _trainers = [];
  int? _filterTrainerId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final results = await Future.wait([
        api.getTrainers(),
        api.getPtSessions(date: dateStr),
      ]);
      if (mounted) {
        setState(() {
          _trainers = results[0] as List<Map<String, dynamic>>;
          _sessions = results[1] as List<PtSessionModel>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSessions() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final sessions = await context.read<ApiService>().getPtSessions(date: dateStr);
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {}
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadSessions();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSessions();
    }
  }

  List<PtSessionModel> get _filtered {
    if (_filterTrainerId == null) return _sessions;
    return _sessions.where((s) => s.trainerId == _filterTrainerId).toList();
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
      if (mounted) showErrorSnack(context, '${loc.t('ptSession.fail')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final localeCode = loc.locale.languageCode;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    final completedCount = _filtered.where((s) => s.status == 'COMPLETED').length;
    final scheduledCount = _filtered.where((s) => s.status == 'SCHEDULED').length;
    final noShowCount = _filtered.where((s) => s.status == 'NO_SHOW').length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(children: [
            const Icon(Icons.how_to_reg, color: _primary, size: 26),
            const SizedBox(width: 10),
            Text(loc.t('ptSession.title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            // 날짜 이동
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeDate(-1),
            ),
            TextButton(
              onPressed: _pickDate,
              child: Text(
                DateFormat(loc.t('ptSession.dateFormat'), localeCode).format(_selectedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isToday ? _primary : Colors.black87,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeDate(1),
            ),
            if (!isToday)
              TextButton(
                onPressed: () {
                  setState(() => _selectedDate = DateTime.now());
                  _loadSessions();
                },
                child: Text(loc.t('ptSession.today')),
              ),
          ]),
          const SizedBox(height: 12),

          // 요약 카드
          Row(children: [
            _summaryCard(loc.t('ptSession.sum.all'),
                loc.t('ptSession.count', params: {'n': _filtered.length.toString()}),
                Colors.grey.shade600),
            const SizedBox(width: 12),
            _summaryCard(loc.t('ptSession.sum.scheduled'),
                loc.t('ptSession.count', params: {'n': scheduledCount.toString()}),
                Colors.blue),
            const SizedBox(width: 12),
            _summaryCard(loc.t('ptSession.sum.completed'),
                loc.t('ptSession.count', params: {'n': completedCount.toString()}),
                Colors.green),
            const SizedBox(width: 12),
            _summaryCard(loc.t('ptSession.sum.noshow'),
                loc.t('ptSession.count', params: {'n': noShowCount.toString()}),
                Colors.red),
            const Spacer(),
            FilterPill<int>(
              label: loc.t('ptSession.filter.trainer'),
              selectedLabel: _trainers.firstWhere(
                (t) => t['adminId'] == _filterTrainerId,
                orElse: () => {'adminName': loc.t('ptSession.filter.all')},
              )['adminName'] ?? loc.t('ptSession.filter.all'),
              isActive: _filterTrainerId != null,
              options: [
                (loc.t('ptSession.filter.all'), null),
                ..._trainers.map((t) => (t['adminName'] as String? ?? '', t['adminId'] as int?)),
              ],
              onSelected: (v) => setState(() => _filterTrainerId = v),
              activeColor: _primary,
            ),
          ]),
          const SizedBox(height: 16),

          // 세션 목록
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(loc.t('ptSession.empty'),
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
                      _th(loc.t('ptSession.col.time'), flex: 2),
                      _th(loc.t('ptSession.col.trainer'), flex: 2),
                      _th(loc.t('ptSession.col.member'), flex: 2),
                      _th(loc.t('ptSession.col.round'), flex: 1),
                      _th(loc.t('ptSession.col.status'), flex: 2),
                      _th(loc.t('ptSession.col.memo'), flex: 3),
                      _th(loc.t('ptSession.col.action'), flex: 2),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final s = _filtered[i];
                        final statusColor = _statusColor(s.status);
                        return Container(
                          color: s.status == 'COMPLETED'
                              ? Colors.green.withOpacity(0.04)
                              : s.status == 'NO_SHOW'
                                  ? Colors.red.withOpacity(0.04)
                                  : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(children: [
                              Expanded(flex: 2, child: Text(
                                '${s.startTime} ~ ${s.endTime}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              )),
                              Expanded(flex: 2, child: Text(s.trainerName ?? '-')),
                              Expanded(flex: 2, child: Row(children: [
                                if (s.photoUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundImage: NetworkImage(s.photoUrl!),
                                    ),
                                  ),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.memberName ?? '-',
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                    if (s.memberNo != null)
                                      Text(s.memberNo!,
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  ],
                                )),
                              ])),
                              Expanded(flex: 1, child: Text(
                                loc.t('ptSession.roundN', params: {'n': s.sessionNo.toString()}),
                                style: TextStyle(color: Colors.grey.shade600))),
                              Expanded(flex: 2, child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_statusLabel(loc, s.status),
                                    style: TextStyle(color: statusColor, fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              )),
                              Expanded(flex: 3, child: Text(
                                s.memo ?? '-',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              )),
                              Expanded(flex: 2, child: s.status == 'SCHEDULED'
                                  ? Row(children: [
                                      _actionBtn(loc.t('ptSession.btn.complete'), Colors.green,
                                          () => _updateStatus(s, 'COMPLETED')),
                                      const SizedBox(width: 4),
                                      _actionBtn(loc.t('ptSession.btn.noshow'), Colors.orange,
                                          () => _updateStatus(s, 'NO_SHOW')),
                                    ])
                                  : const SizedBox()),
                            ]),
                          ),
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

  Widget _summaryCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(color: color, fontSize: 11)),
      Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    ]),
  );

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(label,
        style: TextStyle(fontWeight: FontWeight.bold,
            color: Colors.grey.shade600, fontSize: 12)),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );

  Color _statusColor(String s) => switch (s) {
    'COMPLETED' => Colors.green,
    'CANCELLED' => Colors.grey,
    'NO_SHOW' => Colors.red,
    _ => Colors.blue,
  };

  String _statusLabel(LocaleProvider loc, String s) => switch (s) {
    'COMPLETED' => loc.t('pt.status.completed'),
    'CANCELLED' => loc.t('pt.status.cancelled'),
    'NO_SHOW' => loc.t('pt.status.noshow'),
    _ => loc.t('pt.status.scheduled'),
  };
}
