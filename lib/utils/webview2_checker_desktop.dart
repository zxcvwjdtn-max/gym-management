import 'package:webview_windows/webview_windows.dart';

Future<bool> checkWebView2Available() async {
  try {
    final v = await WebviewController.getWebViewVersion();
    return v != null && v.isNotEmpty;
  } catch (_) {
    return false;
  }
}
