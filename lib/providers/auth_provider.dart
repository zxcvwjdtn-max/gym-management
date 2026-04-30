import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  bool _isLoggedIn = false;
  int? _gymId;
  String? _gymName;
  String? _gymCode;
  String? _sportType;
  String? _adminName;
  int? _authLevel;
  bool _isSuperAdmin = false;
  bool _adEnabled = false;
  String? _adClient;
  String? _adSlot;
  int? _parentGymId;
  String? _branchName;
  String _gymLocale = 'ko';
  DateTime? _tokenExpiry;

  bool get isLoggedIn => _isLoggedIn;
  int? get gymId => _gymId;

  /// 토큰이 만료됐으면 true (만료시각 미설정 시에도 만료로 간주)
  bool get isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  /// JWT payload에서 exp 클레임 파싱 (외부 라이브러리 없이 base64 디코딩)
  static DateTime? _parseExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // base64url → base64 정규화 후 디코딩
      final payload = base64Url.normalize(parts[1]);
      final json = jsonDecode(utf8.decode(base64Url.decode(payload))) as Map;
      final exp = json['exp'];
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    } catch (_) {
      return null;
    }
  }
  String? get gymName => _gymName;
  String? get gymCode => _gymCode;
  String? get sportType => _sportType;
  String? get adminName => _adminName;
  int? get authLevel => _authLevel;
  bool get isSuperAdmin => _isSuperAdmin;
  bool get adEnabled => _adEnabled;
  String? get adClient => _adClient;
  String? get adSlot => _adSlot;
  int? get parentGymId => _parentGymId;
  String? get branchName => _branchName;
  String get gymLocale => _gymLocale;

  AuthProvider(this._api) {
    // 401 수신 시 자동 로그아웃 연결
    _api.onUnauthorized = () => logout();
  }

  /// 앱 시작 시 저장된 세션 복원 (만료된 토큰은 자동 폐기)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final expiry = _parseExpiry(token);
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      // 저장된 토큰이 이미 만료 → 세션 삭제 후 로그인 화면
      await prefs.clear();
      return;
    }

    _tokenExpiry = expiry;
    _gymId = int.tryParse(prefs.getString('gymId') ?? '');
    _gymName = prefs.getString('gymName');
    _gymCode = prefs.getString('gymCode');
    _sportType = prefs.getString('sportType');
    _adminName = prefs.getString('adminName');
    _authLevel = int.tryParse(prefs.getString('authLevel') ?? '');
    _isSuperAdmin = prefs.getBool('isSuperAdmin') ?? false;
    _adEnabled = prefs.getBool('adEnabled') ?? false;
    _adClient = prefs.getString('adClient');
    _adSlot = prefs.getString('adSlot');
    _parentGymId = int.tryParse(prefs.getString('parentGymId') ?? '');
    _branchName = prefs.getString('branchName');
    _gymLocale = prefs.getString('gymLocale') ?? 'ko';
    _isLoggedIn = true;
    notifyListeners();
  }

  /// 로그인 처리 — SharedPreferences에 세션 저장
  Future<void> login(String loginId, String password) async {
    final result = await _api.login(loginId, password);
    final prefs = await SharedPreferences.getInstance();

    final token = result['token'] as String;
    _tokenExpiry = _parseExpiry(token);
    await prefs.setString('token', token);
    await prefs.setString('gymId', result['gymId']?.toString() ?? '');
    await prefs.setString('gymName', result['gymName'] ?? '');
    await prefs.setString('gymCode', result['gymCode'] ?? '');
    await prefs.setString('sportType', result['sportType'] ?? '');
    await prefs.setString('adminName', result['adminName'] ?? '');
    await prefs.setString('authLevel', result['authLevel']?.toString() ?? '');
    await prefs.setBool('isSuperAdmin', result['superAdmin'] == true);
    await prefs.setBool('adEnabled', result['adEnabled'] == true);
    await prefs.setString('adClient', result['adClient'] ?? '');
    await prefs.setString('adSlot', result['adSlot'] ?? '');
    await prefs.setString('parentGymId', result['parentGymId']?.toString() ?? '');
    await prefs.setString('branchName', result['branchName'] ?? '');
    final locale = result['locale'] as String? ?? 'ko';
    await prefs.setString('gymLocale', locale);
    await prefs.setString('app_locale', locale); // LocaleProvider가 읽는 키

    _gymId = result['gymId'] is int ? result['gymId'] : null;
    _gymName = result['gymName'];
    _gymCode = result['gymCode'];
    _sportType = result['sportType'];
    _adminName = result['adminName'];
    _authLevel = result['authLevel'];
    _isSuperAdmin = result['superAdmin'] == true;
    _adEnabled = result['adEnabled'] == true;
    _adClient = result['adClient'];
    _adSlot = result['adSlot'];
    _parentGymId = result['parentGymId'] is int ? result['parentGymId'] : null;
    _branchName = result['branchName'];
    _gymLocale = result['locale'] as String? ?? 'ko';
    _isLoggedIn = true;
    notifyListeners();
  }

  /// 로그아웃 — 저장된 세션 전체 삭제
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _gymId = null;
    _gymName = null;
    _gymCode = null;
    _sportType = null;
    _adminName = null;
    _isSuperAdmin = false;
    _adEnabled = false;
    _adClient = null;
    _adSlot = null;
    _parentGymId = null;
    _branchName = null;
    _gymLocale = 'ko';
    _tokenExpiry = null;
    notifyListeners();
  }

  /// 토큰 만료 여부 확인 후 만료 시 자동 로그아웃 (화면 전환마다 호출)
  Future<bool> checkExpiredAndLogout() async {
    if (!_isLoggedIn) return true;
    if (isTokenExpired) {
      await logout();
      return true;
    }
    return false;
  }
}
