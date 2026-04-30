import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import 'member_form_screen.dart';
import '../../widgets/app_select.dart';
import '../../widgets/member_table.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});
  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  List<MemberModel> _members = [];
  bool _loading = true;
  final Set<int> _selected = {};

  // 검색 조건
  final _keywordCtrl = TextEditingController();
  String? _typeFilter;
  String? _statusFilter;
  String? _clothFilter;
  String? _lockerFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _selected.clear(); });
    try {
      final api = context.read<ApiService>();
      var list = await api.getMembers(
        keyword: _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim(),
        memberType: _typeFilter,
        membershipStatus: _statusFilter,
      );
      // 옷·락카 대여 필터는 클라이언트에서 적용
      if (_clothFilter != null) {
        list = list.where((m) => m.clothRentalYn == _clothFilter).toList();
      }
      if (_lockerFilter != null) {
        list = list.where((m) => m.lockerRentalYn == _lockerFilter).toList();
      }
      if (mounted) setState(() { _members = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _typeLabel(LocaleProvider loc, String? v) {
    const keys = {'REGULAR': 'memberList.type.regular', 'GROUP': 'memberList.type.group', 'VIP': 'memberList.type.vip'};
    final k = keys[v];
    return k == null ? loc.t('common.all') : loc.t(k);
  }

  String _statusLabel(LocaleProvider loc, String? v) {
    const keys = {
      'ACTIVE': 'memberList.status.active',
      'EXPIRED': 'memberList.status.expired',
      'SUSPENDED': 'memberList.status.suspended',
      'PAUSED': 'memberList.status.paused',
    };
    final k = keys[v];
    return k == null ? loc.t('common.all') : loc.t(k);
  }

  String _rentalLabel(LocaleProvider loc, String? v) =>
      v == 'Y' ? loc.t('memberList.rental.rented')
      : v == 'N' ? loc.t('memberList.rental.none')
      : loc.t('common.all');

  void _reset() {
    setState(() {
      _keywordCtrl.clear();
      _typeFilter = null;
      _statusFilter = null;
      _clothFilter = null;
      _lockerFilter = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Row(children: [
            Text(loc.t('menu.member_list'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const MemberFormScreen()),
                );
                if (result == true) _load();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.t('member.addBtn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // ── 검색 패널 ──
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 이름/번호 키워드
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _keywordCtrl,
                      decoration: InputDecoration(
                        hintText: loc.t('memberList.searchHint'),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterPill<String?>(
                    label: loc.t('memberList.filter.type'),
                    selectedLabel: _typeLabel(loc, _typeFilter),
                    isActive: _typeFilter != null,
                    options: [
                      (loc.t('common.all'), null),
                      (loc.t('memberList.type.regular'), 'REGULAR'),
                      (loc.t('memberList.type.group'), 'GROUP'),
                      (loc.t('memberList.type.vip'), 'VIP'),
                    ],
                    onSelected: (v) => setState(() => _typeFilter = v),
                  ),
                  const SizedBox(width: 8),
                  FilterPill<String?>(
                    label: loc.t('memberList.filter.status'),
                    selectedLabel: _statusLabel(loc, _statusFilter),
                    isActive: _statusFilter != null,
                    options: [
                      (loc.t('common.all'), null),
                      (loc.t('memberList.status.active'), 'ACTIVE'),
                      (loc.t('memberList.status.expired'), 'EXPIRED'),
                      (loc.t('memberList.status.suspended'), 'SUSPENDED'),
                      (loc.t('memberList.status.paused'), 'PAUSED'),
                    ],
                    onSelected: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(width: 8),
                  FilterPill<String?>(
                    label: loc.t('memberList.filter.cloth'),
                    selectedLabel: _rentalLabel(loc, _clothFilter),
                    isActive: _clothFilter != null,
                    options: [
                      (loc.t('common.all'), null),
                      (loc.t('memberList.rental.rented'), 'Y'),
                      (loc.t('memberList.rental.none'), 'N'),
                    ],
                    onSelected: (v) => setState(() => _clothFilter = v),
                  ),
                  const SizedBox(width: 8),
                  FilterPill<String?>(
                    label: loc.t('memberList.filter.locker'),
                    selectedLabel: _rentalLabel(loc, _lockerFilter),
                    isActive: _lockerFilter != null,
                    options: [
                      (loc.t('common.all'), null),
                      (loc.t('memberList.rental.rented'), 'Y'),
                      (loc.t('memberList.rental.none'), 'N'),
                    ],
                    onSelected: (v) => setState(() => _lockerFilter = v),
                  ),
                  const Spacer(),
                  // 조회 버튼
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(loc.t('memberList.actionSearch')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 초기화 버튼
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.t('memberList.actionReset')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── 결과 건수 ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              _loading ? '' : loc.t('memberList.totalCount', params: {'n': _members.length.toString()}),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : MemberTable(
                    members: _members,
                    selected: _selected,
                    onSelectionChanged: (idx, v) => setState(() {
                      if (v) { _selected.add(idx); } else { _selected.remove(idx); }
                    }),
                    onRefresh: _load,
                  ),
          ),
        ],
      ),
    );
  }
}



