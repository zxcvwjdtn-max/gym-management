import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});
  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _messageCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<MemberModel> _members = [];
  List<MemberModel> _filtered = [];
  Set<int> _selected = {};
  bool _sendAll = false;
  bool _loading = false;
  bool _membersLoading = true;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadTemplates();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final list = await context.read<ApiService>().getMembers();
      if (mounted) setState(() { _members = list; _filtered = list; _membersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await context.read<ApiService>().getNotificationTemplates();
      if (mounted) setState(() => _templates = list);
    } catch (_) {}
  }

  void _filterMembers(String keyword) {
    setState(() {
      _filtered = _members.where((m) =>
        m.memberName.contains(keyword) || m.memberNo.contains(keyword) ||
        (m.phone?.contains(keyword) ?? false)
      ).toList();
    });
  }

  Future<void> _send() async {
    final loc = context.read<LocaleProvider>();
    if (_messageCtrl.text.trim().isEmpty) {
      showErrorSnack(context, loc.t('noti.send.err.empty'));
      return;
    }
    if (!_sendAll && _selected.isEmpty) {
      showErrorSnack(context, loc.t('noti.send.err.noRecipient'));
      return;
    }

    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'customContent': _messageCtrl.text,
        if (!_sendAll) 'memberIds': _selected.toList(),
      };
      await context.read<ApiService>().sendNotification(body);
      if (mounted) {
        showSuccessSnack(context, loc.t('noti.send.success'));
        _messageCtrl.clear();
        setState(() { _selected.clear(); _sendAll = false; });
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, loc.t('noti.send.fail', params: {'e': e.toString()}));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(loc.t('noti.send.recipients'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Checkbox(value: _sendAll, onChanged: (v) => setState(() {
                        _sendAll = v!;
                        if (_sendAll) _selected.clear();
                      })),
                      Text(loc.t('noti.send.all')),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: loc.t('noti.send.searchHint'),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: _filterMembers,
                      enabled: !_sendAll,
                    ),
                    const SizedBox(height: 10),
                    Text(loc.t('noti.send.selectedN', params: {'n': _selected.length.toString()}),
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _membersLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (context, i) {
                                final m = _filtered[i];
                                final isSelected = _selected.contains(m.memberId);
                                return CheckboxListTile(
                                  value: _sendAll || isSelected,
                                  enabled: !_sendAll,
                                  dense: true,
                                  title: Text(m.memberName,
                                    style: const TextStyle(fontSize: 13)),
                                  subtitle: Text('${m.memberNo} | ${m.phone ?? '-'}',
                                    style: const TextStyle(fontSize: 11)),
                                  onChanged: (_) {
                                    setState(() {
                                      if (isSelected) _selected.remove(m.memberId);
                                      else if (m.memberId != null) _selected.add(m.memberId!);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.t('noti.send.compose'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (_templates.isNotEmpty) ...[
                          Text(loc.t('noti.send.template'),
                            style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _templates.map((t) => OutlinedButton(
                              onPressed: () => setState(() =>
                                  _messageCtrl.text = t['content'] ?? ''),
                              child: Text(t['templateName'] ?? '', style: const TextStyle(fontSize: 12)),
                            )).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: _messageCtrl,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: loc.t('noti.send.placeholder'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _send,
                            icon: _loading
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send),
                            label: Text(_sendAll
                                ? loc.t('noti.send.all')
                                : loc.t('noti.send.sendToN', params: {'n': _selected.length.toString()})),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
