import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/websocket_service.dart';

/// 실시간 출석 알림 상태 관리
class AttendanceProvider extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();
  AttendanceModel? _latestAttendance;
  bool _showPopup = false;

  AttendanceModel? get latestAttendance => _latestAttendance;
  bool get showPopup => _showPopup;

  /// WebSocket 연결 초기화 및 출석 이벤트 수신 시작
  void init(int gymId) {
    _ws.onAttendance = (attendance) {
      _latestAttendance = attendance;
      _showPopup = true;
      notifyListeners();
    };
    _ws.connect(gymId);
  }

  void dismissPopup() {
    _showPopup = false;
    notifyListeners();
  }

  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}
