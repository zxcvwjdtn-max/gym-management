import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

/// 앱 전역 언어(Locale) 상태
/// 지원 언어: ko, en
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale';
  static const supported = ['ko', 'en'];

  String _lang = 'ko';

  String get lang => _lang;
  Locale get locale => Locale(_lang, _lang == 'ko' ? 'KR' : 'US');

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && supported.contains(saved)) {
      _lang = saved;
      notifyListeners();
    }
  }

  Future<void> setLang(String lang) async {
    if (!supported.contains(lang) || lang == _lang) return;
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang);
    notifyListeners();
  }

  /// 문자열 조회 단축 함수. params가 주어지면 {key} 토큰을 치환.
  String t(String key, {Map<String, String>? params}) {
    var s = AppStrings.get(key, _lang);
    if (params != null) {
      params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }
}
