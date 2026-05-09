import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

/// 통합 설정 화면
/// - 언어 (ko/en)
/// - 포인트 적립 설정
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 포인트 설정
  bool _enabled = false;
  final _rateCtrl = TextEditingController(text: '0');
  bool _loading = true;
  bool _saving = false;

  // 출석 모드
  String _checkoutMode = 'CHECK_IN_ONLY';
  bool _modeSaving = false;

  // 전자계약 PDF 경로
  String _serverPdfDir = '';
  final _localPdfCtrl = TextEditingController();
  bool _pdfSaving = false;

  // 키오스크 공지 설정
  String _kioskMode = 'NOTICE';
  final _noticeCtrl = TextEditingController();
  Uint8List? _kioskImageBytes;
  bool _kioskSaving = false;
  bool _imageUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _localPdfCtrl.dispose();
    _noticeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getPointSettings(),
        api.getCheckoutMode(),
        api.getContractPdfSettings(),
        api.getKioskSettings(),
      ]);
      if (!mounted) return;
      final data = results[0] as Map<String, dynamic>;
      final pdfSettings = results[2] as Map<String, dynamic>;
      final kiosk = results[3] as Map<String, dynamic>;
      setState(() {
        _enabled = 'Y' == data['pointEnabled'];
        final r = data['pointRatePercent'];
        _rateCtrl.text = r == null ? '0' : r.toString();
        _checkoutMode = results[1] as String;
        _serverPdfDir = pdfSettings['serverPdfDir'] as String? ?? '';
        _localPdfCtrl.text = pdfSettings['localPdfDir'] as String? ?? '';
        _kioskMode = kiosk['kioskDisplayMode'] as String? ?? 'NOTICE';
        _noticeCtrl.text = kiosk['kioskNotice'] as String? ?? '';
        _loading = false;
      });
      // 이미지가 있으면 미리보기 로드
      if (kiosk['hasImage'] == true) {
        final imgBytes = await api.getKioskImage();
        if (mounted && imgBytes != null) {
          setState(() => _kioskImageBytes = Uint8List.fromList(imgBytes));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final loc = context.read<LocaleProvider>();
        showErrorSnack(context, '${loc.t('common.loadFailed')}: $e');
      }
    }
  }

  Future<void> _saveLocalPdfDir() async {
    setState(() => _pdfSaving = true);
    try {
      await context.read<ApiService>().updateLocalPdfDir(_localPdfCtrl.text.trim());
      if (mounted) showSuccessSnack(context, '저장되었습니다.');
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _pdfSaving = false);
    }
  }

  Future<void> _saveCheckoutMode(String mode) async {
    setState(() => _modeSaving = true);
    try {
      await context.read<ApiService>().updateCheckoutMode(mode);
      if (mounted) {
        setState(() => _checkoutMode = mode);
        showSuccessSnack(context, '저장되었습니다.');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _modeSaving = false);
    }
  }

  Future<void> _saveKiosk() async {
    setState(() => _kioskSaving = true);
    try {
      await context.read<ApiService>().updateKioskSettings(
            mode: _kioskMode,
            notice: _noticeCtrl.text.trim(),
          );
      if (mounted) showSuccessSnack(context, '저장되었습니다.');
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _kioskSaving = false);
    }
  }

  Future<void> _pickAndUploadKioskImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    List<int> bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      return;
    }

    setState(() => _imageUploading = true);
    try {
      await context.read<ApiService>().uploadKioskImage(
            bytes, file.name);
      if (mounted) {
        setState(() => _kioskImageBytes = Uint8List.fromList(bytes));
        showSuccessSnack(context, '이미지가 업로드되었습니다.');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '업로드 실패: $e');
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }

  Future<void> _savePoint() async {
    final loc = context.read<LocaleProvider>();
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      showErrorSnack(context, loc.t('settings.point.rateError'));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().updatePointSettings(_enabled ? 'Y' : 'N', rate);
      if (mounted) showSuccessSnack(context, loc.t('common.saved'));
    } catch (e) {
      if (mounted) showErrorSnack(context, '${loc.t('common.saveFailed')}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('settings.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // ── 언어 설정 ─────────────────────────────────────
          _sectionCard(
            icon: Icons.language,
            title: loc.t('settings.language.title'),
            desc: loc.t('settings.language.desc'),
            child: Row(
              children: [
                Expanded(
                  child: _langOption(
                    selected: loc.lang == 'ko',
                    label: loc.t('settings.language.korean'),
                    onTap: () => loc.setLang('ko'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _langOption(
                    selected: loc.lang == 'en',
                    label: loc.t('settings.language.english'),
                    onTap: () => loc.setLang('en'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 출석/퇴실 관리 모드 ──────────────────────────
          _sectionCard(
            icon: Icons.directions_run,
            title: '출석 관리 방식',
            desc: '출석만 관리할지, 출석과 퇴실을 함께 관리할지 설정합니다.',
            child: _modeSaving
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    _modeOption(
                      value: 'CHECK_IN_ONLY',
                      label: '출석만 관리',
                      desc: '출석 후 한 번 더 스캔하면 "이미 출석" 안내',
                      icon: Icons.login,
                    ),
                    const SizedBox(height: 10),
                    _modeOption(
                      value: 'CHECK_IN_OUT',
                      label: '출석 + 퇴실 관리',
                      desc: '출석 후 한 번 더 스캔하면 퇴실 처리',
                      icon: Icons.swap_horiz,
                    ),
                  ]),
          ),
          const SizedBox(height: 20),

          // ── 전자계약 PDF 저장 경로 ────────────────────────
          _sectionCard(
            icon: Icons.picture_as_pdf,
            title: '전자계약 PDF 저장 경로',
            desc: '계약서 확인 시 PDF 파일이 저장될 경로를 설정합니다.',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 서버 저장 경로 (읽기 전용)
              Text('서버 저장 경로', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _serverPdfDir.isEmpty ? '경로 로딩 중...' : _serverPdfDir,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF333333)),
                ),
              ),
              const SizedBox(height: 16),
              // 추가 로컬 저장 경로 (편집 가능)
              Text('추가 저장 경로 (선택)', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text('설정 시 PDF가 위 경로 외에 이 경로에도 추가 저장됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              TextField(
                controller: _localPdfCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'C:\\Users\\사용자\\Documents\\contracts',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => _localPdfCtrl.clear(),
                    tooltip: '비우기',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _pdfSaving ? null : _saveLocalPdfDir,
                  icon: _pdfSaving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── 키오스크 공지 설정 ───────────────────────────────
          _sectionCard(
            icon: Icons.monitor,
            title: '출석체크 키오스크 공지',
            desc: '키오스크 화면에 표시할 내용을 설정합니다.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 표시 방식 선택
                _modeOption(
                  value: 'NOTICE',
                  label: '공지사항 텍스트',
                  desc: '직접 입력한 공지 내용을 표시합니다.',
                  icon: Icons.campaign_outlined,
                  currentValue: _kioskMode,
                  onSelect: () => setState(() => _kioskMode = 'NOTICE'),
                ),
                const SizedBox(height: 10),
                _modeOption(
                  value: 'IMAGE',
                  label: '이미지',
                  desc: '업로드한 이미지를 전체 화면에 표시합니다.',
                  icon: Icons.image_outlined,
                  currentValue: _kioskMode,
                  onSelect: () => setState(() => _kioskMode = 'IMAGE'),
                ),
                const SizedBox(height: 20),

                // 공지사항 텍스트 입력 (NOTICE 모드일 때)
                if (_kioskMode == 'NOTICE') ...[
                  Text('공지사항 내용',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noticeCtrl,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '• 공지 내용을 입력하세요.\n• 줄바꿈도 그대로 표시됩니다.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],

                // 이미지 업로드 (IMAGE 모드일 때)
                if (_kioskMode == 'IMAGE') ...[
                  Text('키오스크 이미지',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  if (_kioskImageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _kioskImageBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _imageUploading ? null : _pickAndUploadKioskImage,
                      icon: _imageUploading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(_kioskImageBytes == null
                          ? '이미지 선택 및 업로드'
                          : '이미지 변경'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        foregroundColor: const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _kioskSaving ? null : _saveKiosk,
                    icon: _kioskSaving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text('저장'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 포인트 설정 ───────────────────────────────────
          _sectionCard(
            icon: Icons.stars,
            title: loc.t('settings.point.section'),
            desc: loc.t('settings.point.desc'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.t('settings.point.enable'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(loc.t('settings.point.enable.desc'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ]),
                const Divider(height: 32),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.t('settings.point.rate'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(loc.t('settings.point.rate.desc'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _rateCtrl,
                      enabled: _enabled,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: loc.t('settings.point.rateLabel'),
                        border: const OutlineInputBorder(),
                        suffixText: '%',
                        isDense: true,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _savePoint,
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(loc.t('common.save')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String desc,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xFF1565C0), size: 22),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _modeOption({
    required String value,
    required String label,
    required String desc,
    required IconData icon,
    String? currentValue,
    VoidCallback? onSelect,
  }) {
    final selected = (currentValue ?? _checkoutMode) == value;
    return InkWell(
      onTap: () {
        if (!selected) {
          if (onSelect != null) {
            onSelect();
          } else {
            _saveCheckoutMode(value);
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0).withValues(alpha: 0.06) : null,
          border: Border.all(
            color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected ? const Color(0xFF1565C0) : Colors.grey,
              size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: selected ? const Color(0xFF1565C0) : Colors.black87,
              )),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600,
              )),
            ],
          )),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? const Color(0xFF1565C0) : Colors.grey,
            size: 20,
          ),
        ]),
      ),
    );
  }

  Widget _langOption({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0).withValues(alpha: 0.08) : null,
          border: Border.all(
            color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? const Color(0xFF1565C0) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? const Color(0xFF1565C0) : Colors.black87,
              )),
        ]),
      ),
    );
  }
}
