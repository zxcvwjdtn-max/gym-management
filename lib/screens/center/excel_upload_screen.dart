import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/member_excel_upload_dialog.dart';

/// 회원 엑셀 업로드 이력 화면.
/// [gymId] null → 센터 관리자 모드 / int → 슈퍼어드민 특정 체육관 모드
/// [onBack] 슈퍼어드민 뷰에서 뒤로가기용 콜백 (null이면 독립 화면)
class ExcelUploadScreen extends StatefulWidget {
  final int? gymId;
  final String? gymName;
  final VoidCallback? onBack;

  const ExcelUploadScreen({super.key, this.gymId, this.gymName, this.onBack});

  @override
  State<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends State<ExcelUploadScreen> {
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final raw = widget.gymId == null
          ? await api.getUploadBatches()
          : await api.getUploadBatchesForGym(widget.gymId!);
      if (mounted) {
        setState(() {
          _batches = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, '${context.read<LocaleProvider>().t('common.loadFailed')}: $e');
      }
    }
  }

  Future<void> _pickAndUpload() async {
    final loc = context.read<LocaleProvider>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) showErrorSnack(context, loc.t('settings.excel.readFail'));
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MemberExcelUploadDialog(
        bytes: file.bytes!,
        filename: file.name,
        gymId: widget.gymId,
      ),
    );
    _load();
  }

  Future<void> _deleteBatch(Map<String, dynamic> batch) async {
    final loc = context.read<LocaleProvider>();
    final batchId = batch['batchId'] as String;

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

    try {
      final api = context.read<ApiService>();
      widget.gymId == null
          ? await api.deleteUploadBatch(batchId)
          : await api.deleteUploadBatchForGym(widget.gymId!, batchId);
      if (mounted) {
        showSuccessSnack(context, loc.t('excelUpload.deleteSuccess'));
        _load();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '${loc.t("excelUpload.deleteFailed")}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final title = widget.gymName != null
        ? '${widget.gymName} — ${loc.t('menu.excel_upload')}'
        : loc.t('menu.excel_upload');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──────────────────────────────────────
          Row(children: [
            if (widget.onBack != null) ...[
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: loc.t('superTicket.back'),
              ),
              const SizedBox(width: 4),
            ],
            Text(title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(loc.t('settings.excel.pick')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(loc.t('excelUpload.historyDesc'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 16),

          // ── 규칙 안내 ──────────────────────────────────
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.blue.shade100)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(loc.t('settings.excel.rules'),
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade800, height: 1.6)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── 업로드 이력 테이블 ──────────────────────────
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _batches.isEmpty
                  ? _buildEmpty(loc)
                  : _buildTable(loc)),
        ],
      ),
    );
  }

  Widget _buildEmpty(LocaleProvider loc) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.upload_file, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(loc.t('excelUpload.noHistory'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        const SizedBox(height: 8),
        Text(loc.t('excelUpload.noHistoryHint'),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ]),
    );
  }

  Widget _buildTable(LocaleProvider loc) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          // 헤더
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(children: [
              Expanded(flex: 2, child: _hdr(loc.t('excelUpload.col.date'))),
              Expanded(flex: 3, child: _hdr(loc.t('excelUpload.col.filename'))),
              SizedBox(width: 60, child: _hdr(loc.t('excelUpload.total'), center: true)),
              SizedBox(width: 60, child: _hdr(loc.t('excelUpload.success'), center: true)),
              SizedBox(width: 60, child: _hdr(loc.t('excelUpload.skipped'), center: true)),
              SizedBox(width: 60, child: _hdr(loc.t('excelUpload.failed2'), center: true)),
              SizedBox(width: 80, child: _hdr(loc.t('excelUpload.col.status'), center: true)),
              SizedBox(width: 80, child: _hdr(loc.t('excelUpload.col.action'), center: true)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _batches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) => _buildRow(loc, _batches[i]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRow(LocaleProvider loc, Map<String, dynamic> b) {
    final deleted = b['deletedYn'] == 'Y';
    final createdAt = b['createdAt'] as String? ?? '';
    final dateStr = createdAt.length >= 16 ? createdAt.substring(0, 16).replaceFirst('T', ' ') : createdAt;
    final filename = b['filename'] as String? ?? '-';
    final total   = b['totalRows']    as int? ?? 0;
    final success = b['successCount'] as int? ?? 0;
    final skipped = b['skippedCount'] as int? ?? 0;
    final failed  = b['failedCount']  as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(children: [
        Expanded(flex: 2,
            child: Text(dateStr,
                style: TextStyle(
                    fontSize: 12,
                    color: deleted ? Colors.grey.shade400 : Colors.grey.shade700))),
        Expanded(flex: 3,
            child: Text(filename,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: deleted ? Colors.grey.shade400 : Colors.black87,
                    decoration: deleted ? TextDecoration.lineThrough : null))),
        SizedBox(width: 60, child: _cell('$total', Colors.grey.shade700, deleted)),
        SizedBox(width: 60, child: _cell('$success', Colors.green.shade700, deleted)),
        SizedBox(width: 60, child: _cell('$skipped', Colors.orange.shade700, deleted)),
        SizedBox(width: 60, child: _cell('$failed', Colors.red.shade700, deleted)),
        SizedBox(
          width: 80,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: deleted ? Colors.grey.shade100 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: deleted ? Colors.grey.shade300 : Colors.green.shade200),
              ),
              child: Text(
                deleted ? loc.t('excelUpload.status.deleted') : loc.t('excelUpload.status.active'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: deleted ? Colors.grey.shade500 : Colors.green.shade700),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: Center(
            child: deleted
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: () => _deleteBatch(b),
                    icon: const Icon(Icons.delete_sweep, size: 14),
                    label: Text(loc.t('common.delete'), style: const TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _hdr(String label, {bool center = false}) {
    return Text(label,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
  }

  Widget _cell(String value, Color color, bool deleted) {
    return Text(value,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: deleted ? Colors.grey.shade400 : color));
  }
}
