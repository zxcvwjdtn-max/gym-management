import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';

/// 회원 엑셀 업로드 진행 + 결과 표시 다이얼로그.
/// [gymId]가 null이면 센터 관리자 API, 있으면 슈퍼어드민 API 사용.
class MemberExcelUploadDialog extends StatefulWidget {
  final List<int> bytes;
  final String filename;
  final int? gymId;

  const MemberExcelUploadDialog({
    super.key,
    required this.bytes,
    required this.filename,
    this.gymId,
  });

  @override
  State<MemberExcelUploadDialog> createState() => _MemberExcelUploadDialogState();
}

class _MemberExcelUploadDialogState extends State<MemberExcelUploadDialog> {
  bool _uploading = true;
  Map<String, dynamic>? _result;
  String? _error;

  bool _deleting = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  Future<void> _upload() async {
    try {
      final api = context.read<ApiService>();
      final result = widget.gymId == null
          ? await api.uploadMembersExcel(widget.bytes, widget.filename)
          : await api.uploadMembersExcelForGym(widget.gymId!, widget.bytes, widget.filename);
      if (mounted) setState(() { _result = result; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _uploading = false; });
    }
  }

  Future<void> _deleteBatch() async {
    final batchId = _result?['batchId'] as String?;
    if (batchId == null) return;
    final loc = context.read<LocaleProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('excelUpload.deleteConfirmTitle')),
        content: Text(loc.t('excelUpload.deleteConfirmMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.t('excelUpload.deleteConfirmBtn')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final api = context.read<ApiService>();
      widget.gymId == null
          ? await api.deleteUploadBatch(batchId)
          : await api.deleteUploadBatchForGym(widget.gymId!, batchId);
      if (mounted) setState(() { _deleted = true; _deleting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.t("excelUpload.deleteFailed")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.upload_file, color: Color(0xFF1565C0), size: 22),
        const SizedBox(width: 8),
        Text(loc.t('excelUpload.title')),
      ]),
      content: SizedBox(
        width: 500,
        child: _uploading ? _buildProgress(loc) : _buildResult(loc),
      ),
      actions: [
        if (!_uploading && _result != null && !_deleted)
          TextButton.icon(
            onPressed: _deleting ? null : _deleteBatch,
            icon: _deleting
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.delete_sweep, size: 16),
            label: Text(loc.t('excelUpload.deleteBtn')),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: Text(loc.t('common.close')),
        ),
      ],
    );
  }

  Widget _buildProgress(LocaleProvider loc) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 16),
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(loc.t('excelUpload.uploading', params: {'f': widget.filename}),
          style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildResult(LocaleProvider loc) {
    if (_error != null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 40),
        const SizedBox(height: 12),
        Text(loc.t('excelUpload.failed'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
      ]);
    }

    if (_deleted) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle, color: Colors.orange, size: 40),
        const SizedBox(height: 12),
        Text(loc.t('excelUpload.deleteSuccess'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]);
    }

    final r = _result!;
    final total   = r['totalRows']    as int? ?? 0;
    final success = r['successCount'] as int? ?? 0;
    final skipped = r['skippedCount'] as int? ?? 0;
    final failed  = r['failedCount']  as int? ?? 0;
    final batchId = r['batchId']      as String?;
    final errors  = (r['errors'] as List?)?.cast<String>() ?? const <String>[];

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(failed > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
          color: failed > 0 ? Colors.orange : Colors.green, size: 40),
      const SizedBox(height: 12),
      Text(loc.t('excelUpload.done'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _statRow(loc.t('excelUpload.total'),   total,   Colors.grey.shade700),
      _statRow(loc.t('excelUpload.success'), success, Colors.green.shade700),
      _statRow(loc.t('excelUpload.skipped'), skipped, Colors.orange.shade700),
      _statRow(loc.t('excelUpload.failed2'), failed,  Colors.red.shade700),
      if (batchId != null && success > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${loc.t("excelUpload.batchId")}: $batchId',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade700,
                    fontFamily: 'monospace'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text(loc.t('excelUpload.deleteHint'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
      if (errors.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(loc.t('excelUpload.errorList'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: SingleChildScrollView(
            child: Text(errors.join('\n'),
                style: TextStyle(fontSize: 11, color: Colors.red.shade900)),
          ),
        ),
      ],
    ]);
  }

  Widget _statRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
        Text('$value',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}
