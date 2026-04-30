import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
// notice_screen.dart에서 공통 위젯 재사용
import 'notice_screen.dart' show PostDetailDialog;

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});
  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  List<CommunityPostModel> _posts = [];
  bool _loading = true;

  static const _type = 'MESSAGE';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getCommunityPosts(_type);
      if (mounted) setState(() { _posts = list; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); showErrorSnack(context, '불러오기 실패: $e'); }
    }
  }

  Future<void> _openForm({CommunityPostModel? post}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MessageFormDialog(existing: post),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(CommunityPostModel post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전달사항 삭제'),
        content: Text('"${post.title}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteCommunityPost(post.postId!);
      if (mounted) { showSuccessSnack(context, '삭제했습니다.'); _load(); }
    } catch (e) {
      if (mounted) showErrorSnack(context, '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.message, color: Color(0xFF2E7D32), size: 26),
            const SizedBox(width: 10),
            const Text('전달사항', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            if (!_loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('${_posts.length}건', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('글쓰기'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_posts.isEmpty)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.message_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('등록된 전달사항이 없습니다.', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => _openForm(), child: const Text('첫 전달사항 작성')),
              ]),
            ))
          else
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Column(children: [
                    _buildHeader(),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (_, i) => _MsgRow(
                          index: i,
                          post: _posts[i],
                          onEdit: () => _openForm(post: _posts[i]),
                          onDelete: () => _confirmDelete(_posts[i]),
                        ),
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

  Widget _buildHeader() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(children: [
        SizedBox(width: 36, child: Text('번호', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: Text('제목', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        SizedBox(width: 120, child: Text('작성자', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        SizedBox(width: 140, child: Text('작성일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        SizedBox(width: 80),
      ]),
    );
  }
}

class _MsgRow extends StatelessWidget {
  final int index;
  final CommunityPostModel post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MsgRow({required this.index, required this.post, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = post.createdAt != null && post.createdAt!.length >= 10
        ? post.createdAt!.substring(0, 10) : '-';
    return InkWell(
      onTap: () => showDialog(context: context,
          builder: (_) => PostDetailDialog(post: post, title: '전달사항')),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(width: 36, child: Text('${index + 1}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Expanded(child: Text(post.title, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 120, child: Text(post.createdBy ?? '-', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          SizedBox(width: 140, child: Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          SizedBox(
            width: 80,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(onTap: onEdit, child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit, size: 16, color: Colors.blue))),
              const SizedBox(width: 4),
              InkWell(onTap: onDelete, child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.delete, size: 16, color: Colors.red.shade400))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// 전달사항 전용 폼 다이얼로그 (isPinned 없음)
class _MessageFormDialog extends StatefulWidget {
  final CommunityPostModel? existing;
  const _MessageFormDialog({this.existing});
  @override
  State<_MessageFormDialog> createState() => _MessageFormDialogState();
}

class _MessageFormDialogState extends State<_MessageFormDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _saving = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _titleCtrl.text = widget.existing!.title;
      _contentCtrl.text = widget.existing!.content ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) { showErrorSnack(context, '제목을 입력하세요.'); return; }
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final body = {
        'postType': 'MESSAGE',
        'title': title,
        'content': _contentCtrl.text.trim(),
        'isPinned': 'N',
      };
      if (isEdit) {
        await api.updateCommunityPost(widget.existing!.postId!, body);
      } else {
        await api.createCommunityPost(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEdit ? '전달사항 수정' : '전달사항 작성'),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            maxLines: 10,
            decoration: const InputDecoration(labelText: '내용', border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEdit ? '수정' : '등록'),
        ),
      ],
    );
  }
}
