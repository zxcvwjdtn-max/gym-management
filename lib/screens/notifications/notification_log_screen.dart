import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class NotificationLogScreen extends StatefulWidget {
  const NotificationLogScreen({super.key});
  @override
  State<NotificationLogScreen> createState() => _NotificationLogScreenState();
}

class _NotificationLogScreenState extends State<NotificationLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getNotificationLogs(
        from: _fmt(_from), to: _fmt(_to));
      if (mounted) setState(() { _logs = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final loc = context.read<LocaleProvider>();
    final picked = await showDatePicker(
      context: context, initialDate: _from,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      locale: loc.locale);
    if (picked != null) { setState(() => _from = picked); _load(); }
  }

  Future<void> _pickTo() async {
    final loc = context.read<LocaleProvider>();
    final picked = await showDatePicker(
      context: context, initialDate: _to,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      locale: loc.locale);
    if (picked != null) { setState(() => _to = picked); _load(); }
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
            Text(loc.t('noti.log.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 20),
            OutlinedButton.icon(
              onPressed: _pickFrom,
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(_fmt(_from)),
            ),
            const SizedBox(width: 8),
            const Text('~'),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickTo,
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(_fmt(_to)),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(loc.t('noti.log.countN', params: {'n': _logs.length.toString()}),
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_logs.isEmpty)
            Expanded(child: Center(
              child: Text(loc.t('noti.log.empty'), style: const TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: [
                        DataColumn(label: Text(loc.t('noti.log.col.date'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('noti.log.col.recipient'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('noti.log.col.phone'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('noti.log.col.content'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(loc.t('noti.log.col.status'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _logs.map((log) {
                        final ok = log['status'] == 'SUCCESS';
                        return DataRow(cells: [
                          DataCell(Text(log['sentAt']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
                          DataCell(Text(log['memberName'] ?? '-')),
                          DataCell(Text(log['phone'] ?? '-')),
                          DataCell(Tooltip(
                            message: log['message'] ?? '',
                            child: Text(
                              (log['message'] ?? '').toString().length > 20
                                  ? '${log['message'].toString().substring(0, 20)}...'
                                  : log['message'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ok ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(ok ? loc.t('noti.log.status.success') : loc.t('noti.log.status.failed'),
                              style: TextStyle(
                                color: ok ? Colors.green : Colors.red,
                                fontSize: 12, fontWeight: FontWeight.bold)),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
