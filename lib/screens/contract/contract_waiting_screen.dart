import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

void _err(BuildContext ctx, Object e) =>
    showErrorSnack(ctx, e.toString().replaceAll('Exception: ', ''));
void _ok(BuildContext ctx, String msg) => showSuccessSnack(ctx, msg);

class ContractWaitingScreen extends StatefulWidget {
  const ContractWaitingScreen({super.key});
  @override
  State<ContractWaitingScreen> createState() => _ContractWaitingScreenState();
}

class _ContractWaitingScreenState extends State<ContractWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getPendingContracts(),
        api.getAllContracts(),
      ]);
      if (mounted) {
        setState(() {
          _pending = results[0];
          _all = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _err(context, e); }
    }
  }

  Future<void> _confirm(Map<String, dynamic> app) async {
    final email = app['applicantEmail'] as String?;
    final hasEmail = email != null && email.isNotEmpty;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('계약서 확인'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${app['applicantName']} 님의 계약서를 확인 처리합니다.'),
        const SizedBox(height: 8),
        const Text('• PDF 파일이 생성되어 서버에 저장됩니다.',
          style: TextStyle(fontSize: 13, color: Colors.grey)),
        if (hasEmail)
          Text('• $email 로 계약서 PDF가 이메일 발송됩니다.',
            style: const TextStyle(fontSize: 13, color: Colors.teal))
        else
          const Text('• 이메일 미입력 — 이메일 발송 없음.',
            style: TextStyle(fontSize: 13, color: Colors.orange)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          child: const Text('확인'),
        ),
      ],
    ));
    if (ok != true || !mounted) return;

    try {
      await context.read<ApiService>().confirmContract(app['applicationId']);
      if (!mounted) return;
      _load();
      // 계약서 확인 완료 후 회원 등록 다이얼로그 표시
      final registered = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MemberRegisterDialog(app: app),
      );
      if (!mounted) return;
      if (registered == true) {
        _ok(context, '확인 완료 및 회원 등록이 완료되었습니다.');
      } else {
        _ok(context, '확인 처리 완료. PDF가 생성되었습니다.');
      }
    } catch (e) { if (mounted) _err(context, e); }
  }

  Future<void> _delete(Map<String, dynamic> app) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('삭제 확인'),
      content: Text('${app['applicantName']} 님의 계약 신청을 삭제하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('삭제')),
      ],
    ));
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteContract(app['applicationId']);
      if (mounted) _load();
    } catch (e) { if (mounted) _err(context, e); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('입회 대기', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          if (_pending.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
              child: Text('${_pending.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ]),
        const SizedBox(height: 4),
        const Text('회원이 제출한 전자계약서 확인 목록입니다. 확인 시 PDF가 생성되고 이메일로 발송됩니다.',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '미확인 (${_pending.length})'),
            Tab(text: '전체 (${_all.length})'),
          ],
          labelColor: const Color(0xFF1565C0),
          indicatorColor: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(child: TabBarView(controller: _tab, children: [
            _buildList(_pending, showConfirm: true),
            _buildList(_all, showConfirm: false),
          ])),
      ]),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, {required bool showConfirm}) {
    if (list.isEmpty) {
      return const Center(child: Text('내역이 없습니다.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => _buildCard(list[i], showConfirm: showConfirm),
    );
  }

  void _showDetail(Map<String, dynamic> app) {
    showDialog(context: context, builder: (_) => _ContractDetailDialog(app: app));
  }

  Widget _buildCard(Map<String, dynamic> app, {required bool showConfirm}) {
    final isConfirmed = app['confirmedYn'] == 'Y';
    final isSubmitted = app['submittedYn'] == 'Y';
    final email = app['applicantEmail'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(app),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statusBadge(isConfirmed, isSubmitted),
              const SizedBox(width: 10),
              Expanded(child: Text(app['applicantName'] ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              if (showConfirm && isSubmitted && !isConfirmed)
                ElevatedButton(
                  onPressed: () => _confirm(app),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
                  child: const Text('확인'),
                ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () => _delete(app)),
            ]),
            const SizedBox(height: 8),
            _infoRow(Icons.phone, app['applicantPhone'] ?? ''),
            if (email.isNotEmpty) _infoRow(Icons.email_outlined, email),
            if ((app['applicantBirth'] as String? ?? '').isNotEmpty)
              _infoRow(Icons.cake_outlined, app['applicantBirth'] ?? ''),
            _infoRow(Icons.description_outlined, app['templateName'] ?? '계약서'),
            const SizedBox(height: 6),
            Row(children: [
              if (app['submittedAt'] != null)
                Text('제출: ${_fmtDate(app['submittedAt'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (app['confirmedAt'] != null) ...[
                const Text('  ·  ', style: TextStyle(color: Colors.grey)),
                Text('확인: ${_fmtDate(app['confirmedAt'])}  (확인자: ${app['confirmedBy'] ?? ''})',
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ]),
            if (app['pdfPath'] != null)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('PDF: ${app['pdfPath']}',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  overflow: TextOverflow.ellipsis)),
            Align(
              alignment: Alignment.centerRight,
              child: Text('탭하여 내용 보기',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statusBadge(bool confirmed, bool submitted) {
    if (confirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
        child: const Text('확인완료', style: TextStyle(color: Colors.white, fontSize: 11)),
      );
    }
    if (submitted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
        child: const Text('대기중', style: TextStyle(color: Colors.white, fontSize: 11)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(12)),
      child: const Text('미제출', style: TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ]),
  );

  String _fmtDate(String? dt) {
    if (dt == null || dt.isEmpty) return '';
    return dt.length > 16 ? dt.substring(0, 16).replaceAll('T', ' ') : dt;
  }
}

// ── 계약서 확인 후 회원 등록 다이얼로그 ──────────────────────────────

class _MemberRegisterDialog extends StatefulWidget {
  final Map<String, dynamic> app;
  const _MemberRegisterDialog({required this.app});

  @override
  State<_MemberRegisterDialog> createState() => _MemberRegisterDialogState();
}

class _MemberRegisterDialogState extends State<_MemberRegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _memberNoCtrl   = TextEditingController();
  final _nameCtrl       = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _birthCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _joinDateCtrl   = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = widget.app;
    _nameCtrl.text        = app['applicantName'] as String? ?? '';
    _phoneCtrl.text       = app['applicantPhone'] as String? ?? '';
    _emailCtrl.text       = app['applicantEmail'] as String? ?? '';
    _addressCtrl.text     = app['applicantAddress'] as String? ?? '';
    _parentPhoneCtrl.text = app['parentPhone'] as String? ?? '';

    // 생년월일: YYYYMMDD → YYYY-MM-DD 변환
    final birth = app['applicantBirth'] as String? ?? '';
    if (birth.length == 8 && !birth.contains('-')) {
      _birthCtrl.text = '${birth.substring(0, 4)}-${birth.substring(4, 6)}-${birth.substring(6, 8)}';
    } else {
      _birthCtrl.text = birth;
    }

    // 입관 시작일 → 가입일
    _joinDateCtrl.text = app['memberStartDate'] as String? ?? '';

    // 회원번호 자동 제안: 전화번호 뒷 4자리
    final phone = _phoneCtrl.text;
    if (phone.length >= 4) {
      _memberNoCtrl.text = phone.replaceAll('-', '').substring(
        phone.replaceAll('-', '').length - 4);
    }
  }

  @override
  void dispose() {
    _memberNoCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _birthCtrl.dispose();
    _addressCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _joinDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'memberNo':    _memberNoCtrl.text.trim(),
        'memberName':  _nameCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'birthDate':   _birthCtrl.text.trim(),
        'address':     _addressCtrl.text.trim(),
        'parentPhone': _parentPhoneCtrl.text.trim(),
        'joinDate':    _joinDateCtrl.text.trim(),
        'memberType':  'REGULAR',
        'smsYn':       'Y',
      };
      await context.read<ApiService>().createMember(body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorSnack(context, '회원 등록 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const inputDecor = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.person_add, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('회원 등록',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context, false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          // 안내
          Container(
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                '계약서 정보로 자동 입력되었습니다. 회원번호를 확인하고 등록하세요.',
                style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
              )),
            ]),
          ),

          // 폼
          Expanded(child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // 회원번호 (강조)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('회원번호 *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF1565C0))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _memberNoCtrl,
                      decoration: inputDecor.copyWith(
                        hintText: '회원번호 입력',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '회원번호를 입력해주세요.' : null,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                _field('성명 *', _nameCtrl, inputDecor,
                  validator: (v) => (v == null || v.trim().isEmpty) ? '성명을 입력해주세요.' : null),
                const SizedBox(height: 12),
                _field('연락처 *', _phoneCtrl, inputDecor,
                  hint: '010-0000-0000',
                  validator: (v) => (v == null || v.trim().isEmpty) ? '연락처를 입력해주세요.' : null),
                const SizedBox(height: 12),
                _field('생년월일', _birthCtrl, inputDecor, hint: 'YYYY-MM-DD'),
                const SizedBox(height: 12),
                _field('주소', _addressCtrl, inputDecor),
                const SizedBox(height: 12),
                _field('보호자 연락처', _parentPhoneCtrl, inputDecor, hint: '010-0000-0000'),
                const SizedBox(height: 12),
                _field('이메일', _emailCtrl, inputDecor, hint: 'email@example.com'),
                const SizedBox(height: 12),
                _field('가입일 (입관 시작일)', _joinDateCtrl, inputDecor, hint: 'YYYY-MM-DD'),
              ]),
            ),
          )),

          // 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('건너뛰기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _register,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add),
                  label: const Text('회원 등록'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, InputDecoration baseDecor,
      {String? hint, String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
        color: Color(0xFF555555))),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        decoration: baseDecor.copyWith(hintText: hint),
        validator: validator,
      ),
    ]);
  }
}

// ── 계약서 작성 내용 상세 다이얼로그 ─────────────────────────────────

class _ContractDetailDialog extends StatelessWidget {
  final Map<String, dynamic> app;
  const _ContractDetailDialog({required this.app});

  String _fmt(String? dt) {
    if (dt == null || dt.isEmpty) return '';
    return dt.length > 16 ? dt.substring(0, 16).replaceAll('T', ' ') : dt;
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = app['confirmedYn'] == 'Y';
    final sigData = app['signatureData'] as String?;
    final hasSig = sigData != null && sigData.startsWith('data:image');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 840),
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '${app['applicantName'] ?? ''} — ${app['templateName'] ?? '계약서'}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              )),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          // 본문 스크롤
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // 제출 정보
              _section('제출 정보', [
                _row('성명', app['applicantName']),
                _row('연락처', app['applicantPhone']),
                if ((app['applicantBirth'] as String? ?? '').isNotEmpty)
                  _row('생년월일', app['applicantBirth']),
                if ((app['applicantAddress'] as String? ?? '').isNotEmpty)
                  _row('주소', app['applicantAddress']),
                if ((app['parentPhone'] as String? ?? '').isNotEmpty)
                  _row('보호자 연락처', app['parentPhone']),
                if ((app['memberStartDate'] as String? ?? '').isNotEmpty)
                  _row('입관 시작일', app['memberStartDate']),
                if ((app['applicantEmail'] as String? ?? '').isNotEmpty)
                  _row('이메일', app['applicantEmail']),
              ]),
              const SizedBox(height: 16),

              // 처리 정보
              _section('처리 정보', [
                _row('제출일시', _fmt(app['submittedAt'] as String?)),
                if (isConfirmed) ...[
                  _row('확인일시', _fmt(app['confirmedAt'] as String?)),
                  _row('확인자', app['confirmedBy']),
                  if ((app['pdfPath'] as String? ?? '').isNotEmpty)
                    _row('PDF 경로', app['pdfPath'], mono: true),
                ],
              ]),
              const SizedBox(height: 16),

              // 서명
              if (hasSig) ...[
                const Text('서명', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFFAFAFA),
                  ),
                  child: Builder(builder: (_) {
                    try {
                      final b64 = sigData.split(',').last;
                      final bytes = base64Decode(b64);
                      return Image.memory(bytes,
                        height: 120, fit: BoxFit.contain, alignment: Alignment.centerLeft);
                    } catch (_) {
                      return const Text('서명 이미지 로드 실패',
                        style: TextStyle(color: Colors.grey));
                    }
                  }),
                ),
                const SizedBox(height: 8),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.draw_outlined, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Text('서명 없음', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 8),
              ],

              // 계약서 내용 스냅샷
              if ((app['contentSnapshot'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('계약서 내용', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: SelectableText(
                    app['contentSnapshot'] as String,
                    style: const TextStyle(fontSize: 12.5, height: 1.7, color: Colors.black87),
                  ),
                ),
              ],
            ]),
          )),

          // 닫기
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

  Widget _section(String title, List<Widget> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: rows),
      ),
    ]);
  }

  Widget _row(String label, dynamic value, {bool mono = false}) {
    final display = value?.toString() ?? '';
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50),
          child: Text(label, style: const TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SelectableText(display, style: TextStyle(
              fontSize: 13, color: Colors.black87,
              fontFamily: mono ? 'monospace' : null,
            )),
          ),
        ),
      ]),
    );
  }
}
