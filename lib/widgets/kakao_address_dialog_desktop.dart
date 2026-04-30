import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

bool? _webView2Cached;
Future<bool> isWebView2Available() async {
  if (_webView2Cached != null) return _webView2Cached!;
  try {
    final v = await WebviewController.getWebViewVersion();
    _webView2Cached = v != null && v.isNotEmpty;
  } catch (_) {
    _webView2Cached = false;
  }
  return _webView2Cached!;
}

class AddressResult {
  final String zonecode;
  final String address;
  const AddressResult({required this.zonecode, required this.address});
}

Future<AddressResult?> showKakaoAddressDialog(BuildContext context) {
  return showDialog<AddressResult>(
    context: context,
    barrierColor: Colors.black45,
    barrierDismissible: false,
    builder: (_) => const _KakaoAddressDialog(),
  );
}

class _KakaoAddressDialog extends StatefulWidget {
  const _KakaoAddressDialog();
  @override
  State<_KakaoAddressDialog> createState() => _KakaoAddressDialogState();
}

class _KakaoAddressDialogState extends State<_KakaoAddressDialog> {
  final _ctrl = WebviewController();
  HttpServer? _server;
  bool _ready = false;
  String? _initError;
  bool _handled = false;
  Offset? _offset;
  static const double _w = 520;
  static const double _h = 620;
  Timer? _pollTimer;

  static const String _html = r'''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    html,body { width:100%; height:100%; }
    #wrap  { width:100%; height:100vh; }
    #status {
      position:fixed; top:50%; left:50%;
      transform:translate(-50%,-50%);
      color:#555; font-size:14px; font-family:sans-serif;
    }
  </style>
</head>
<body>
  <div id="wrap"></div>
  <div id="status">주소 검색 불러오는 중...</div>
  <script>
    window.__r = null;
    function sendResult(zonecode, address) {
      if (window.__r) return;
      window.__r = [zonecode, address];
      try { window.chrome.webview.postMessage(JSON.stringify({zonecode:zonecode,address:address})); } catch(e) {}
    }
    window.addEventListener('message', function(e) {
      if (window.__r || !e.data) return;
      try {
        var obj = (typeof e.data === 'object') ? e.data : JSON.parse(e.data);
        var zc   = obj.zonecode || obj.postcode5 || obj.postcode || '';
        var addr = obj.roadAddress || obj.address || obj.jibunAddress || '';
        if (addr) sendResult(zc, addr);
      } catch(ex) {}
    }, true);
    function initPostcode() {
      document.getElementById('status').style.display = 'none';
      new daum.Postcode({
        oncomplete: function(data) {
          var addr = data.roadAddress || data.jibunAddress;
          sendResult(data.zonecode, addr);
        },
        width: '100%', height: '100%'
      }).embed(document.getElementById('wrap'), { autoClose: false });
    }
    var s = document.createElement('script');
    s.src = 'https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js';
    s.onload  = initPostcode;
    s.onerror = function() {
      document.getElementById('status').textContent =
        '카카오 주소 스크립트를 불러오지 못했습니다. 인터넷 연결을 확인하세요.';
    };
    document.head.appendChild(s);
  </script>
</body>
</html>''';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = _server!.port;
      _server!.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'text/html; charset=utf-8')
          ..headers.set('Access-Control-Allow-Origin', '*')
          ..write(_html)
          ..close();
      });
      await _ctrl.initialize();
      _ctrl.webMessage.listen((event) {
        final raw = event?.toString() ?? '';
        if (!raw.startsWith('{')) return;
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _handleResult(map['zonecode']?.toString() ?? '', map['address']?.toString() ?? '');
        } catch (_) {}
      });
      await _ctrl.loadUrl('http://127.0.0.1:$port/');
      if (mounted) setState(() => _ready = true);
      _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        if (_handled || !mounted) { _pollTimer?.cancel(); return; }
        try {
          final raw = await _ctrl.executeScript('window.__r');
          if (raw == null || raw == 'null') return;
          await _ctrl.executeScript('window.__r = null');
          final list = jsonDecode(raw) as List;
          _handleResult(list[0]?.toString() ?? '', list[1]?.toString() ?? '');
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  void _handleResult(String zonecode, String address) {
    if (_handled || address.isEmpty) return;
    _handled = true;
    _pollTimer?.cancel();
    if (mounted) Navigator.of(context).pop(AddressResult(zonecode: zonecode, address: address));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _server?.close(force: true);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _offset ??= Offset((size.width - _w) / 2, (size.height - _h) / 2);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          children: [
            GestureDetector(onTap: () => Navigator.of(context).pop(), behavior: HitTestBehavior.opaque),
            Positioned(
              left: _offset!.dx, top: _offset!.dy,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: _w, height: _h,
                  child: Column(children: [
                    GestureDetector(
                      onPanUpdate: (d) {
                        setState(() {
                          final next = _offset! + d.delta;
                          _offset = Offset(
                            next.dx.clamp(0.0, size.width - _w),
                            next.dy.clamp(0.0, size.height - _h),
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1565C0),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Text('주소 검색', style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          const Icon(Icons.drag_indicator, color: Colors.white38, size: 18),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(Icons.close, color: Colors.white70, size: 20),
                          ),
                        ]),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        child: _buildBody(),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
          const SizedBox(height: 12),
          const Text('WebView를 초기화할 수 없습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_initError!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      ));
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return Webview(_ctrl);
  }
}
