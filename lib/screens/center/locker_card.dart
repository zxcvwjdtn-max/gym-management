// 라커 카드 UI 컴포넌트 — LockerCard(개별 라커 카드), LockerSummaryCard(요약 통계 카드)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import 'locker_dialogs.dart';

// ──────────────────────────────────────────────────────────────
// 라커 카드 (소형)
// 상태에 따라 색상·라벨 변경, 선택 모드·삭제 지원
// ──────────────────────────────────────────────────────────────
class LockerCard extends StatelessWidget {
  final LockerModel locker;
  final bool isExpiring;    // 만료 임박 여부 (D-3 이하)
  final bool canDelete;     // 삭제 버튼 노출 여부
  final bool inSelectMode;  // 다중 선택 모드 활성화 여부
  final bool isSelected;    // 현재 선택 상태
  final VoidCallback? onToggleSelect; // 선택 토글 콜백
  final VoidCallback onRefresh;       // 목록 새로고침 콜백

  const LockerCard({
    required this.locker,
    required this.onRefresh,
    this.isExpiring = false,
    this.canDelete = false,
    this.inSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  /// 상태에 따른 전경색 반환
  Color get _color {
    if (isExpiring) return Colors.orange.shade700;
    return switch (locker.status) {
      'AVAILABLE'   => Colors.green.shade600,
      'OCCUPIED'    => const Color(0xFF1565C0),
      'MAINTENANCE' => Colors.red.shade600,
      _             => Colors.grey,
    };
  }

  /// 상태에 따른 배경색 반환
  Color get _bgColor {
    if (isExpiring) return Colors.orange.shade50;
    return switch (locker.status) {
      'AVAILABLE'   => Colors.green.shade50,
      'OCCUPIED'    => const Color(0xFFE3F2FD),
      'MAINTENANCE' => Colors.red.shade50,
      _             => Colors.grey.shade50,
    };
  }

  /// 상태 라벨 텍스트 반환 (i18n)
  String _labelText(BuildContext context) {
    final loc = context.read<LocaleProvider>();
    if (isExpiring) return loc.t('center.locker.status.expiring');
    return switch (locker.status) {
      'AVAILABLE'   => loc.t('center.locker.status.available'),
      'OCCUPIED'    => loc.t('center.locker.status.occupied'),
      'MAINTENANCE' => loc.t('center.locker.status.maintenance'),
      _             => locker.status ?? '',
    };
  }

  /// 종료일 기준 잔여 일수 계산
  int? get _remainDays {
    if (locker.endDate == null) return null;
    final end = DateTime.tryParse(locker.endDate!);
    return end?.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final days = _remainDays;
    final isAvailable = locker.status == 'AVAILABLE';
    final isOccupied  = locker.status == 'OCCUPIED';
    final labelText   = _labelText(context);

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: EdgeInsets.zero,
      color: _bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue : _color.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // 선택 모드면 선택 토글, 아니면 상세 다이얼로그 오픈
        onTap: inSelectMode ? onToggleSelect : () => _showDetail(context),
        child: Stack(
          children: [
            // 카드 본문
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 라커 번호
                    Text(locker.lockerNo ?? '-',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _color)),
                    const SizedBox(height: 3),
                    // 상태 라벨 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(labelText,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _color)),
                    ),
                    // 사용중: 회원 이름 표시
                    if (isOccupied && locker.memberName != null) ...[
                      const SizedBox(height: 3),
                      Text(locker.memberName!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _color),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                    // 만료 D-day 표시 (사용중인 경우)
                    if (days != null && isOccupied) ...[
                      const SizedBox(height: 2),
                      Text('D-$days',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: days <= 3 ? Colors.red.shade700 : Colors.grey.shade500)),
                    ],
                    // 삭제 아이콘 — 사용가능·점검중 상태이고 선택 모드가 아닐 때만 표시
                    if (canDelete && !inSelectMode && (isAvailable || locker.status == 'MAINTENANCE'))
                      GestureDetector(
                        onTap: () => _deleteOne(context),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: Colors.red.shade400),
                      ),
                  ],
                ),
              ),
            ),
            // 선택 모드 체크박스 (카드 우상단)
            if (inSelectMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade400,
                        width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 라커 상세 다이얼로그 표시
  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => LockerDetailDialog(locker: locker, onAction: onRefresh),
    );
  }

  /// 단건 삭제 확인 후 삭제 처리
  Future<void> _deleteOne(BuildContext context) async {
    final loc = context.read<LocaleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('center.locker.deleteOneTitle')),
        content: Text(loc.t('center.locker.deleteOneConfirm', params: {'no': '${locker.lockerNo}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(loc.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<ApiService>().deleteLocker(locker.lockerId!);
      onRefresh();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, context.read<LocaleProvider>().t('center.locker.deleteFail', params: {'e': '$e'}));
    }
  }
}

// ──────────────────────────────────────────────────────────────
// 요약 카드 — 상단 통계 수치 표시 (전체/사용중/만료임박/사용가능/점검중)
// ──────────────────────────────────────────────────────────────
class LockerSummaryCard extends StatelessWidget {
  final String label; // 카드 제목
  final int count;    // 표시할 수치
  final Color color;  // 테마 색상

  const LockerSummaryCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text('$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]),
    );
  }
}
