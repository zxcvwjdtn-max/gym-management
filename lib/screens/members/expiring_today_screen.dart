import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/member_table.dart';

class ExpiringTodayScreen extends StatefulWidget {
  const ExpiringTodayScreen({super.key});
  @override
  State<ExpiringTodayScreen> createState() => _ExpiringTodayScreenState();
}

class _ExpiringTodayScreenState extends State<ExpiringTodayScreen> {
  List<MemberModel> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<ApiService>().getExpiringToday();
      if (mounted) setState(() { _members = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
            const Icon(Icons.event_busy, color: Colors.orange, size: 26),
            const SizedBox(width: 10),
            Text(loc.t('expiringToday.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(loc.t('common.memberCount',
                  params: {'n': _members.length.toString()}),
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loc.t('common.refresh')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_members.isEmpty)
            Expanded(child: Center(
              child: Text(loc.t('expiringToday.empty'),
                  style: const TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: MemberTable(members: _members, onRefresh: _load),
            ),
        ],
      ),
    );
  }
}
