// 회원 상세 > 탭 7: 포인트 잔액 및 이력
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// ══════════════════════════════════════════════════════════════
// 탭 7: 포인트
// ══════════════════════════════════════════════════════════════
class MemberPointTab extends StatefulWidget {
  final int memberId;
  final String memberName;
  const MemberPointTab({required this.memberId, required this.memberName});

  @override
  State<MemberPointTab> createState() => _PointTabState();
}

class _PointTabState extends State<MemberPointTab> {
  int _balance = 0;
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getMemberPoint(widget.memberId);
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;
        final list = data['ledger'] as List? ?? [];
        _ledger = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, '${context.read<LocaleProvider>().t('common.loadFailed')}: $e');
      }
    }
  }

  Future<void> _adjust({required bool isEarn}) async {
    final loc = context.read<LocaleProvider>();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEarn ? loc.t('member.point.earnDialog') : loc.t('member.point.useDialog')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isEarn ? loc.t('member.point.amountLabelEarn') : loc.t('member.point.amountLabelUse'),
                  border: const OutlineInputBorder(),
                  suffixText: 'P',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: loc.t('member.point.reason'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEarn ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isEarn ? loc.t('member.point.earn') : loc.t('member.point.use')),
          ),
        ],
      ),
    );
    if (result != true) return;

    final raw = int.tryParse(amountCtrl.text.trim());
    if (raw == null || raw <= 0) {
      if (mounted) showErrorSnack(context, loc.t('member.point.invalidAmount'));
      return;
    }
    final amount = isEarn ? raw : -raw;
    final desc = descCtrl.text.trim();
    if (desc.isEmpty) {
      if (mounted) showErrorSnack(context, loc.t('member.point.reasonRequired'));
      return;
    }

    try {
      await context.read<ApiService>().adjustPoint(widget.memberId, amount, desc);
      if (mounted) {
        showSuccessSnack(context, loc.t('member.point.done'));
        await _load();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '${loc.t('member.point.fail')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final loc = context.watch<LocaleProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.stars, color: Colors.orange, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('member.point.balance', params: {'name': widget.memberName}),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${_fmtNumber(_balance)} P',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _adjust(isEarn: true),
                  icon: const Icon(Icons.add),
                  label: Text(loc.t('member.point.earn')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _adjust(isEarn: false),
                  icon: const Icon(Icons.remove),
                  label: Text(loc.t('member.point.use')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text(loc.t('member.point.history'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: _ledger.isEmpty
                  ? Center(
                      child: Text(loc.t('member.point.noHistory'),
                          style: const TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _ledger.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = _ledger[i];
                        final amount = (e['pointAmount'] as num?)?.toInt() ?? 0;
                        final isEarn = amount >= 0;
                        final type = e['pointType'] ?? '';
                        final source = e['sourceType'] ?? '';
                        final desc = e['description'] ?? '';
                        final balanceAfter = (e['balanceAfter'] as num?)?.toInt() ?? 0;
                        final createdAt = e['createdAt'] ?? '';
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isEarn ? Colors.green : Colors.red).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEarn ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isEarn ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Row(children: [
                            _typeBadge(loc, type, source),
                            const SizedBox(width: 8),
                            Expanded(child: Text(desc.toString(),
                                overflow: TextOverflow.ellipsis)),
                          ]),
                          subtitle: Text(_fmtDate(createdAt.toString()),
                              style: const TextStyle(fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isEarn ? '+' : ''}${_fmtNumber(amount)} P',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isEarn ? Colors.green : Colors.red,
                                ),
                              ),
                              Text('${loc.t('member.point.balanceAfter')} ${_fmtNumber(balanceAfter)}P',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(LocaleProvider loc, String type, String source) {
    Color c;
    String label;
    if (source == 'TICKET_SALE') { c = Colors.blue; label = loc.t('member.point.badge.ticketSale'); }
    else if (source == 'MANUAL') { c = type == 'EARN' ? Colors.green : Colors.red; label = loc.t('member.point.badge.manual'); }
    else if (type == 'USE') { c = Colors.orange; label = loc.t('member.point.badge.use'); }
    else { c = Colors.grey; label = type; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _fmtNumber(int n) {
    final neg = n < 0;
    final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return neg ? '-$s' : s;
  }

  String _fmtDate(String s) {
    if (s.isEmpty) return '-';
    if (s.length >= 19) return s.substring(0, 16).replaceAll('T', ' ');
    return s;
  }
}
