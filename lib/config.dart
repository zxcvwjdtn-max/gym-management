/// ════════════════════════════════════════════════════════════
///  서버 URL 설정 — 개발/운영 환경 분리
/// ════════════════════════════════════════════════════════════
///
///  ┌─ 로컬 테스트 시 ─────────────────────────────────────────┐
///  │  _localOverride 에 원하는 URL 을 직접 입력하세요.          │
///  │  배포 전 반드시 빈 문자열('')로 되돌려 주세요.              │
///  └──────────────────────────────────────────────────────────┘
///
///  ┌─ 자동 분기 (localOverride = '') ────────────────────────┐
///  │  flutter run / build --debug  → _devUrl  (개발 서버)    │
///  │  flutter build --release      → _prodUrl (운영 서버)    │
///  └──────────────────────────────────────────────────────────┘
class AppConfig {
  AppConfig._();

  // ── ✏ 로컬 오버라이드: 테스트할 URL 입력, 기본값은 빈 문자열 ──
  static const String _localOverride = '';
  // static const String _localOverride = 'http://192.168.1.240:8081/api';

  // ── 환경별 URL ───────────────────────────────────────────────
  static const String _devUrl  = 'http://1.234.20.159:8081/api';
  static const String _prodUrl = 'http://1.234.20.159:8083/api';

  static const bool _isProd = bool.fromEnvironment('dart.vm.product');

  static const String serverUrl = _localOverride != ''
      ? _localOverride
      : (_isProd ? _prodUrl : _devUrl);
}
