// ──────────────────────────────────────────────────────────────
// member_accounting_tab.dart
// 회원 상세 > 탭 2: 매출현황
// _AccountingTab, _AccountingTabState, _AccountingRow
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';

// ──────────────────────────────────────────────────────────────
// 탭 2: 매출현황
// ──────────────────────────────────────────────────────────────
class MemberAccountingTab extends StatefulWidget {
  final int memberId;
  const MemberAccountingTab({required this.memberId});

  @override
  State<MemberAccountingTab> createState() => _AccountingTabState();
}

class _AccountingTabState extends State<MemberAccountingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<AccountingModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 해당 회원의 매출 목록 조회
  Future<void> _load() async {
    try {
      final data = await context.read<ApiService>().getMemberAccounting(widget.memberId);
      if (mounted) setState(() { _list = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    // 총 매출 계산 (수입 - 지출)
    final total = _list.fold<int>(0, (s, e) {
      if (e.accountingType == 'INCOME') return s + (e.amount ?? 0);
      return s - (e.amount ?? 0);
    });

    final loc = context.watch<LocaleProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 합계 카드
        Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              Text(loc.t('member.acc.totalRevenue'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_fmt(total)}원',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: total >= 0 ? const Color(0xFF1565C0) : Colors.red,
                )),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (_list.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(loc.t('member.acc.empty'), style: const TextStyle(color: Colors.grey)),
          ))
        else
          ..._list.map((acc) => _AccountingRow(acc: acc)),
      ],
    );
  }

  /// 숫자를 천 단위 쉼표 포맷으로 변환 (음수 포함)
  String _fmt(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return (v < 0 ? '-' : '') + buf.toString();
  }
}

/// 매출 내역 한 행
class _AccountingRow extends StatelessWidget {
  final AccountingModel acc;
  const _AccountingRow({required this.acc});

  @override
  Widget build(BuildContext context) {
    final isIncome = acc.accountingType == 'INCOME';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
            color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(acc.description ?? _categoryText(acc.category),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            Text(acc.accountingDate ?? '',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        )),
        Text(
          '${isIncome ? '+' : '-'}${_fmtNum(acc.amount ?? 0)}원',
          style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16,
            color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ]),
    );
  }

  /// 카테고리 코드 → 한국어 표시
  String _categoryText(String? c) {
    switch (c) {
      case 'TICKET': return '이용권';
      case 'ETC_INCOME': return '기타수입';
      case 'PURCHASE': return '매입';
      case 'UNPAID': return '미수금';
      default: return c ?? '-';
    }
  }

  /// 천 단위 쉼표 포맷
  String _fmtNum(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
