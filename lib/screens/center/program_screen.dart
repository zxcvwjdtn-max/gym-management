import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});
  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  List<TicketModel> _all = [];
  bool _loading = true;

  List<TicketModel> get _ptPrograms =>
      _all.where((t) => t.isCount).toList();

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
    final nameCtrl  = TextEditingController(text: ticket?.ticketName ?? '');
    final priceCtrl = TextEditingController(text: ticket?.price != null ? ticket!.price.toString() : '');
    final countCtrl = TextEditingController(text: ticket?.totalCount?.toString() ?? '');
    final monthCtrl = TextEditingController(text: ticket?.durationMonths.toString() ?? '3');
    final descCtrl  = TextEditingController(text: ticket?.description ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.fitness_center, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 8),
          Text(ticket == null ? loc.t('ptProgram.add') : loc.t('ptProgram.editTitle')),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: loc.t('ptProgram.nameLabel'),
                  hintText: loc.t('ptProgram.nameHint'),
                  border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: countCtrl, keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: loc.t('ptProgram.countLabel'),
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('ptProgram.countSuffix')))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: loc.t('ptProgram.priceLabel'),
                    border: const OutlineInputBorder(),
                    suffixText: loc.t('ptProgram.priceSuffix')))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: monthCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc.t('ptProgram.validityLabel'),
                  border: const OutlineInputBorder(),
                  suffixText: loc.t('ptProgram.validitySuffix'),
                  helperText: loc.t('ptProgram.validityHelper'))),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2,
                decoration: InputDecoration(
                  labelText: loc.t('ptProgram.descLabel'),
                  border: const OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || countCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                showErrorSnack(context, loc.t('ptProgram.errRequired'));
                return;
              }
              try {
                final t = TicketModel(
                  ticketId: ticket?.ticketId,
                  gymId: ticket?.gymId,
                  ticketName: nameCtrl.text.trim(),
                  price: int.tryParse(priceCtrl.text) ?? 0,
                  durationMonths: int.tryParse(monthCtrl.text) ?? 0,
                  weeklyDays: 0,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  ticketScope: ticket?.ticketScope ?? 'GYM',
                  ticketType: 'COUNT',
                  totalCount: int.tryParse(countCtrl.text),
                  sportType: ticket?.sportType ?? auth.sportType,
                );
                await context.read<ApiService>().saveTicket(t);
                if (context.mounted) { Navigator.pop(context); _load(); }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnack(context, loc.t('ptProgram.saveFail',
                    params: {'e': e.toString()}));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            child: Text(loc.t('common.save')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(TicketModel ticket) {
    final loc = context.read<LocaleProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('ptProgram.deleteTitle')),
        content: Text(loc.t('ptProgram.deleteConfirm',
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
                    loc.t('ptProgram.deleteFail', params: {'e': e.toString()}));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: Text(loc.t('ptProgram.delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final programs = _ptPrograms;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(loc.t('ptProgram.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text(loc.t('ptProgram.countSummary',
                params: {'n': programs.length.toString()}),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('ptProgram.add')),
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
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (programs.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(loc.t('ptProgram.empty'),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add),
                    label: Text(loc.t('ptProgram.addFirst')),
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
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: programs.length,
                itemBuilder: (context, i) => _buildCard(loc, programs[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(LocaleProvider loc, TicketModel t) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fitness_center,
                color: Color(0xFF1565C0), size: 20),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Text(loc.t('ptProgram.badge'),
                style: const TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: (v) {
                if (v == 'edit') _showForm(t);
                else if (v == 'delete') _confirmDelete(t);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(loc.t('ptProgram.edit'))),
                PopupMenuItem(value: 'delete',
                  child: Text(loc.t('ptProgram.delete'),
                    style: const TextStyle(color: Colors.red))),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Text(t.ticketName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(
            t.totalCount != null
              ? loc.t('ptProgram.sessionsN', params: {'n': t.totalCount.toString()})
              : loc.t('ptProgram.sessionsDash'),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            t.durationMonths > 0
              ? loc.t('ptProgram.validMonths', params: {'m': t.durationMonths.toString()})
              : loc.t('ptProgram.validUnlimited'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const Spacer(),
          Text(loc.t('acc.wonAmount', params: {'v': _fmt(t.price)}),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0))),
        ]),
      ),
    );
  }

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
