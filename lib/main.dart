import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/api_service.dart';
import 'utils/webview2_checker.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.init();

  // 핸들링되지 않은 Flutter 프레임워크 오류 → 로그 기록
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.crash(details.exception, details.stack);
  };

  // 핸들링되지 않은 비동기 오류 → 로그 기록
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.crash(error, stack);
    return false;
  };

  // 웹에서는 WebView2 체크 생략
  final webView2Available = kIsWeb ? false : await checkWebView2Available();

  runApp(GymManagementApp(webView2Available: webView2Available));
}

class GymManagementApp extends StatelessWidget {
  final bool webView2Available;
  const GymManagementApp({super.key, required this.webView2Available});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProxyProvider<ApiService, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<ApiService>()),
          update: (_, api, prev) => prev ?? AuthProvider(api),
        ),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..init()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProv, _) => MaterialApp(
          title: '체육관 관리 시스템',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko', 'KR'),
            Locale('en', 'US'),
          ],
          locale: localeProv.locale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1565C0),
            ),
            useMaterial3: true,
            fontFamily: 'Pretendard',
          ),
          home: _AppRoot(webView2Available: webView2Available),
        ),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  final bool webView2Available;
  const _AppRoot({required this.webView2Available});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().init();
      // WebView2 미설치 시 안내 다이얼로그
      if (!widget.webView2Available) {
        _showWebView2Dialog();
      }
    });
  }

  // WebView2 미설치 안내 다이얼로그 표시
  void _showWebView2Dialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 40),
        title: const Text('WebView2 설치 필요'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WebView2 Runtime이 설치되어 있지 않습니다.\n'
              '카카오 주소 검색 기능을 사용하려면 설치가 필요합니다.',
            ),
            SizedBox(height: 12),
            Text(
              '• 주소 검색을 제외한 모든 기능은 정상 작동합니다.\n'
              '• 설치 후 앱을 재시작하면 주소 검색이 활성화됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에 설치'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(
                  'https://developer.microsoft.com/microsoft-edge/webview2/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('지금 설치하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const LoginScreen();
    return const DashboardScreen();
  }
}
