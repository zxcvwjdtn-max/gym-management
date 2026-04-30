import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/app_select.dart';

class UnpaidScreen extends StatefulWidget {
  const UnpaidScreen({super.key});
  @override
  State<UnpaidScreen> createState() => _UnpaidScreenState();
}

class _UnpaidScreenState extends State<UnpaidScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getUnpaidList();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnack(context, '미수금 조회 실패: $e');
      }
    }
  }

  int get _total => _data.fold(0, (s, e) => s + (e['amount'] as int? ?? 0));

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 헤더 ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            const Icon(Icons.money_off, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            const Text('미수금 관리',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            if (!_loading) ...[
              _Badge('${_data.length}건', Colors.orange),
              const SizedBox(width: 8),
              _Badge('총 ${_fmt(_total)}원', Colors.red),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),

        // ── 테이블 헤더 ────────────────────────────────────────
        Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(children: [
            _hcell('회원명', flex: 2),
            _hcell('이용권 / 내용', flex: 4),
            _hcell('미수금액', flex: 2),
            _hcell('등록일', flex: 2),
            _hcell('이용권 시작일', flex: 2),
            _hcell('수납', flex: 2),
          ]),
        ),
        const Divider(height: 1),

        // ── 리스트 ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _data.isEmpty
                  ? const Center(
                      child: Text('미수금 내역이 없습니다.',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _data.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) => _UnpaidRow(
                        row: _data[i],
                        onReceived: _load,
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _hcell(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
  );
}

// ─── 뱃지 ──────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
  );
}

// ─── 미수금 행 ──────────────────────────────────────────────────────
class _UnpaidRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onReceived;
  const _UnpaidRow({required this.row, required this.onReceived});

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Widget _dateCell(String date) => Row(children: [
    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
    const SizedBox(width: 4),
    Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
  ]);

  @override
  Widget build(BuildContext context) {
    final amount     = row['amount'] as int? ?? 0;
    final name       = row['memberName'] as String? ?? '-';
    final desc       = row['description'] as String? ?? '-';
    final startDate  = row['accountingDate'] as String? ?? '-';
    final createdRaw = row['createdAt'] as String? ?? '';
    final createdDate = createdRaw.length >= 10 ? createdRaw.substring(0, 10) : createdRaw;
    final id         = row['accountingId'] as int?;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: [
        // 회원명
        Expanded(
          flex: 2,
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),

        // 이용권/내용
        Expanded(
          flex: 4,
          child: Text(desc,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),

        // 금액
        Expanded(
          flex: 2,
          child: Text('${_fmt(amount)}원',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
        ),

        // 등록일 (created_at)
        Expanded(
          flex: 2,
          child: _dateCell(createdDate.isEmpty ? '-' : createdDate),
        ),

        // 이용권 시작일 (accounting_date)
        Expanded(
          flex: 2,
          child: _dateCell(startDate),
        ),

        // 수납 버튼
        Expanded(
          flex: 2,
          child: id == null
              ? const SizedBox()
              : ElevatedButton.icon(
                  onPressed: () => _showReceiveDialog(context, id, name, amount),
                  icon: const Icon(Icons.payments, size: 14),
                  label: const Text('수납', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
        ),
      ]),
    );
  }

  void _showReceiveDialog(BuildContext context, int id, String memberName, int amount) {
    showDialog(
      context: context,
      builder: (_) => _ReceiveDialog(
        accountingId: id,
        memberName: memberName,
        amount: amount,
        onReceived: onReceived,
      ),
    );
  }
}

// ─── 수납 처리 다이얼로그 ───────────────────────────────────────────
class _ReceiveDialog extends StatefulWidget {
  final int accountingId;
  final String memberName;
  final int amount;
  final VoidCallback onReceived;

  const _ReceiveDialog({
    required this.accountingId,
    required this.memberName,
    required this.amount,
    required this.onReceived,
  });

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  String _method = 'CASH';
  String? _cardCompany;
  bool _saving = false;

  static const _cardCompanies = [
    'BC카드', '신한카드', '현대카드', '삼성카드', '롯데카드',
    '하나카드', 'NH농협카드', 'KB국민카드', '씨티카드', '우리카드', '카카오뱅크',
  ];

  String _fmt(int v) => v.toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().receiveUnpaid(
        widget.accountingId,
        paymentMethod: _method,
        cardCompany: _method == 'CARD' ? _cardCompany : null,
      );
      widget.onReceived();
      if (mounted) {
        Navigator.pop(context);
        showSuccessSnack(context, '수납 처리가 완료되었습니다.');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, '수납 처리 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('수납 처리'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 요약
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(children: [
                Row(children: [
                  const Text('회원', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 16),
                  Text(widget.memberName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Text('미수금액', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 16),
                  Text('${_fmt(widget.amount)}원',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold, fontSize: 17)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // 결제방법
            FormSelect<String>(
              label: '결제방법',
              currentLabel: const {'CARD': '카드', 'CASH': '현금', 'TRANSFER': '계좌이체'}[_method],
              hint: '선택',
              options: const [('카드', 'CARD'), ('현금', 'CASH'), ('계좌이체', 'TRANSFER')],
              onSelected: (v) {
                if (v != null) setState(() {
                  _method = v;
                  if (v != 'CARD') _cardCompany = null;
                });
              },
            ),

            // 카드사 선택
            if (_method == 'CARD') ...[
              const SizedBox(height: 12),
              FormSelect<String>(
                label: '카드사',
                currentLabel: _cardCompany,
                hint: '카드사 선택 (선택사항)',
                options: _cardCompanies.map((c) => (c, c)).toList(),
                onSelected: (v) => setState(() => _cardCompany = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _confirm,
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check, size: 16),
          label: const Text('수납 처리'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
