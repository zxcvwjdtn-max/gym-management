import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';

class AutoNotificationScreen extends StatelessWidget {
  const AutoNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final rules = [
      _AutoRule(
        titleKey: 'noti.auto.rule.d3.title',
        descKey: 'noti.auto.rule.d3.desc',
        icon: Icons.event_busy,
        color: Colors.orange,
        enabled: true,
      ),
      _AutoRule(
        titleKey: 'noti.auto.rule.dday.title',
        descKey: 'noti.auto.rule.dday.desc',
        icon: Icons.notifications_active,
        color: Colors.red,
        enabled: true,
      ),
      _AutoRule(
        titleKey: 'noti.auto.rule.birthday.title',
        descKey: 'noti.auto.rule.birthday.desc',
        icon: Icons.cake,
        color: Colors.pink,
        enabled: false,
      ),
      _AutoRule(
        titleKey: 'noti.auto.rule.absent.title',
        descKey: 'noti.auto.rule.absent.desc',
        icon: Icons.bedtime,
        color: Colors.indigo,
        enabled: false,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.t('noti.auto.title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(loc.t('noti.auto.subtitle'),
            style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _AutoRuleCard(rule: rules[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoRule {
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final bool enabled;
  _AutoRule({required this.titleKey, required this.descKey, required this.icon,
      required this.color, required this.enabled});
}

class _AutoRuleCard extends StatefulWidget {
  final _AutoRule rule;
  const _AutoRuleCard({required this.rule});

  @override
  State<_AutoRuleCard> createState() => _AutoRuleCardState();
}

class _AutoRuleCardState extends State<_AutoRuleCard> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.rule.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.rule.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.rule.icon, color: widget.rule.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.t(widget.rule.titleKey),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(loc.t(widget.rule.descKey),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeColor: widget.rule.color,
              ),
              Text(_enabled ? loc.t('noti.auto.active') : loc.t('noti.auto.inactive'),
                style: TextStyle(
                  color: _enabled ? widget.rule.color : Colors.grey,
                  fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ]),
      ),
    );
  }
}
