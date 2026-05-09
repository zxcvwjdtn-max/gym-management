// 회원 상세 > 탭 8: 상담 내역 목록 및 등록/수정 다이얼로그
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// ──────────────────────────────────────────────────────────────
// 탭 8: 상담 내역
// ──────────────────────────────────────────────────────────────
class MemberConsultationTab extends StatefulWidget {
  final int memberId;
  const MemberConsultationTab({required this.memberId});

  @override
  State<MemberConsultationTab> createState() => _ConsultationTabState();
}

class _ConsultationTabState extends State<MemberConsultationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<ConsultationModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getConsultations(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog({ConsultationModel? existing}) {
    showDialog(
      context: context,
      builder: (_) => _ConsultationDialog(
        memberId: widget.memberId,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(ConsultationModel c) async {
    final loc = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('member.consult.delete.title')),
        content: Text(loc.t('member.consult.delete.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteConsultation(c.consultationId!);
      _load();
    } catch (e) {
      if (mounted) showErrorSnack(context,
          loc.t('member.consult.delete.fail', params: {'e': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = context.watch<LocaleProvider>();
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Text(loc.t('member.consult.header', params: {'n': _list.length.toString()}),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: Text(loc.t('member.consult.add')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),
        Expanded(
          child: _list.isEmpty
              ? Center(child: Text(loc.t('member.consult.empty'),
                  style: const TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = _list[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4, offset: const Offset(0, 2),
                        )],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 16, color: Colors.blue.shade400),
                            const SizedBox(width: 6),
                            Text(c.consultDate ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const Spacer(),
                            if (c.createdBy != null)
                              Text(c.createdBy!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade500)),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showAddDialog(existing: c),
                              child: Icon(Icons.edit_outlined,
                                  size: 18, color: Colors.grey.shade500),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _delete(c),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red.shade300),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(c.content ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.5)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── 상담 등록/수정 다이얼로그 ────────────────────────────────────
class _ConsultationDialog extends StatefulWidget {
  final int memberId;
  final ConsultationModel? existing;
  final VoidCallback onSaved;
  const _ConsultationDialog({
    required this.memberId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_ConsultationDialog> createState() => _ConsultationDialogState();
}

class _ConsultationDialogState extends State<_ConsultationDialog> {
  late DateTime _date;
  late TextEditingController _contentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final d = DateTime.tryParse(widget.existing!.consultDate ?? '');
      _date = d ?? DateTime.now();
      _contentCtrl = TextEditingController(text: widget.existing!.content ?? '');
    } else {
      _date = DateTime.now();
      _contentCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(LocaleProvider loc) async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      showErrorSnack(context, loc.t('member.consult.dialog.contentRequired'));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'memberId': widget.memberId,
        'consultDate': _fmt(_date),
        'content': content,
      };
      if (widget.existing != null) {
        await context.read<ApiService>()
            .updateConsultation(widget.existing!.consultationId!, body);
      } else {
        await context.read<ApiService>().createConsultation(body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context,
          loc.t('member.consult.dialog.saveFail', params: {'e': e.toString()}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return AlertDialog(
      title: Text(widget.existing != null
          ? loc.t('member.consult.dialog.edit')
          : loc.t('member.consult.dialog.add')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상담일 달력 선택
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: loc.t('member.consult.dialog.date'),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_fmt(_date),
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: loc.t('member.consult.dialog.content'),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(loc),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(loc.t('common.save')),
        ),
      ],
    );
  }
}
