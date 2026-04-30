import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

void _err(BuildContext ctx, Object e) =>
    showErrorSnack(ctx, e.toString().replaceAll('Exception: ', ''));
void _ok(BuildContext ctx, String msg) => showSuccessSnack(ctx, msg);

class ContractTemplateScreen extends StatefulWidget {
  const ContractTemplateScreen({super.key});
  @override
  State<ContractTemplateScreen> createState() => _ContractTemplateScreenState();
}

class _ContractTemplateScreenState extends State<ContractTemplateScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  Map<String, dynamic>? _editing; // null이면 목록, 아니면 편집 중
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getContractTemplates();
      if (mounted) setState(() { _templates = list; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _err(context, e); }
    }
  }

  void _openNew() => setState(() { _editing = {'templateName': '', 'content': ''}; _isNew = true; });
  void _openEdit(Map<String, dynamic> t) => setState(() { _editing = Map.from(t); _isNew = false; });
  void _cancelEdit() => setState(() { _editing = null; });

  Future<void> _save() async {
    if (_editing == null) return;
    final name = _editing!['templateName'] as String? ?? '';
    final content = _editing!['content'] as String? ?? '';
    if (name.trim().isEmpty) { _err(context, '템플릿 이름을 입력하세요.'); return; }
    if (content.trim().isEmpty) { _err(context, '계약서 내용을 입력하세요.'); return; }
    try {
      final api = context.read<ApiService>();
      if (_isNew) {
        await api.createContractTemplate({'templateName': name, 'content': content});
      } else {
        await api.updateContractTemplate(_editing!['templateId'], {'templateName': name, 'content': content});
      }
      setState(() => _editing = null);
      _load();
      if (mounted) _ok(context, '저장되었습니다.');
    } catch (e) { if (mounted) _err(context, e); }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('삭제 확인'),
      content: const Text('이 템플릿을 삭제하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('삭제')),
      ],
    ));
    if (ok != true) return;
    try {
      await context.read<ApiService>().deleteContractTemplate(id);
      _load();
    } catch (e) { if (mounted) _err(context, e); }
  }

  Future<void> _activate(int id) async {
    try {
      await context.read<ApiService>().activateContractTemplate(id);
      _load();
      if (mounted) _ok(context, '대표 템플릿으로 설정되었습니다.');
    } catch (e) { if (mounted) _err(context, e); }
  }

  // 발송 다이얼로그
  Future<void> _showSendDialog(Map<String, dynamic> template) async {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool sending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.send, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 8),
          Text('계약서 발송 — ${template['templateName']}'),
        ]),
        content: SizedBox(width: 400, child: Form(key: formKey, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('입력한 전화번호로 전자계약서 링크를 발송합니다.',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextFormField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: '성명 *', border: OutlineInputBorder()),
              validator: (v) => (v?.trim().isEmpty ?? true) ? '성명을 입력하세요' : null),
            const SizedBox(height: 12),
            TextFormField(controller: phoneCtrl,
              decoration: const InputDecoration(labelText: '연락처 *', border: OutlineInputBorder(), hintText: '01012345678'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v?.trim().isEmpty ?? true) ? '연락처를 입력하세요' : null),
            const SizedBox(height: 12),
            TextFormField(controller: emailCtrl,
              decoration: const InputDecoration(labelText: '이메일 (선택)', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton.icon(
            onPressed: sending ? null : () async {
              if (!formKey.currentState!.validate()) return;
              ss(() => sending = true);
              try {
                await context.read<ApiService>().sendContract({
                  'templateId': template['templateId'],
                  'name':  nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _ok(context, '계약서 링크가 발송되었습니다.');
                }
              } catch (e) {
                ss(() => sending = false);
                if (mounted) _err(context, e);
              }
            },
            icon: sending
              ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              : const Icon(Icons.send, size: 16),
            label: const Text('발송'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editing != null) return _buildEditor();
    return _buildList();
  }

  Widget _buildList() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('계약서 템플릿', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _openNew,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('새 템플릿'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('계약서 내용을 미리 작성해두고, 회원에게 링크로 발송하세요.',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 20),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_templates.isEmpty)
          const Expanded(child: Center(child: Text('등록된 템플릿이 없습니다. 새 템플릿을 만들어 주세요.',
            style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (_, i) {
                final t = _templates[i];
                final isActive = t['isActive'] == 'Y';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isActive ? const BorderSide(color: Color(0xFF1565C0), width: 2) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (isActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('대표', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: Text(t['templateName'] ?? '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                        if (!isActive)
                          TextButton(onPressed: () => _activate(t['templateId']),
                            child: const Text('대표 설정')),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _openEdit(t)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _delete(t['templateId'])),
                        ElevatedButton.icon(
                          onPressed: () => _showSendDialog(t),
                          icon: const Icon(Icons.send, size: 14),
                          label: const Text('발송'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        (t['content'] as String? ?? '').length > 120
                          ? '${(t['content'] as String).substring(0, 120)}…'
                          : (t['content'] as String? ?? ''),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildEditor() {
    final nameCtrl    = TextEditingController(text: _editing!['templateName'] as String? ?? '');
    final contentCtrl = TextEditingController(text: _editing!['content'] as String? ?? '');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: _cancelEdit),
          const SizedBox(width: 8),
          Text(_isNew ? '새 계약서 템플릿' : '템플릿 수정',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              _editing!['templateName'] = nameCtrl.text;
              _editing!['content'] = contentCtrl.text;
              _save();
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 20),
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '템플릿 이름 *',
            border: OutlineInputBorder(),
            hintText: '예: 헬스장 입회계약서'),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: contentCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              labelText: '계약서 내용 *',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              hintText: '계약서 내용을 입력하세요.\n\n예:\n제1조 (계약 목적)\n본 계약은 ...',
            ),
          ),
        ),
      ]),
    );
  }
}
