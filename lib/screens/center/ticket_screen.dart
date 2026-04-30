import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/app_select.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  List<TicketModel> _all = [];
  bool _loading = true;

  List<TicketModel> get _gymTickets => _all.where((t) => !t.isCommon).toList();
  List<TicketModel> get _commonTickets => _all.where((t) => t.isCommon).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getTickets();
      if (mounted) setState(() { _all = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForm([TicketModel? ticket]) {
    final loc = context.read<LocaleProvider>();
    final auth = context.read<AuthProvider>();
    String selectedType  = ticket?.ticketType  ?? 'PERIOD';
    int? importedFromId;
    String? importedSportType;
    final nameCtrl  = TextEditingController(text: ticket?.ticketName ?? '');
    final codeCtrl  = TextEditingController(text: ticket?.ticketCode ?? '');
    final priceCtrl = TextEditingController(text: (ticket?.price != null && ticket!.price != 0) ? ticket.price.toString() : '');
    final monthCtrl = TextEditingController(text: ticket?.durationMonths.toString() ?? '1');
    final dayCtrl   = TextEditingController(text: ticket?.durationDays?.toString() ?? '');
    final weekCtrl  = TextEditingController(text: ticket?.weeklyDays.toString() ?? '0');
    final countCtrl = TextEditingController(text: ticket?.totalCount?.toString() ?? '');
    final descCtrl  = TextEditingController(text: ticket?.description ?? '');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.card_membership, color: Color(0xFF1565C0), size: 20),
            const SizedBox(width: 8),
            Text(ticket == null ? loc.t('center.ticket.add') : loc.t('center.ticket.editTitle')),
          ]),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (ticket == null && _commonTickets.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.public, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(loc.t('center.ticket.importFromCommon'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                      const SizedBox(height: 8),
                      FormSelect<int>(
                        label: loc.t('center.ticket.commonSelectLabel'),
                        hint: loc.t('center.ticket.commonSelectHint'),
                        currentLabel: importedFromId == null ? null
                            : _commonTickets.firstWhere((c) => c.ticketId == importedFromId,
                                orElse: () => TicketModel(
                                  ticketName: '', durationMonths: 0, weeklyDays: 0, price: 0)).ticketName,
                        options: _commonTickets.map((c) => (
                          '${c.ticketName} (${_fmtPrice(c.price)}${loc.t('center.ticket.priceSuffix')})',
                          c.ticketId,
                        )).toList(),
                        onSelected: (v) {
                          if (v == null) return;
                          final src = _commonTickets.firstWhere((c) => c.ticketId == v);
                          setDlg(() {
                            importedFromId = v;
                            importedSportType = src.sportType;
                            selectedType = src.ticketType;
                            nameCtrl.text  = src.ticketName;
                            codeCtrl.text  = src.ticketCode ?? '';
                            priceCtrl.text = src.price.toString();
                            monthCtrl.text = src.durationMonths.toString();
                            dayCtrl.text   = src.durationDays?.toString() ?? '';
                            weekCtrl.text  = src.weeklyDays.toString();
                            countCtrl.text = src.totalCount?.toString() ?? '';
                            descCtrl.text  = src.description ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(loc.t('center.ticket.importDesc'),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.t('center.ticket.type'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _typeCard(
                      icon: Icons.calendar_month,
                      label: loc.t('center.ticket.type.period'),
                      desc: loc.t('center.ticket.type.periodDesc'),
                      value: 'PERIOD',
                      current: selectedType,
                      color: Colors.teal,
                      onTap: () => setDlg(() => selectedType = 'PERIOD'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _typeCard(
                      icon: Icons.confirmation_number_outlined,
                      label: loc.t('center.ticket.type.count'),
                      desc: loc.t('center.ticket.type.countDesc'),
                      value: 'COUNT',
                      current: selectedType,
                      color: Colors.purple,
                      onTap: () => setDlg(() => selectedType = 'COUNT'),
                    )),
                  ]),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(flex: 2, child: TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: loc.t('center.ticket.nameLabel'),
                      border: const OutlineInputBorder()),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: loc.t('center.ticket.codeLabel'),
                      border: const OutlineInputBorder()),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: loc.t('center.ticket.priceLabel'),
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('center.ticket.priceSuffix'),
                  ),
                ),
                const SizedBox(height: 12),
                // 기간 필드 (기간제 / 횟수제 공통)
                Row(children: [
                  Expanded(child: TextField(controller: monthCtrl, keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: loc.t('center.ticket.monthLabel'),
                      border: const OutlineInputBorder(),
                      suffixText: loc.t('center.ticket.monthSuffix')))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: dayCtrl, keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: loc.t('center.ticket.dayLabel'),
                      border: const OutlineInputBorder(),
                      suffixText: loc.t('center.ticket.daySuffix')))),
                  const SizedBox(width: 12),
                  if (selectedType == 'PERIOD')
                    Expanded(child: TextField(controller: weekCtrl, keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.t('center.ticket.weekLabel'),
                        border: const OutlineInputBorder(),
                        suffixText: loc.t('center.ticket.weekSuffix'))))
                  else
                    Expanded(child: TextField(controller: countCtrl, keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.t('center.ticket.countLabel'),
                        border: const OutlineInputBorder(),
                        suffixText: loc.t('center.ticket.weekSuffix')))),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: loc.t('center.ticket.descLabel'),
                    border: const OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(loc.t('common.cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                  showErrorSnack(ctx, loc.t('center.ticket.errRequired'));
                  return;
                }
                try {
                  final updated = TicketModel(
                    ticketId: ticket?.ticketId,
                    gymId: ticket?.gymId,
                    ticketName: nameCtrl.text.trim(),
                    ticketCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                    durationMonths: int.tryParse(monthCtrl.text) ?? 0,
                    durationDays: dayCtrl.text.trim().isEmpty ? null : int.tryParse(dayCtrl.text),
                    weeklyDays: selectedType == 'PERIOD' ? (int.tryParse(weekCtrl.text) ?? 0) : 0,
                    price: int.tryParse(priceCtrl.text) ?? 0,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    ticketScope: 'GYM',
                    ticketType: selectedType,
                    totalCount: selectedType == 'COUNT' ? int.tryParse(countCtrl.text) : null,
                    sportType: ticket?.sportType ?? importedSportType ?? auth.sportType,
                  );
                  await ctx.read<ApiService>().saveTicket(updated);
                  if (ctx.mounted) { Navigator.pop(ctx); _load(); }
                } catch (e) {
                  if (ctx.mounted) {
                    showErrorSnack(ctx,
                      loc.t('center.ticket.saveFail', params: {'e': e.toString()}));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              child: Text(loc.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeCard({
    required IconData icon,
    required String label,
    required String desc,
    required String value,
    required String current,
    required Color color,
    required VoidCallback onTap,
  }) {
    final selected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: selected ? color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
              color: selected ? Colors.white : Colors.grey.shade500,
              size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(label,
                  style: TextStyle(
                    color: selected ? color : Colors.grey.shade700,
                    fontWeight: FontWeight.w700, fontSize: 14,
                  )),
                const SizedBox(width: 4),
                if (selected) Icon(Icons.check_circle, color: color, size: 16),
              ]),
              const SizedBox(height: 2),
              Text(desc,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }

  void _confirmDelete(TicketModel ticket) {
    final loc = context.read<LocaleProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('center.ticket.deleteTitle')),
        content: Text(loc.t('center.ticket.deleteConfirm',
          params: {'n': ticket.ticketName})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<ApiService>().deleteTicket(ticket.ticketId!);
                if (context.mounted) { Navigator.pop(context); _load(); }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnack(context,
                    loc.t('center.ticket.deleteFail', params: {'e': e.toString()}));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('center.ticket.delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final filtered = _gymTickets;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('center.ticket.title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text(loc.t('center.ticket.gymCountSummary',
                params: {'n': filtered.length.toString()}),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('center.ticket.add')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.card_membership_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(loc.t('center.ticket.empty'),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add),
                    label: Text(loc.t('center.ticket.addFirst')),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                  ),
                ]),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _buildTicketCard(loc, filtered[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(LocaleProvider loc, TicketModel t) {
    const accentColor = Color(0xFF1565C0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: t.isCount ? Colors.purple.shade50 : Colors.teal.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: (t.isCount ? Colors.purple : Colors.teal).withOpacity(0.3)),
              ),
              child: Text(t.isCount ? loc.t('center.ticket.badge.count') : loc.t('center.ticket.badge.period'),
                style: TextStyle(
                  color: t.isCount ? Colors.purple : Colors.teal,
                  fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
              onPressed: () => _showForm(t),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: loc.t('center.ticket.edit'),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              onPressed: () => _confirmDelete(t),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: loc.t('center.ticket.delete'),
            ),
          ]),
          const SizedBox(height: 8),
          Text(t.ticketName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (t.ticketCode != null && t.ticketCode!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(t.ticketCode!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
          const SizedBox(height: 6),
          Text(_durationText(loc, t), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const Spacer(),
          Text(loc.t('acc.wonAmount', params: {'v': _fmtPrice(t.price)}),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor)),
        ]),
      ),
    );
  }

  String _durationText(LocaleProvider loc, TicketModel t) {
    final parts = <String>[];
    if (t.durationMonths > 0) {
      parts.add(loc.t('center.ticket.monthsN', params: {'m': t.durationMonths.toString()}));
    }
    if (t.durationDays != null && t.durationDays! > 0) {
      parts.add(loc.t('center.ticket.daysN', params: {'d': t.durationDays.toString()}));
    }
    final dur = parts.isEmpty ? '' : parts.join(' ');

    if (t.isCount) {
      final count = t.totalCount != null
          ? loc.t('center.ticket.totalCount', params: {'n': t.totalCount.toString()})
          : loc.t('center.ticket.totalCountDash');
      return dur.isEmpty ? count : '$count | $dur';
    }

    final week = t.weeklyDays == 0
        ? loc.t('center.ticket.weeklyUnlimited')
        : loc.t('center.ticket.weeklyN', params: {'n': t.weeklyDays.toString()});
    return dur.isEmpty ? week : '$dur | $week';
  }

  String _fmtPrice(int price) =>
      price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
