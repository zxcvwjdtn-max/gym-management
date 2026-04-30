import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../center/excel_upload_screen.dart';

class SuperGymScreen extends StatefulWidget {
  const SuperGymScreen({super.key});
  @override
  State<SuperGymScreen> createState() => _SuperGymScreenState();
}

class _SuperGymScreenState extends State<SuperGymScreen> {
  List<Map<String, dynamic>> _gyms = [];
  bool _loading = true;
  String _search = '';
  Map<String, dynamic>? _selectedGymForExcel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getAllGyms();
      if (mounted) setState(() { _gyms = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context,
            '${context.read<LocaleProvider>().t('common.loadFailed')}: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _gyms;
    return _gyms.where((g) {
      final name = (g['gymName'] ?? '').toString().toLowerCase();
      final code = (g['gymCode'] ?? '').toString().toLowerCase();
      final phone = (g['phone'] ?? '').toString();
      return name.contains(q) || code.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedGymForExcel != null) {
      return ExcelUploadScreen(
        gymId: _selectedGymForExcel!['gymId'] as int,
        gymName: _selectedGymForExcel!['gymName'] as String?,
        onBack: () => setState(() => _selectedGymForExcel = null),
      );
    }
    return _buildList();
  }

  Widget _buildList() {
    final loc = context.watch<LocaleProvider>();
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 헤더 ────────────────────────────────────────
        Row(children: [
          Text(loc.t('superGym.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text('${_gyms.length}${loc.t('superGym.countSuffix')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const Spacer(),
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: loc.t('superGym.searchHint'),
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(loc.t('common.refresh')),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 16),

        // ── 테이블 ───────────────────────────────────────
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.business_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _gyms.isEmpty
                      ? loc.t('superGym.empty')
                      : loc.t('superGym.noMatch'),
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ]),
            ),
          )
        else
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(children: [
                  // 헤더 행
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Row(children: [
                      Expanded(flex: 3,
                          child: _hdr(loc.t('superGym.col.name'))),
                      Expanded(flex: 2,
                          child: _hdr(loc.t('superGym.col.code'))),
                      Expanded(flex: 2,
                          child: _hdr(loc.t('superGym.col.sport'))),
                      Expanded(flex: 2,
                          child: _hdr(loc.t('superGym.col.phone'))),
                      Expanded(flex: 3,
                          child: _hdr(loc.t('superGym.col.address'))),
                      SizedBox(
                          width: 80,
                          child: _hdr(loc.t('superGym.col.subscription'),
                              center: true)),
                      SizedBox(
                          width: 200,
                          child: _hdr(loc.t('superGym.col.action'),
                              center: true)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          _buildRow(loc, filtered[i]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildRow(LocaleProvider loc, Map<String, dynamic> g) {
    final sub = g['subscriptionStatus'] as String? ?? 'NONE';
    final useYn = g['useYn'] as String? ?? 'Y';
    final inactive = useYn == 'N';

    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Row(children: [
            if (inactive)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(loc.t('superGym.inactive'),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade600)),
              ),
            Expanded(
              child: Text(g['gymName'] ?? '-',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: inactive
                          ? Colors.grey.shade400
                          : Colors.black87)),
            ),
          ]),
        ),
        Expanded(
            flex: 2,
            child: Text(g['gymCode'] ?? '-',
                style: TextStyle(
                    fontSize: 12,
                    color: inactive
                        ? Colors.grey.shade400
                        : Colors.grey.shade700))),
        Expanded(
            flex: 2,
            child: Text(g['sportType'] ?? '-',
                style: TextStyle(
                    fontSize: 13,
                    color:
                        inactive ? Colors.grey.shade400 : Colors.black87))),
        Expanded(
            flex: 2,
            child: Text(g['phone'] ?? '-',
                style: TextStyle(
                    fontSize: 13,
                    color:
                        inactive ? Colors.grey.shade400 : Colors.black87))),
        Expanded(
            flex: 3,
            child: Text(g['address'] ?? '-',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color:
                        inactive ? Colors.grey.shade400 : Colors.grey.shade700))),
        SizedBox(
          width: 80,
          child: Center(child: _subBadge(loc, sub)),
        ),
        SizedBox(
          width: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showEditDialog(g),
                icon: const Icon(Icons.edit, size: 13),
                label: Text(loc.t('common.edit'),
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _selectedGymForExcel = g),
                icon: const Icon(Icons.upload_file, size: 13),
                label: Text(loc.t('superTicket.uploadExcel'),
                    style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _subBadge(LocaleProvider loc, String status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'ACTIVE':
        bg = Colors.green.shade50; fg = Colors.green.shade700;
        label = loc.t('superGym.sub.active');
        break;
      case 'EXPIRING':
        bg = Colors.orange.shade50; fg = Colors.orange.shade700;
        label = loc.t('superGym.sub.expiring');
        break;
      case 'EXPIRED':
        bg = Colors.red.shade50; fg = Colors.red.shade700;
        label = loc.t('superGym.sub.expired');
        break;
      default:
        bg = Colors.grey.shade100; fg = Colors.grey.shade500;
        label = loc.t('superGym.sub.none');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _hdr(String label, {bool center = false}) => Text(label,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));

  // ── 수정 다이얼로그 ──────────────────────────────────

  void _showEditDialog(Map<String, dynamic> gym) {
    showDialog(
      context: context,
      builder: (_) => _GymEditDialog(
        gym: gym,
        onSaved: _load,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 체육관 수정 다이얼로그
// ─────────────────────────────────────────────────────────────────────────────

class _GymEditDialog extends StatefulWidget {
  final Map<String, dynamic> gym;
  final VoidCallback onSaved;
  const _GymEditDialog({required this.gym, required this.onSaved});
  @override
  State<_GymEditDialog> createState() => _GymEditDialogState();
}

class _GymEditDialogState extends State<_GymEditDialog> {
  static const _sportTypes = [
    'FITNESS', 'PILATES', 'YOGA', 'CROSSFIT',
    'BOXING', 'SWIMMING', 'TENNIS', 'GOLF', 'TAEKWONDO', 'ETC',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _ownerCtrl;
  late String _sportType;
  late String _useYn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.gym['gymName'] ?? '');
    _phoneCtrl   = TextEditingController(text: widget.gym['phone'] ?? '');
    _addressCtrl = TextEditingController(text: widget.gym['address'] ?? '');
    _ownerCtrl   = TextEditingController(text: widget.gym['ownerName'] ?? '');
    _sportType   = widget.gym['sportType'] ?? 'FITNESS';
    _useYn       = widget.gym['useYn'] ?? 'Y';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _addressCtrl.dispose(); _ownerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loc = context.read<LocaleProvider>();
    if (_nameCtrl.text.trim().isEmpty) {
      showErrorSnack(context, loc.t('superGym.edit.nameRequired'));
      return;
    }
    setState(() => _saving = true);
    try {
      final gymId = widget.gym['gymId'] as int;
      await context.read<ApiService>().updateGym(gymId, {
        'gymName':   _nameCtrl.text.trim(),
        'phone':     _phoneCtrl.text.trim(),
        'address':   _addressCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'sportType': _sportType,
        'useYn':     _useYn,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showSuccessSnack(context, loc.t('common.saved'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnack(context,
            '${loc.t("common.saveFailed")}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final gymCode = widget.gym['gymCode'] ?? '';

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.business, color: Color(0xFF1565C0), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            loc.t('superGym.edit.title', params: {'n': widget.gym['gymName'] ?? ''}),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gymCode.toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${loc.t("superGym.col.code")}: $gymCode',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ),
              _field(loc.t('superGym.edit.name'), _nameCtrl),
              const SizedBox(height: 14),
              _field(loc.t('superGym.edit.owner'), _ownerCtrl),
              const SizedBox(height: 14),
              _field(loc.t('superGym.edit.phone'), _phoneCtrl,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _field(loc.t('superGym.edit.address'), _addressCtrl),
              const SizedBox(height: 14),
              // 종목 드롭다운
              Text(loc.t('superGym.edit.sport'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _sportTypes.contains(_sportType)
                    ? _sportType
                    : _sportTypes.first,
                items: _sportTypes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _sportType = v!),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              // 사용여부
              Row(children: [
                Text(loc.t('superGym.edit.useYn'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _useYn == 'Y',
                  onChanged: (v) =>
                      setState(() => _useYn = v ? 'Y' : 'N'),
                ),
                Text(_useYn == 'Y'
                    ? loc.t('superGym.edit.active')
                    : loc.t('superGym.edit.inactive'),
                    style: TextStyle(
                        fontSize: 13,
                        color: _useYn == 'Y'
                            ? Colors.green.shade700
                            : Colors.red.shade400)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(loc.t('common.cancel')),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save, size: 16),
          label: Text(loc.t('common.save')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
  }
}
