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
      if (mounted) setState(() {
        _pending = results[0];
        _all = results[1];
        _loading = false;
      });
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
      _load();
      if (mounted) _ok(context, '확인 처리 완료. PDF가 생성되었습니다.');
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
    if (ok != true) return;
    try {
      await context.read<ApiService>().deleteContract(app['applicationId']);
      _load();
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

  Widget _buildCard(Map<String, dynamic> app, {required bool showConfirm}) {
    final isConfirmed = app['confirmedYn'] == 'Y';
    final isSubmitted = app['submittedYn'] == 'Y';
    final email = app['applicantEmail'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              Text('확인: ${_fmtDate(app['confirmedAt'])}',
                style: const TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ]),
          if (app['pdfPath'] != null)
            Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('PDF: ${app['pdfPath']}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                overflow: TextOverflow.ellipsis)),
        ]),
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
