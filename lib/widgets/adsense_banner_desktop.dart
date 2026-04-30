import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class AdSenseBanner extends StatefulWidget {
  final String adClient;
  final String adSlot;
  final double height;

  const AdSenseBanner({
    super.key,
    required this.adClient,
    required this.adSlot,
    this.height = 90,
  });

  @override
  State<AdSenseBanner> createState() => _AdSenseBannerState();
}

class _AdSenseBannerState extends State<AdSenseBanner> {
  final _ctrl = WebviewController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _ctrl.initialize();
      await _ctrl.setBackgroundColor(Colors.transparent);
      await _ctrl.loadStringContent(_buildHtml());
      if (mounted) setState(() => _ready = true);
    } catch (_) {}
  }

  String _buildHtml() {
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #f5f5f5; display: flex; justify-content: center; align-items: center;
         height: 100vh; overflow: hidden; }
  .ad-wrap { width: 100%; max-width: 728px; }
</style>
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${widget.adClient}"
     crossorigin="anonymous"></script>
</head>
<body>
<div class="ad-wrap">
  <ins class="adsbygoogle"
       style="display:block"
       data-ad-client="${widget.adClient}"
       data-ad-slot="${widget.adSlot}"
       data-ad-format="horizontal"
       data-full-width-responsive="true"></ins>
  <script>(adsbygoogle = window.adsbygoogle || []).push({});</script>
</div>
</body>
</html>''';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return SizedBox(height: widget.height);
    return SizedBox(height: widget.height, child: Webview(_ctrl));
  }
}
