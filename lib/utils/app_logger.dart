import 'package:flutter/foundation.dart';

/// 개발 모드에서만 로그를 출력합니다.
/// flutter run          → kDebugMode = true  → 출력됨
/// flutter run --release → kDebugMode = false → 출력 안됨
/// flutter build windows → kDebugMode = false → 출력 안됨
class AppLogger {
  AppLogger._();

  /// HTTP 요청 로그 출력
  static void req(String method, String url, {Object? body}) {
    if (!kDebugMode) return;
    debugPrint('┌── [REQ] $method $url');
    if (body != null) debugPrint('│   body: $body');
    debugPrint('└────────────────────────────────');
  }

  /// HTTP 응답 로그 출력
  static void res(String method, String url, int statusCode, Object? body) {
    if (!kDebugMode) return;
    final icon = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    debugPrint('┌── [RES] $icon $method $url [$statusCode]');
    debugPrint('│   body: $body');
    debugPrint('└────────────────────────────────');
  }

  /// HTTP 에러 로그 출력
  static void err(String method, String url, Object error) {
    if (!kDebugMode) return;
    debugPrint('┌── [ERR] ❌ $method $url');
    debugPrint('│   error: $error');
    debugPrint('└────────────────────────────────');
  }

  /// 일반 정보 로그 출력
  static void info(String message) {
    if (!kDebugMode) return;
    debugPrint('[INFO] $message');
  }
}
