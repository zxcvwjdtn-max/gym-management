import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 행정안전부 도로명주소 API 검색 결과
class AddressResult {
  final String zonecode; // 우편번호 5자리
  final String address;  // 도로명주소

  const AddressResult({required this.zonecode, required this.address});
}

/// 행정안전부 도로명주소 API 인증키
/// 발급: https://www.juso.go.kr/addrlink/devAddrLinkRequestGuide.do (무료)
const String _jusoApiKey = 'devU01TX0FVVEgyMDIzMDQxMTEwMjUyNjExNDkwMzU=';

/// 주소 검색 다이얼로그 (행정안전부 도로명주소 API)
Future<AddressResult?> showAddressSearchDialog(BuildContext context) {
  return showDialog<AddressResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AddressSearchDialog(),
  );
}

class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog();

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _totalCount = 0;
  static const int _perPage = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // 행정안전부 API로 주소 검색
  Future<void> _search({int page = 1}) async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.https(
        'www.juso.go.kr',
        '/addrlink/addrLinkApi.do',
        {
          'keyword': keyword,
          'confmKey': _jusoApiKey,
          'currentPage': page.toString(),
          'countPerPage': _perPage.toString(),
          'resultType': 'json',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final common = data['results']['common'];
      final errCode = common['errorCode'] ?? '0';
      if (errCode != '0') {
        setState(() {
          _error = common['errorMessage'] ?? '검색 오류가 발생했습니다.';
          _loading = false;
        });
        return;
      }

      final juso = (data['results']['juso'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final total = int.tryParse(common['totalCount'] ?? '0') ?? 0;

      setState(() {
        _results = juso;
        _totalCount = total;
        _currentPage = page;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '검색에 실패했습니다. 네트워크를 확인해주세요.';
        _loading = false;
      });
    }
  }

  int get _totalPages => (_totalCount / _perPage).ceil();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 560,
        height: 580,
        child: Column(children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.location_on, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('주소 검색',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ]),
          ),

          // 검색창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '도로명, 건물명, 지번 입력 (예: 강남대로 396)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _results = []);
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _search(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : () => _search(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('검색'),
              ),
            ]),
          ),

          // 결과 카운트
          if (_totalCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text('총 $_totalCount건',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                Text('$_currentPage / $_totalPages 페이지',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),

          const Divider(height: 1),

          // 결과 목록
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade300, size: 36),
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: TextStyle(color: Colors.red.shade400)),
                      ],
                    ),
                  )
                : _results.isEmpty && !_loading
                    ? Center(
                        child: Text(
                          _searchCtrl.text.isEmpty
                              ? '검색어를 입력하세요'
                              : '검색 결과가 없습니다.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _results[i];
                          final roadAddr =
                              item['roadAddr']?.toString() ?? '';
                          final zipNo =
                              item['zipNo']?.toString() ?? '';
                          final jibunAddr =
                              item['jibunAddr']?.toString() ?? '';

                          return InkWell(
                            onTap: () => Navigator.of(context).pop(
                              AddressResult(
                                  zonecode: zipNo, address: roadAddr),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1565C0)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(zipNo,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.bold,
                                        )),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(roadAddr,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(jibunAddr,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors
                                                    .grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 페이지네이션
          if (_totalPages > 1)
            Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade200))),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () => _search(page: _currentPage - 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(
                    _totalPages.clamp(0, 5),
                    (i) {
                      final page = i + 1;
                      final isActive = page == _currentPage;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () => _search(page: page),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF1565C0)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$page',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages
                        ? () => _search(page: _currentPage + 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}
