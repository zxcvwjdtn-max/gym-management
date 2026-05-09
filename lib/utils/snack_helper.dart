import 'package:flutter/material.dart';

/// 에러 스낵바 — X 버튼을 눌러야 사라짐
void showErrorSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
    ]),
    backgroundColor: Colors.red.shade700,
    duration: const Duration(days: 1),
    action: SnackBarAction(
      label: '✕',
      textColor: Colors.white,
      onPressed: () => messenger.hideCurrentSnackBar(),
    ),
  ));
}

/// 성공/정보 스낵바 — 5초 후 자동 사라짐, X 버튼으로 즉시 닫기 가능
void showSuccessSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
    ]),
    backgroundColor: Colors.green.shade700,
    duration: const Duration(seconds: 5),
    showCloseIcon: true,
    closeIconColor: Colors.white,
  ));
}
