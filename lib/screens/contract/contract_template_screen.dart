import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

void _err(BuildContext ctx, Object e) =>
    showErrorSnack(ctx, e.toString().replaceAll('Exception: ', ''));
void _ok(BuildContext ctx, String msg) => showSuccessSnack(ctx, msg);

// 새 템플릿 생성 시 기본으로 채워지는 입회원서 내용
const _defaultTemplateContent = '''입 회 원 서

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

본 계약은 아래 당사자 간에 체결됩니다.

  甲 (센터)  :  {{체육관명}}
  乙 (회원)  :  {{이름}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

■ 이용 약관

제1조 (목적)
본 계약은 회원이 체육관(이하 "센터")의 시설 및 서비스를 이용하는 데 필요한 사항을 규정함을 목적으로 합니다.

제2조 (회원의 의무)
1. 회원은 센터의 규정과 직원의 안내에 따라야 합니다.
2. 회원은 타 회원에게 불편을 주는 행위를 하여서는 안 됩니다.
3. 회원은 센터 기구 및 시설을 안전하게 사용하여야 합니다.
4. 운동 전 건강 상태를 확인하고, 이상 발생 시 즉시 운동을 중단하여야 합니다.

제3조 (개인정보 수집 및 이용 동의)
센터는 원활한 서비스 제공을 위해 아래 개인정보를 수집·이용합니다.
- 수집 항목: 성명, 연락처, 생년월일, 이메일, 주소
- 수집 목적: 회원 관리 및 서비스 제공
- 보유 기간: 계약 종료 후 1년

제4조 (안전 수칙)
1. 기구 사용 전 반드시 사용 방법을 숙지하세요.
2. 과도한 중량이나 무리한 동작은 삼가 주세요.
3. 응급 상황 발생 시 즉시 직원에게 알려주세요.
4. 귀중품은 반드시 개인이 보관하여 주세요.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

※ 기타 안내 사항
(센터의 추가 안내 사항을 이곳에 직접 입력하세요.)''';

// 지원 플레이스홀더 목록
const _placeholders = [
  ('{{체육관명}}',       '체육관 이름'),
  ('{{이름}}',          '회원 성명'),
  ('{{생년월일}}',       '생년월일'),
  ('{{전화번호}}',       '회원 연락처'),
  ('{{보호자전화번호}}', '보호자 연락처(미성년자)'),
  ('{{주소}}',           '주소'),
  ('{{입관시작일}}',     '입관 시작일'),
  ('{{이메일}}',         '이메일'),
];

class ContractTemplateScreen extends StatefulWidget {
  const ContractTemplateScreen({super.key});
  @override
  State<ContractTemplateScreen> createState() => _ContractTemplateScreenState();
}

class _ContractTemplateScreenState extends State<ContractTemplateScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  Map<String, dynamic>? _editing;
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

  void _openNew() => setState(() {
    _editing = {'templateName': '', 'content': _defaultTemplateContent};
    _isNew = true;
  });
  void _openEdit(Map<String, dynamic> t) => setState(() { _editing = Map.from(t); _isNew = false; });
  void _cancelEdit() => setState(() { _editing = null; });

  Future<void> _save() async {
    if (_editing == null) return;
    final name    = _editing!['templateName'] as String? ?? '';
    final content = _editing!['content'] as String? ?? '';
    if (name.trim().isEmpty)    { _err(context, '템플릿 이름을 입력하세요.'); return; }
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
    if (ok != true || !mounted) return;
    try {
      final api = context.read<ApiService>();
      await api.deleteContractTemplate(id);
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

  void _showPreview(String content, String templateName) {
    showDialog(
      context: context,
      builder: (_) => _ContractPreviewDialog(
        content: content,
        templateName: templateName.isEmpty ? '입회계약서' : templateName,
      ),
    );
  }

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
          Flexible(child: Text('계약서 발송 — ${template['templateName']}')),
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
                final api = context.read<ApiService>();
                await api.sendContract({
                  'templateId': template['templateId'],
                  'name':  nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                });
                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                _ok(context, '계약서 링크가 발송되었습니다.');
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
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.teal),
                          tooltip: '미리보기',
                          onPressed: () => _showPreview(
                            t['content'] as String? ?? '',
                            t['templateName'] as String? ?? '',
                          ),
                        ),
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
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('기본 양식 불러오기'),
                  content: const Text('현재 내용이 기본 양식으로 교체됩니다.\n계속하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('교체'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                contentCtrl.text = _defaultTemplateContent;
              }
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('기본 양식'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showPreview(contentCtrl.text, nameCtrl.text),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('미리보기'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.teal),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              _editing!['templateName'] = nameCtrl.text;
              _editing!['content']      = contentCtrl.text;
              _save();
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('저장'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 16),

        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '템플릿 이름 *',
            border: OutlineInputBorder(),
            hintText: '예: 헬스장 입회계약서'),
        ),
        const SizedBox(height: 12),

        _PlaceholderHelpPanel(contentCtrl: contentCtrl),
        const SizedBox(height: 12),

        Expanded(
          child: TextField(
            controller: contentCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: '계약서 내용 *',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── 계약서 미리보기 다이얼로그 ───────────────────────────────────────

class _ContractPreviewDialog extends StatelessWidget {
  final String content;
  final String templateName;

  const _ContractPreviewDialog({required this.content, required this.templateName});

  static const _tagColor = Color(0xFF1565C0);
  static const _tagBg    = Color(0xFFE3F0FF);

  @override
  Widget build(BuildContext context) {
    const cardDecor = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
    );

    return Dialog(
      backgroundColor: const Color(0xFFF5F5F5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 880),
        child: Column(children: [
          // 다이얼로그 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text('계약서 미리보기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          // 스크롤 본문 (실제 HTML 페이지 구조와 동일)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // Card 1: 헤더 + 계약서 내용 (실제: #headerCard)
                Container(
                  decoration: cardDecor,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // doc-header
                    Column(children: [
                      const Text('헬스장', style: TextStyle(
                        fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(templateName, style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111111),
                        letterSpacing: 6)),
                    ]),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(thickness: 2, color: Color(0xFFE0E0E0)),
                    ),
                    // 계약서 내용
                    _richContent(content),
                  ]),
                ),

                // Card 2: 개인정보 입력 (실제: #formCard)
                Container(
                  decoration: cardDecor,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('개인정보 입력',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                    const SizedBox(height: 14),
                    ...[
                      ('성명 *', '이름을 입력하세요'),
                      ('연락처 *', '010-0000-0000'),
                      ('생년월일', 'YYYYMMDD (예: 19900101)'),
                      ('주소 *', '도로명 주소를 입력하세요'),
                      ('보호자 연락처', '010-0000-0000'),
                      ('입관 시작일 *', '날짜 선택'),
                      ('이메일', 'email@example.com'),
                    ].map((f) {
                      final (label, hint) = f;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label, style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFDDDDDD)),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFAFAFA),
                            ),
                            child: Text(hint,
                              style: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA))),
                          ),
                        ]),
                      );
                    }),
                  ]),
                ),

                // Card 3: 서명 (실제: canvas card)
                Container(
                  decoration: cardDecor,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('서명', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('지우기', style: TextStyle(fontSize: 11, color: Color(0xFF555555))),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border.all(color: const Color(0xFFBBBBBB), width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text('서명란', style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
                    ),
                  ]),
                ),

                // Card 4: 동의 체크박스 + 제출 버튼 (실제: agree card)
                Container(
                  decoration: cardDecor,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFBBBBBB)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('위 계약서 내용을 모두 읽고 동의합니다.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF444444))),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('계약서 제출',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          // 닫기 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _richContent(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\{\{[^}]+\}\}');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: const TextStyle(fontSize: 13.5, height: 1.8, color: Colors.black87),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 13.5, height: 1.8,
          color: _tagColor,
          backgroundColor: _tagBg,
          fontWeight: FontWeight.w600,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(fontSize: 13.5, height: 1.8, color: Colors.black87),
      ));
    }
    return SelectableText.rich(TextSpan(children: spans));
  }
}

// ── 플레이스홀더 도움말 패널 ─────────────────────────────────────────

class _PlaceholderHelpPanel extends StatefulWidget {
  final TextEditingController contentCtrl;
  const _PlaceholderHelpPanel({required this.contentCtrl});

  @override
  State<_PlaceholderHelpPanel> createState() => _PlaceholderHelpPanelState();
}

class _PlaceholderHelpPanelState extends State<_PlaceholderHelpPanel> {
  bool _expanded = false;

  void _insert(String tag) {
    final ctrl  = widget.contentCtrl;
    final sel   = ctrl.selection;
    final text  = ctrl.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end   = sel.end   < 0 ? text.length : sel.end;
    final newText = text.replaceRange(start, end, tag);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBD6F5)),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.label_outline, size: 16, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              const Text('플레이스홀더 — 회원 입력값으로 자동 치환됩니다',
                style: TextStyle(fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: const Color(0xFF1565C0)),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: Color(0xFFBBD6F5)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _placeholders.map((p) {
                final (tag, label) = p;
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: Text('$tag  $label', style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  onPressed: () => _insert(tag),
                  tooltip: '클릭하면 커서 위치에 삽입',
                );
              }).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: 10),
            child: Row(children: [
              Icon(Icons.info_outline, size: 13, color: Colors.grey),
              SizedBox(width: 4),
              Flexible(child: Text(
                '칩을 클릭하면 편집기 커서 위치에 삽입됩니다. 회원이 계약서를 제출하면 실제 입력값으로 교체됩니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}
