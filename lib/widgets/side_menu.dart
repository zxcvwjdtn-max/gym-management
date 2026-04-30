import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class MenuItem {
  final String label;
  final IconData icon;
  final String route;
  final List<MenuItem> children;

  const MenuItem({
    required this.label,
    required this.icon,
    required this.route,
    this.children = const [],
  });
}

/// 현재 로케일 기준으로 메뉴 트리를 생성
List<MenuItem> buildMenuTree(LocaleProvider loc) => [
  MenuItem(label: loc.t('menu.dashboard'), icon: Icons.dashboard, route: 'dashboard'),
  MenuItem(
    label: loc.t('menu.members'),
    icon: Icons.people,
    route: 'members',
    children: [
      MenuItem(label: loc.t('menu.member_list'),    icon: Icons.list,        route: 'member_list'),
      MenuItem(label: loc.t('menu.member_group'),   icon: Icons.group,       route: 'member_group'),
      MenuItem(label: loc.t('menu.expiring_today'), icon: Icons.event_busy,  route: 'expiring_today'),
      MenuItem(label: loc.t('menu.inactive'),       icon: Icons.bedtime,     route: 'inactive'),
      MenuItem(label: loc.t('menu.suspended'),      icon: Icons.block,       route: 'suspended'),
      MenuItem(label: loc.t('menu.birthdays'),      icon: Icons.cake,        route: 'birthdays'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.attendance'),
    icon: Icons.fact_check,
    route: 'attendance',
    children: [
      MenuItem(label: loc.t('menu.attendance_check'),  icon: Icons.how_to_reg,  route: 'attendance_check'),
      MenuItem(label: loc.t('menu.attendance_status'), icon: Icons.bar_chart,   route: 'attendance_status'),
      MenuItem(label: loc.t('menu.hourly_attendance'), icon: Icons.access_time, route: 'hourly_attendance'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.notifications'),
    icon: Icons.notifications,
    route: 'notifications',
    children: [
      MenuItem(label: loc.t('menu.notification_send'),     icon: Icons.send,         route: 'notification_send'),
      MenuItem(label: loc.t('menu.notification_auto'),     icon: Icons.auto_mode,    route: 'notification_auto'),
      MenuItem(label: loc.t('menu.notification_template'), icon: Icons.text_snippet, route: 'notification_template'),
      MenuItem(label: loc.t('menu.notification_log'),      icon: Icons.history,      route: 'notification_log'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.accounting'),
    icon: Icons.account_balance_wallet,
    route: 'accounting',
    children: [
      MenuItem(label: loc.t('menu.daily_sales'),        icon: Icons.today,           route: 'daily_sales'),
      MenuItem(label: loc.t('menu.monthly_sales'),      icon: Icons.calendar_month,  route: 'monthly_sales'),
      MenuItem(label: loc.t('menu.yearly_sales'),       icon: Icons.calendar_today,  route: 'yearly_sales'),
      MenuItem(label: loc.t('menu.unpaid'),             icon: Icons.money_off,       route: 'unpaid'),
      MenuItem(label: loc.t('menu.monthly_settlement'), icon: Icons.summarize,       route: 'monthly_settlement'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.statistics'),
    icon: Icons.analytics,
    route: 'statistics',
    children: [
      MenuItem(label: loc.t('menu.visit_stats'), icon: Icons.show_chart, route: 'visit_stats'),
      MenuItem(label: loc.t('menu.sales_stats'), icon: Icons.pie_chart,  route: 'sales_stats'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.pt'),
    icon: Icons.sports,
    route: 'pt',
    children: [
      MenuItem(label: loc.t('menu.pt_programs'),  icon: Icons.fitness_center, route: 'pt_program'),
      MenuItem(label: loc.t('menu.pt_contracts'), icon: Icons.assignment_ind, route: 'pt_contracts'),
      MenuItem(label: loc.t('menu.pt_sessions'),  icon: Icons.how_to_reg,     route: 'pt_sessions'),
      MenuItem(label: loc.t('menu.pt_schedule'),  icon: Icons.schedule,       route: 'pt_schedule'),
    ],
  ),
  MenuItem(
    label: '전자계약',
    icon: Icons.draw_outlined,
    route: 'contract',
    children: [
      MenuItem(label: '계약서 템플릿', icon: Icons.article_outlined, route: 'contract_template'),
      MenuItem(label: '입회 대기',    icon: Icons.pending_actions,   route: 'contract_waiting'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.community'),
    icon: Icons.forum,
    route: 'community',
    children: [
      MenuItem(label: loc.t('menu.notice'),  icon: Icons.campaign,       route: 'notice'),
      MenuItem(label: loc.t('menu.message'), icon: Icons.message,        route: 'message'),
      MenuItem(label: loc.t('menu.workout'), icon: Icons.fitness_center, route: 'workout'),
    ],
  ),
  MenuItem(
    label: loc.t('menu.center'),
    icon: Icons.business,
    route: 'center',
    children: [
      MenuItem(label: loc.t('menu.staff'),             icon: Icons.manage_accounts,   route: 'staff'),
      MenuItem(label: loc.t('menu.ticket'),            icon: Icons.card_membership,   route: 'ticket'),
      MenuItem(label: loc.t('menu.locker'),            icon: Icons.lock,              route: 'locker'),
      MenuItem(label: loc.t('menu.group_def'),         icon: Icons.label,             route: 'group_def'),
      MenuItem(label: loc.t('menu.bulk_extend'),       icon: Icons.date_range,        route: 'bulk_extend'),
      MenuItem(label: loc.t('menu.excel_upload'),      icon: Icons.upload_file,       route: 'excel_upload'),
      MenuItem(label: loc.t('menu.center_accounting'), icon: Icons.receipt_long,      route: 'center_accounting'),
      MenuItem(label: loc.t('menu.settings'),          icon: Icons.settings,          route: 'settings'),
    ],
  ),
];

class SideMenu extends StatefulWidget {
  final String selectedRoute;
  final void Function(String route) onSelect;

  const SideMenu({super.key, required this.selectedRoute, required this.onSelect});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final Set<String> _expandedParents = {'members', 'attendance'};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loc = context.watch<LocaleProvider>();
    final menuTree = buildMenuTree(loc);
    return Container(
      width: 230,
      color: const Color(0xFF0D1B2A),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: const Color(0xFF1565C0),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.gymName ?? 'GymPRO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (auth.branchName != null && auth.branchName!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              auth.branchName!,
                              style: const TextStyle(color: Colors.white, fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (auth.gymCode != null && auth.gymCode!.isNotEmpty)
                          Text(
                            auth.gymCode!,
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        if (auth.gymCode != null && auth.gymCode!.isNotEmpty &&
                            auth.sportType != null && auth.sportType!.isNotEmpty)
                          const Text(' · ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        if (auth.sportType != null && auth.sportType!.isNotEmpty)
                          Text(
                            auth.sportType!,
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        auth.adminName ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...menuTree.map((item) => _buildMenuItem(item)),
                if (auth.isSuperAdmin) ...[
                  const Divider(color: Colors.white12, height: 20, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(loc.t('menu.superadmin'), style: const TextStyle(
                      color: Colors.white30, fontSize: 11, letterSpacing: 1)),
                  ),
                  _buildMenuTile(
                    label: loc.t('menu.super_gym'),
                    icon: Icons.business_outlined,
                    route: 'super_gym',
                    selected: widget.selectedRoute == 'super_gym',
                    onTap: () => widget.onSelect('super_gym'),
                  ),
                  _buildMenuTile(
                    label: loc.t('menu.super_ticket'),
                    icon: Icons.card_membership_outlined,
                    route: 'super_ticket',
                    selected: widget.selectedRoute == 'super_ticket',
                    onTap: () => widget.onSelect('super_ticket'),
                  ),
                  _buildMenuTile(
                    label: loc.t('menu.super_gym_ad'),
                    icon: Icons.campaign_outlined,
                    route: 'super_gym_ad',
                    selected: widget.selectedRoute == 'super_gym_ad',
                    onTap: () => widget.onSelect('super_gym_ad'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.teal, size: 20),
            title: const Text('원격지원 요청',
                style: TextStyle(color: Colors.teal, fontSize: 14)),
            onTap: () => _launchRemoteSupport(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white54, size: 20),
            title: Text(loc.t('menu.logout'),
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _launchRemoteSupport(BuildContext context) async {
    // Windows: ms-quick-assist: 프로토콜 실행
    // 웹/기타: 안내 메시지
    final uri = Uri.parse(kIsWeb ? 'https://support.microsoft.com' : 'ms-quick-assist:');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(kIsWeb
              ? '원격지원은 Windows 앱에서 실행해주세요.'
              : '원격지원 실행 실패: $e')),
        );
      }
    }
  }

  // 메뉴 항목 빌드 (자식 있으면 확장형, 없으면 단일 타일)
  Widget _buildMenuItem(MenuItem item) {
    if (item.children.isEmpty) {
      final selected = widget.selectedRoute == item.route;
      return _buildMenuTile(
        label: item.label, icon: item.icon, route: item.route,
        selected: selected, onTap: () => widget.onSelect(item.route),
      );
    }

    final isExpanded = _expandedParents.contains(item.route);
    final childSelected = item.children.any((c) => c.route == widget.selectedRoute);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isExpanded || childSelected,
        onExpansionChanged: (v) {
          setState(() {
            if (v) _expandedParents.add(item.route);
            else _expandedParents.remove(item.route);
          });
        },
        leading: Icon(item.icon, color: childSelected ? Colors.blue.shade300 : Colors.white54, size: 20),
        title: Text(item.label,
          style: TextStyle(
            color: childSelected ? Colors.blue.shade300 : Colors.white70,
            fontSize: 14, fontWeight: childSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Icon(
          isExpanded || childSelected ? Icons.expand_less : Icons.expand_more,
          color: Colors.white38, size: 16,
        ),
        children: item.children.map((child) {
          final sel = widget.selectedRoute == child.route;
          return InkWell(
            onTap: () => widget.onSelect(child.route),
            child: Container(
              color: sel ? Colors.blue.shade900.withOpacity(0.5) : Colors.transparent,
              padding: const EdgeInsets.only(left: 52, right: 16, top: 10, bottom: 10),
              child: Row(
                children: [
                  Icon(child.icon, size: 16, color: sel ? Colors.blue.shade200 : Colors.white38),
                  const SizedBox(width: 10),
                  Text(child.label, style: TextStyle(
                    color: sel ? Colors.blue.shade200 : Colors.white60,
                    fontSize: 13,
                  )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 단일 메뉴 타일 빌드
  Widget _buildMenuTile({
    required String label, required IconData icon, required String route,
    required bool selected, required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? Colors.blue.shade900.withOpacity(0.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? Colors.blue.shade300 : Colors.white54),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              color: selected ? Colors.blue.shade200 : Colors.white70,
              fontSize: 14, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }
}
