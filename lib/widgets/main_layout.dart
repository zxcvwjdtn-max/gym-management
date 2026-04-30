import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import 'side_menu.dart';
import 'attendance_popup.dart';
import 'adsense_banner.dart';

class MainLayout extends StatelessWidget {
  final String selectedRoute;
  final void Function(String) onNavigate;
  final Widget child;

  const MainLayout({
    super.key,
    required this.selectedRoute,
    required this.onNavigate,
    required this.child,
  });

  // 사이드 메뉴 + 콘텐츠 영역 + 출석 팝업 오버레이 구성
  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AttendanceProvider>();
    final auth = context.watch<AuthProvider>();
    final showAd = auth.adEnabled &&
        (auth.adClient?.isNotEmpty ?? false) &&
        (auth.adSlot?.isNotEmpty ?? false);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SideMenu(selectedRoute: selectedRoute, onSelect: onNavigate),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),
                Expanded(
                  child: Stack(
                    children: [
                      child,
                      if (ap.showPopup) const AttendancePopupOverlay(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showAd) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            AdSenseBanner(adClient: auth.adClient!, adSlot: auth.adSlot!),
          ],
        ],
      ),
    );
  }
}
