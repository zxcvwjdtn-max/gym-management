import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class BulkExtendScreen extends StatefulWidget {
  const BulkExtendScreen({super.key});
  @override
  State<BulkExtendScreen> createState() => _BulkExtendScreenState();
}

class _BulkExtendScreenState extends State<BulkExtendScreen> {
  List<MemberModel> _members = [];
  bool _loading = true;
  final Set<int> _selectedMemberIds = {};
  bool _selectAll = false;
  final _daysCtrl = TextEditingController(text: '7');
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getMembers();
      if (mounted) setState(() { _members = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bulkExtend() async {
    final loc = context.read<LocaleProvider>();
    final days = int.tryParse(_daysCtrl.text);
    if (days == null || days <= 0) {
      showErrorSnack(context, loc.t('center.bulkExtend.errDays'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('center.bulkExtend.confirmTitle')),
        content: Text(_selectAll
            ? loc.t('center.bulkExtend.confirmAll', params: {'d': days.toString()})
            : loc.t('center.bulkExtend.confirmSel',
                params: {'n': _selectedMemberIds.length.toString(), 'd': days.toString()})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(loc.t('center.bulkExtend.btnConfirm'),
              style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      if (_selectAll) {
        await context.read<ApiService>().bulkExtend(days);
      } else {
        for (final memberId in _selectedMemberIds) {
          final memberships = await context.read<ApiService>().getMemberships(memberId);
          final active = memberships.where((m) => m.status == 'ACTIVE' || m.status == 'EXPIRING_SOON').toList();
          for (final ms in active) {
            await context.read<ApiService>().extendMembership(ms.membershipId!, days);
          }
        }
      }
      if (mounted) {
        showSuccessSnack(context,
          loc.t('center.bulkExtend.success', params: {'d': days.toString()}));
        setState(() { _selectedMemberIds.clear(); _selectAll = false; });
      }
    } catch (e) {
      if (mounted) showErrorSnack(context,
        loc.t('center.bulkExtend.fail', params: {'e': e.toString()}));
    } finally {
      if (mounted) setState(() => _processing = false);
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
          Text(loc.t('center.bulkExtend.title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.date_range, color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(loc.t('center.bulkExtend.setLabel'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(_selectAll
                        ? loc.t('center.bulkExtend.allDesc')
                        : loc.t('center.bulkExtend.selectedDesc',
                            params: {'n': _selectedMemberIds.length.toString()}),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _daysCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: loc.t('center.bulkExtend.daysLabel'),
                      border: const OutlineInputBorder(),
                      suffixText: loc.t('center.bulkExtend.daysSuffix'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (v) => setState(() {
                      _selectAll = v!;
                      if (_selectAll) _selectedMemberIds.clear();
                    }),
                  ),
                  Text(loc.t('center.bulkExtend.allCheck')),
                ]),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _processing ? null : _bulkExtend,
                  icon: _processing
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.update),
                  label: Text(loc.t('center.bulkExtend.btn')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Column(children: [
                        Container(
                          color: Colors.grey.shade100,
                          child: Row(children: [
                            SizedBox(
                              width: 50,
                              child: Checkbox(
                                tristate: true,
                                value: _selectedMemberIds.length == _members.length
                                    ? true
                                    : _selectedMemberIds.isEmpty ? false : null,
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selectedMemberIds.addAll(
                                        _members.where((m) => m.memberId != null).map((m) => m.memberId!));
                                  } else {
                                    _selectedMemberIds.clear();
                                  }
                                }),
                              ),
                            ),
                            Text(loc.t('center.bulkExtend.col.memberNo'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            Text(loc.t('center.bulkExtend.col.name'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            Text(loc.t('center.bulkExtend.col.ticket'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            Text(loc.t('center.bulkExtend.col.endDate'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 20),
                            Text(loc.t('center.bulkExtend.col.status'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ].map((w) => Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: w,
                          ))).toList()),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _members.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final m = _members[i];
                              final isSelected = _selectedMemberIds.contains(m.memberId);
                              return InkWell(
                                onTap: () => setState(() {
                                  if (m.memberId == null) return;
                                  if (isSelected) _selectedMemberIds.remove(m.memberId);
                                  else _selectedMemberIds.add(m.memberId!);
                                }),
                                child: Row(children: [
                                  SizedBox(
                                    width: 50,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => setState(() {
                                        if (m.memberId == null) return;
                                        if (isSelected) _selectedMemberIds.remove(m.memberId);
                                        else _selectedMemberIds.add(m.memberId!);
                                      }),
                                    ),
                                  ),
                                  Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Text(m.memberNo))),
                                  Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Text(m.memberName, style: const TextStyle(fontWeight: FontWeight.w600)))),
                                  Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Text(m.ticketName ?? '-'))),
                                  Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Text(m.membershipEndDate ?? '-'))),
                                  Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: _badge(loc, m.membershipStatus))),
                                ]),
                              );
                            },
                          ),
                        ),
                      ]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badge(LocaleProvider loc, String? status) {
    Color c;
    String label;
    switch (status) {
      case 'ACTIVE': c = Colors.green; label = loc.t('center.bulkExtend.status.active'); break;
      case 'EXPIRING_SOON': c = Colors.orange; label = loc.t('center.bulkExtend.status.expiring'); break;
      case 'EXPIRED': c = Colors.red; label = loc.t('center.bulkExtend.status.expired'); break;
      default: c = Colors.grey; label = status ?? '-'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
