import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/attendance_provider.dart';

class AttendancePopupOverlay extends StatefulWidget {
  const AttendancePopupOverlay({super.key});

  @override
  State<AttendancePopupOverlay> createState() => _AttendancePopupOverlayState();
}

class _AttendancePopupOverlayState extends State<AttendancePopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // 슬라이드 아웃 애니메이션 후 팝업 닫기
  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) context.read<AttendanceProvider>().dismissPopup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>().latestAttendance;
    if (attendance == null) return const SizedBox.shrink();

    return Positioned(
      right: 24,
      bottom: 24,
      child: SlideTransition(
        position: _slideAnim,
        child: _PopupCard(attendance: attendance, onDismiss: _dismiss),
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final AttendanceModel attendance;
  final VoidCallback onDismiss;

  const _PopupCard({required this.attendance, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(attendance.membershipStatus);
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.how_to_reg, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('출석 완료!', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: attendance.photoUrl != null
                        ? NetworkImage(attendance.photoUrl!) : null,
                    child: attendance.photoUrl == null
                        ? const Icon(Icons.person, size: 36, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attendance.memberName,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('번호: ${attendance.memberNo}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                        if (attendance.ticketName != null)
                          Text('이용권: ${attendance.ticketName}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusText(attendance.membershipStatus),
                                style: TextStyle(color: statusColor,
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            if (attendance.remainDays != null) ...[
                              const SizedBox(width: 8),
                              Text('잔여 ${attendance.remainDays}일',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (attendance.todayGymAttendanceCount != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('출석시간', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    Text(_formatTime(attendance.attendanceTime),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('오늘 총 ${attendance.todayGymAttendanceCount}명 출석',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 이용권 상태별 색상 반환
  Color _statusColor(String? status) {
    switch (status) {
      case 'ACTIVE': return Colors.green;
      case 'EXPIRING_SOON': return Colors.orange;
      case 'EXPIRED': return Colors.red;
      case 'SUSPENDED': return Colors.grey;
      default: return Colors.blue;
    }
  }

  // 이용권 상태 코드를 한글 텍스트로 변환
  String _statusText(String? status) {
    switch (status) {
      case 'ACTIVE': return '유효';
      case 'EXPIRING_SOON': return '만료임박';
      case 'EXPIRED': return '만료';
      case 'SUSPENDED': return '정지';
      default: return '미등록';
    }
  }

  // DateTime을 HH:mm 형식으로 포맷
  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
