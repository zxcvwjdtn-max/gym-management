import 'package:flutter/material.dart';

/// 웹에서는 항상 사용 가능 (직접 입력 폼)
Future<bool> isWebView2Available() async => true;

class AddressResult {
  final String zonecode;
  final String address;
  const AddressResult({required this.zonecode, required this.address});
}

Future<AddressResult?> showKakaoAddressDialog(BuildContext context) {
  return showDialog<AddressResult>(
    context: context,
    builder: (_) => const _WebAddressInputDialog(),
  );
}

class _WebAddressInputDialog extends StatefulWidget {
  const _WebAddressInputDialog();
  @override
  State<_WebAddressInputDialog> createState() => _WebAddressInputDialogState();
}

class _WebAddressInputDialogState extends State<_WebAddressInputDialog> {
  final _zipcodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _zipcodeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(children: [
        Icon(Icons.location_on, color: Color(0xFF1565C0), size: 22),
        SizedBox(width: 8),
        Text('주소 입력'),
      ]),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('웹 환경에서는 주소를 직접 입력해 주세요.',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _zipcodeCtrl,
            decoration: const InputDecoration(
              labelText: '우편번호',
              hintText: '12345',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.markunread_mailbox_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: '주소',
              hintText: '예: 서울특별시 강남구 테헤란로 123',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final addr = _addressCtrl.text.trim();
            if (addr.isEmpty) return;
            Navigator.of(context).pop(AddressResult(
              zonecode: _zipcodeCtrl.text.trim(),
              address: addr,
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          child: const Text('적용'),
        ),
      ],
    );
  }
}
