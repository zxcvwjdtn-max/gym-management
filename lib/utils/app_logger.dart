import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

// dart.vm.product = true → release build (flutter build windows --release)
const _isRelease = bool.fromEnvironment('dart.vm.product');

/// 개발/운영 환경 분리 로거
/// - 개발(debug): PrettyPrinter → IDE 콘솔, Level.debug
/// - 운영(release): SimplePrinter → %APPDATA%\GymPRO\logs\gympro-YYYY-MM-DD.log, Level.warning
class AppLogger {
  AppLogger._();

  static late final Logger _log;
  static IOSink? _sink;

  /// main() 에서 앱 시작 시 한 번 호출
  static void init() {
    if (_isRelease) _openLogFile();
    _log = Logger(
      level: _isRelease ? Level.warning : Level.debug,
      printer: _isRelease
          ? SimplePrinter(printTime: true, colors: false)
          : PrettyPrinter(
              methodCount: 1,
              errorMethodCount: 6,
              lineLength: 120,
              colors: true,
              printEmojis: true,
            ),
      output: _isRelease ? _SinkOutput() : ConsoleOutput(),
    );
  }

  // ── 기존 API (api_service.dart 에서 사용) ──────────────────────

  static void req(String method, String url, {Object? body}) {
    _log.d('REQ  $method $url${body != null ? '\n  body: $body' : ''}');
  }

  static void res(String method, String url, int statusCode, Object? body) {
    final ok = statusCode >= 200 && statusCode < 300;
    if (ok) {
      _log.d('RES  ✓ $method $url [$statusCode]\n  body: $body');
    } else {
      _log.w('RES  ✗ $method $url [$statusCode]\n  body: $body');
    }
  }

  static void err(String method, String url, Object error) =>
      _log.e('ERR  $method $url', error: error);

  static void info(String message)    => _log.i(message);
  static void warn(String message)    => _log.w(message);

  /// 핸들링되지 않은 예외 기록 (FlutterError.onError 등에서 호출)
  static void crash(Object error, StackTrace? st) =>
      _log.f('CRASH', error: error, stackTrace: st);

  // ── 내부: 운영 로그 파일 초기화 ───────────────────────────────

  static void _openLogFile() {
    try {
      final appData = Platform.environment['APPDATA'] ?? '.';
      final dir = Directory('$appData\\GymPRO\\logs');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final file  = File('${dir.path}\\gympro-$today.log');
      _sink = file.openWrite(mode: FileMode.append);
    } catch (_) {}
  }

  static void dispose() => _sink?.close();
}

class _SinkOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    final line = event.lines.join('\n');
    if (kDebugMode) debugPrint(line);
    AppLogger._sink?.writeln(line);
    AppLogger._sink?.flush().ignore();
  }
}
