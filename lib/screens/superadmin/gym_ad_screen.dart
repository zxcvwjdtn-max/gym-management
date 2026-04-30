import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class GymAdScreen extends StatefulWidget {
  const GymAdScreen({super.key});

  @override
  State<GymAdScreen> createState() => _GymAdScreenState();
}

class _GymAdScreenState extends State<GymAdScreen> {
  List<Map<String, dynamic>> _gyms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 전체 체육관 목록 로드
  Future<void> _load() async {
    try {
      final list = await context.read<ApiService>().getAllGyms();
      if (mounted) setState(() { _gyms = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, '로드 실패: $e');
        setState(() => _loading = false);
      }
    }
  }

  // 광고 설정 다이얼로그 표시
  void _showAdDialog(Map<String, dynamic> gym) {
    showDialog(
      context: context,
      builder: (_) => _AdSettingsDialog(
        gym: gym,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('체육관 광고 설정'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _gyms.isEmpty
              ? const Center(child: Text('등록된 체육관이 없습니다.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Google AdSense 광고를 체육관 화면 하단에 표시합니다.\n'
                              'AdSense 게시자 ID(ca-pub-XXXX)와 광고 슬롯 ID를 입력하세요.',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                            ),
                          ),
                        ]),
                      ),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: DataTable(
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('체육관명', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('코드', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('광고 허용', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('게시자 ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('슬롯 ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('설정', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _gyms.map((gym) {
                            final adEnabled = gym['adEnabled'] == 'Y';
                            return DataRow(cells: [
                              DataCell(Text(gym['gymName'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(gym['gymCode'] ?? '-',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: adEnabled ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    adEnabled ? '허용' : '미허용',
                                    style: TextStyle(
                                      color: adEnabled ? Colors.green.shade700 : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(
                                _truncate(gym['adClient']),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              )),
                              DataCell(Text(
                                _truncate(gym['adSlot']),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              )),
                              DataCell(
                                TextButton.icon(
                                  onPressed: () => _showAdDialog(gym),
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('설정', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // 긴 문자열 말줄임 처리
  String _truncate(dynamic val) {
    if (val == null || val.toString().isEmpty) return '-';
    final s = val.toString();
    return s.length > 20 ? '${s.substring(0, 20)}…' : s;
  }
}

class _AdSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> gym;
  final VoidCallback onSaved;

  const _AdSettingsDialog({required this.gym, required this.onSaved});

  @override
  State<_AdSettingsDialog> createState() => _AdSettingsDialogState();
}

class _AdSettingsDialogState extends State<_AdSettingsDialog> {
  late bool _adEnabled;
  late final TextEditingController _clientCtrl;
  late final TextEditingController _slotCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _adEnabled = widget.gym['adEnabled'] == 'Y';
    _clientCtrl = TextEditingController(text: widget.gym['adClient'] ?? '');
    _slotCtrl = TextEditingController(text: widget.gym['adSlot'] ?? '');
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _slotCtrl.dispose();
    super.dispose();
  }

  // 광고 설정 저장
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().updateGymAdSettings(
        widget.gym['gymId'],
        adEnabled: _adEnabled ? 'Y' : 'N',
        adClient: _clientCtrl.text.trim(),
        adSlot: _slotCtrl.text.trim(),
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.gym['gymName']} — 광고 설정'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _adEnabled,
              onChanged: (v) => setState(() => _adEnabled = v),
              title: const Text('광고 허용'),
              subtitle: const Text('활성화 시 앱 하단에 AdSense 광고가 표시됩니다.'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientCtrl,
              decoration: const InputDecoration(
                labelText: '게시자 ID (ca-pub-XXXXXXXXXXXXXXXX)',
                hintText: 'ca-pub-',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              enabled: _adEnabled,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slotCtrl,
              decoration: const InputDecoration(
                labelText: '광고 슬롯 ID',
                hintText: '예: 1234567890',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              enabled: _adEnabled,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }
}
