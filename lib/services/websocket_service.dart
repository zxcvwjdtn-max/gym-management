import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// 데스크탑에서 WebSocket으로 실시간 출석 알림 수신
class WebSocketService {
  WebSocketChannel? _channel;
  Function(AttendanceModel)? onAttendance;

  // 웹 Docker 배포 시 --dart-define=WS_BASE_URL=ws://서버IP/api/ws/attendance 로 주입
  static const String wsUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8080/api/ws/attendance',
  );

  /// WebSocket 서버에 연결하고 출석 메시지 수신
  void connect(int gymId) {
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl?gymId=$gymId'));
    _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String);
          if (data['type'] == 'ATTENDANCE' && onAttendance != null) {
            onAttendance!(AttendanceModel.fromJson(data['data']));
          }
        } catch (e) {
          // JSON 파싱 오류 무시
        }
      },
      onError: (e) => reconnect(gymId),
      onDone: () => Future.delayed(const Duration(seconds: 3), () => reconnect(gymId)),
    );
  }

  void reconnect(int gymId) {
    disconnect();
    Future.delayed(const Duration(seconds: 5), () => connect(gymId));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
