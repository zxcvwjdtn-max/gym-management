import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

class NotificationTemplateScreen extends StatefulWidget {
  const NotificationTemplateScreen({super.key});
  @override
  State<NotificationTemplateScreen> createState() => _NotificationTemplateScreenState();
}

class _NotificationTemplateScreenState extends State<NotificationTemplateScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getNotificationTemplates();
      if (mounted) setState(() { _templates = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForm([Map<String, dynamic>? tpl]) {
    final loc = context.read<LocaleProvider>();
    final nameCtrl = TextEditingController(text: tpl?['templateName'] ?? '');
    final contentCtrl = TextEditingController(text: tpl?['content'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tpl == null ? loc.t('noti.template.add') : loc.t('noti.template.editTitle')),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: loc.t('noti.template.nameLabel'),
                  border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: loc.t('noti.template.contentLabel'),
                  border: const OutlineInputBorder(),
                  helperText: loc.t('noti.template.helper'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            child: Text(loc.t('common.save')),
          ),
        ],
      ),
    );
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
            Text(loc.t('noti.template.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('noti.template.add')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_templates.isEmpty)
            Expanded(child: Center(
              child: Text(loc.t('noti.template.empty'),
                style: const TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 350,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _templates.length,
                itemBuilder: (context, i) {
                  final t = _templates[i];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.text_snippet, color: Color(0xFF1565C0), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(t['templateName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _showForm(t);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(loc.t('noti.template.edit'))),
                                PopupMenuItem(value: 'delete', child: Text(loc.t('noti.template.delete'))),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              t['content'] ?? '',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
