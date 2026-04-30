import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/app_select.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getStaff();
      if (mounted) setState(() { _staff = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _roleToId = {'OWNER': 1, 'DIRECTOR': 2, 'STAFF': 3, 'PARTTIME': 4};
  static const _levelToRole = {1: 'OWNER', 2: 'DIRECTOR', 3: 'STAFF', 4: 'PARTTIME'};

  void _showForm([Map<String, dynamic>? staff]) {
    final loc = context.read<LocaleProvider>();
    final nameCtrl     = TextEditingController(text: staff?['adminName'] ?? '');
    final loginCtrl    = TextEditingController(text: staff?['loginId']   ?? '');
    final pwdCtrl      = TextEditingController();
    final phoneCtrl    = TextEditingController(text: staff?['phone']     ?? '');
    final specialtyCtrl= TextEditingController(text: staff?['specialty'] ?? '');
    final authLevel    = staff?['authLevel'] as int? ?? 3;
    String role        = _levelToRole[authLevel] ?? 'STAFF';
    bool isTrainer     = staff?['isTrainer'] == 'Y';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.manage_accounts, color: Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Text(staff == null ? loc.t('center.staff.addTitle') : loc.t('center.staff.editTitle')),
          ]),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText: loc.t('center.staff.nameLabel'),
                      border: const OutlineInputBorder()),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(
                      labelText: loc.t('center.staff.phoneLabel'),
                      border: const OutlineInputBorder()),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: loginCtrl,
                  enabled: staff == null,
                  decoration: InputDecoration(
                      labelText: loc.t('center.staff.loginLabel'),
                      border: const OutlineInputBorder()),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: pwdCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: staff == null ? loc.t('center.staff.pwdLabel') : loc.t('center.staff.pwdEditLabel'),
                    border: const OutlineInputBorder(),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              FormSelect<String>(
                label: loc.t('center.staff.roleLabel'),
                currentLabel: loc.t('center.staff.role.$role'),
                hint: loc.t('center.staff.select'),
                options: [
                  (loc.t('center.staff.role.OWNER'), 'OWNER'),
                  (loc.t('center.staff.role.DIRECTOR'), 'DIRECTOR'),
                  (loc.t('center.staff.role.STAFF'), 'STAFF'),
                  (loc.t('center.staff.role.PARTTIME'), 'PARTTIME'),
                ],
                onSelected: (v) { if (v != null) setDlg(() => role = v); },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4527A0).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4527A0).withOpacity(0.2)),
                ),
                child: Column(children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(loc.t('center.staff.ptTrainer'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(loc.t('center.staff.ptTrainerDesc')),
                    value: isTrainer,
                    onChanged: (v) => setDlg(() => isTrainer = v),
                    activeColor: const Color(0xFF4527A0),
                  ),
                  if (isTrainer) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: specialtyCtrl,
                      decoration: InputDecoration(
                        labelText: loc.t('center.staff.specialtyLabel'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.t('common.cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || loginCtrl.text.trim().isEmpty) {
                  showErrorSnack(ctx, loc.t('center.staff.errRequired'));
                  return;
                }
                try {
                  final body = <String, dynamic>{
                    'adminName': nameCtrl.text.trim(),
                    'loginId': loginCtrl.text.trim(),
                    'authGroupId': _roleToId[role],
                    'phone': phoneCtrl.text.trim(),
                    'isTrainer': isTrainer ? 'Y' : 'N',
                    'specialty': specialtyCtrl.text.trim(),
                    if (pwdCtrl.text.isNotEmpty) 'loginPw': pwdCtrl.text,
                  };
                  final api = context.read<ApiService>();
                  if (staff == null) await api.createStaff(body);
                  else await api.updateStaff(staff['adminId'], body);
                  if (ctx.mounted) { Navigator.pop(ctx); _load(); }
                } catch (e) {
                  if (ctx.mounted) {
                    showErrorSnack(ctx,
                      loc.t('center.staff.saveFail', params: {'e': e.toString()}));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
              child: Text(loc.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStaff(Map<String, dynamic> s) async {
    final loc = context.read<LocaleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('center.staff.deactivate')),
        content: Text(loc.t('center.staff.deactivateConfirm',
          params: {'n': s['adminName']?.toString() ?? ''})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('center.staff.btnDeactivate')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteStaff(s['adminId']);
      _load();
    } catch (e) {
      if (mounted) showErrorSnack(context,
        loc.t('center.staff.fail', params: {'e': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('center.staff.title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.person_add, size: 18),
              label: Text(loc.t('center.staff.add')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_staff.isEmpty)
            Expanded(child: Center(
              child: Text(loc.t('center.staff.empty'),
                  style: const TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columns: [
                      DataColumn(label: Text(loc.t('center.staff.col.name'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.phone'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.loginId'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.role'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.trainer'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.useYn'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.createdAt'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.t('center.staff.col.actions'),
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _staff.map((s) => DataRow(cells: [
                      DataCell(Text(s['adminName'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(s['phone'] ?? '-',
                          style: TextStyle(color: Colors.grey.shade700))),
                      DataCell(Text(s['loginId'] ?? '-')),
                      DataCell(_roleBadge(loc,
                          _levelToRole[s['authLevel'] as int? ?? 4] ?? 'STAFF')),
                      DataCell(s['isTrainer'] == 'Y'
                          ? _trainerBadge(loc, s['specialty'])
                          : Text('-', style: TextStyle(color: Colors.grey.shade400))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: s['useYn'] == 'Y'
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(s['useYn'] == 'Y'
                            ? loc.t('center.staff.active')
                            : loc.t('center.staff.inactive'),
                          style: TextStyle(
                            color: s['useYn'] == 'Y' ? Colors.green : Colors.grey,
                            fontSize: 12, fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Text(
                          s['createdAt']?.toString().substring(0, 10) ?? '-')),
                      DataCell(Row(children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showForm(s),
                          tooltip: loc.t('center.staff.tooltip.edit'),
                        ),
                        if (s['useYn'] == 'Y')
                          IconButton(
                            icon: const Icon(Icons.person_off_outlined,
                                size: 18, color: Colors.red),
                            onPressed: () => _deleteStaff(s),
                            tooltip: loc.t('center.staff.tooltip.deactivate'),
                          ),
                      ])),
                    ])).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roleBadge(LocaleProvider loc, String? role) {
    final color = switch (role) {
      'OWNER' => Colors.purple,
      'DIRECTOR' => Colors.blue,
      'STAFF' => Colors.teal,
      'PARTTIME' => Colors.orange,
      _ => Colors.grey,
    };
    final label = role == null ? '-' : loc.t('center.staff.role.$role');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _trainerBadge(LocaleProvider loc, dynamic specialty) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFF4527A0).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Text(loc.t('center.staff.trainerBadge'),
            style: const TextStyle(color: Color(0xFF4527A0), fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
      if (specialty != null && specialty.toString().isNotEmpty) ...[
        const SizedBox(width: 4),
        Text(specialty.toString(),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    ]);
  }
}
