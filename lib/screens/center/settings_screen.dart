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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.getPointSettings(),
        api.getCheckoutMode(),
      ]);
      if (!mounted) return;
      final data = results[0] as Map<String, dynamic>;
      setState(() {
        _enabled = 'Y' == data['pointEnabled'];
        final r = data['pointRatePercent'];
        _rateCtrl.text = r == null ? '0' : r.toString();
        _checkoutMode = results[1] as String;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final loc = context.read<LocaleProvider>();
        showErrorSnack(context, '${loc.t('common.loadFailed')}: $e');
      }
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
  }) {
    final selected = _checkoutMode == value;
    return InkWell(
      onTap: () { if (!selected) _saveCheckoutMode(value); },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0).withOpacity(0.06) : null,
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
          color: selected ? const Color(0xFF1565C0).withOpacity(0.08) : null,
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
