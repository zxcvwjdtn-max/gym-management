// 라커 관련 다이얼로그 — LockerDetailDialog(상세/상태변경), AddLockerDialog(단건/범위/격자 추가)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';

// ──────────────────────────────────────────────────────────────
// 라커 상세/상태 변경 다이얼로그
// 현재 라커 정보 표시 및 AVAILABLE·MAINTENANCE 상태 전환 지원
// ──────────────────────────────────────────────────────────────
class LockerDetailDialog extends StatefulWidget {
  final LockerModel locker;    // 조회할 라커 데이터
  final VoidCallback onAction; // 상태 변경 후 목록 새로고침 콜백

  const LockerDetailDialog({super.key, required this.locker, required this.onAction});

  @override
  State<LockerDetailDialog> createState() => _LockerDetailDialogState();
}

class _LockerDetailDialogState extends State<LockerDetailDialog> {
  bool _saving = false; // API 호출 중 로딩 상태

  /// 라커 상태를 [status]로 변경하고 다이얼로그 닫기
  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      await context.read<ApiService>()
          .updateLocker(widget.locker.lockerId!, {'status': status});
      widget.onAction();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, context.read<LocaleProvider>().t('center.locker.changeFail', params: {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final l = widget.locker;

    return AlertDialog(
      title: Text(loc.t('center.locker.detailTitle', params: {'no': '${l.lockerNo}'})),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(loc.t('center.locker.rowStatus'), _statusLabel(l.status, loc)),
            if (l.memberName != null) _row(loc.t('center.locker.rowMember'), l.memberName!),
            if (l.startDate != null)  _row(loc.t('center.locker.rowStart'), l.startDate!),
            if (l.endDate != null)    _row(loc.t('center.locker.rowEnd'), l.endDate!),
            if (l.monthlyFee != null && l.monthlyFee! > 0)
              _row(loc.t('center.locker.rowFee'), loc.t('center.locker.feeValue', params: {'fee': '${l.monthlyFee}'})),
            const Divider(height: 24),
            Text(loc.t('center.locker.changeStatus'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 현재 상태가 아닌 버튼만 표시
            Wrap(spacing: 8, children: [
              if (l.status != 'AVAILABLE')
                OutlinedButton(
                  onPressed: _saving ? null : () => _setStatus('AVAILABLE'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
                  child: Text(loc.t('center.locker.status.available')),
                ),
              if (l.status != 'MAINTENANCE')
                OutlinedButton(
                  onPressed: _saving ? null : () => _setStatus('MAINTENANCE'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(loc.t('center.locker.status.maintenance')),
                ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('common.close'))),
      ],
    );
  }

  /// 레이블-값 행 위젯 생성
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 70,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]),
  );

  /// 상태 코드를 i18n 라벨로 변환
  String _statusLabel(String? s, LocaleProvider loc) => switch (s) {
    'AVAILABLE'   => loc.t('center.locker.status.available'),
    'OCCUPIED'    => loc.t('center.locker.status.occupied'),
    'MAINTENANCE' => loc.t('center.locker.status.maintenance'),
    _             => s ?? '',
  };
}

// ──────────────────────────────────────────────────────────────
// 라커 추가 모드 열거형
// single: 단건 | range: 번호 범위 | grid: 행×열 격자
// ──────────────────────────────────────────────────────────────
enum LockerAddMode { single, range, grid }

// ──────────────────────────────────────────────────────────────
// 라커 추가 다이얼로그 (단건 / 범위 / 격자)
// ──────────────────────────────────────────────────────────────
class AddLockerDialog extends StatefulWidget {
  final VoidCallback onSaved; // 추가 완료 후 목록 새로고침 콜백

  const AddLockerDialog({super.key, required this.onSaved});

  @override
  State<AddLockerDialog> createState() => _AddLockerDialogState();
}

class _AddLockerDialogState extends State<AddLockerDialog> {
  LockerAddMode _mode = LockerAddMode.single; // 현재 선택된 추가 모드

  // 각 모드별 입력 컨트롤러
  final _noCtrl      = TextEditingController(); // 단건: 라커 번호
  final _fromCtrl    = TextEditingController(); // 범위: 시작 번호
  final _toCtrl      = TextEditingController(); // 범위: 끝 번호
  final _startCtrl   = TextEditingController(); // 격자: 시작 번호
  final _perRowCtrl  = TextEditingController(); // 격자: 열당 개수
  final _rowsCtrl    = TextEditingController(); // 격자: 열 수
  final _feeCtrl     = TextEditingController(); // 공통: 월 요금
  bool _saving = false; // API 호출 중 로딩 상태

  @override
  void dispose() {
    // 컨트롤러 메모리 해제
    _noCtrl.dispose(); _fromCtrl.dispose(); _toCtrl.dispose();
    _startCtrl.dispose(); _perRowCtrl.dispose(); _rowsCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  /// 현재 모드에 따라 라커 생성 API 호출
  Future<void> _save() async {
    final loc = context.read<LocaleProvider>();
    final fee = int.tryParse(_feeCtrl.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      switch (_mode) {
        case LockerAddMode.single:
          // 단건: 라커 번호 하나 생성
          final no = _noCtrl.text.trim();
          if (no.isEmpty) { showErrorSnack(context, loc.t('center.locker.errNoRequired')); return; }
          await api.createLocker({'lockerNo': no, 'monthlyFee': fee});

        case LockerAddMode.range:
          // 범위: from~to 순차 생성
          final from = int.tryParse(_fromCtrl.text.trim());
          final to   = int.tryParse(_toCtrl.text.trim());
          if (from == null || to == null || from > to) {
            showErrorSnack(context, loc.t('center.locker.errRangeInvalid'));
            return;
          }
          for (int n = from; n <= to; n++) {
            await api.createLocker({'lockerNo': '$n', 'monthlyFee': fee});
          }

        case LockerAddMode.grid:
          // 격자: perRow × rows 개를 배치 API로 생성
          final start  = int.tryParse(_startCtrl.text.trim());
          final perRow = int.tryParse(_perRowCtrl.text.trim());
          final rows   = int.tryParse(_rowsCtrl.text.trim());
          if (start == null || perRow == null || rows == null || perRow <= 0 || rows <= 0) {
            showErrorSnack(context, loc.t('center.locker.errGridInvalid'));
            return;
          }
          final total = perRow * rows;
          final nos = List.generate(total, (n) => '${start + n}');
          await api.createLockerBatch({
            'lockerNos': nos,
            'monthlyFee': fee,
            'groupCols': perRow,
          });
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnack(context, context.read<LocaleProvider>().t('center.locker.addFail', params: {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 격자 모드에서 미리보기 위젯 생성
  Widget _buildGridPreview(LocaleProvider loc) {
    final start  = int.tryParse(_startCtrl.text.trim());
    final perRow = int.tryParse(_perRowCtrl.text.trim());
    final rows   = int.tryParse(_rowsCtrl.text.trim());
    // 유효하지 않은 입력이면 빈 위젯 반환
    if (start == null || perRow == null || rows == null || perRow <= 0 || rows <= 0) {
      return const SizedBox.shrink();
    }
    final total = perRow * rows;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 미리보기 헤더: 총 개수 및 번호 범위
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(children: [
              const Icon(Icons.grid_view, size: 15, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Text(
                loc.t('center.locker.gridPreviewTotal', params: {
                  'n': '$total',
                  'from': '$start',
                  'to': '${start + total - 1}',
                }),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0))),
            ]),
          ),
          // 격자 미리보기 본문 (스크롤 가능)
          SizedBox(
            height: (rows * 38 + 28).toDouble().clamp(60.0, 260.0),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 열 번호 헤더 행
                    Row(children: [
                      const SizedBox(width: 42),
                      for (int c = 1; c <= perRow; c++)
                        SizedBox(
                          width: 46,
                          child: Center(
                            child: Text(
                              loc.t('center.locker.gridColN', params: {'n': '$c'}),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    // 각 행별 라커 번호 표시
                    for (int r = 0; r < rows; r++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              loc.t('center.locker.gridRowN', params: {'n': '${r + 1}'}),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          ),
                          for (int c = 0; c < perRow; c++)
                            Container(
                              width: 42,
                              height: 30,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: const Color(0xFF1565C0)
                                        .withValues(alpha: 0.35)),
                              ),
                              alignment: Alignment.center,
                              child: Text('${start + r * perRow + c}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1565C0))),
                            ),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(loc.t('center.locker.add')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 추가 모드 선택 세그먼트 버튼
              SegmentedButton<LockerAddMode>(
                segments: [
                  ButtonSegment(value: LockerAddMode.single, label: Text(loc.t('center.locker.addMode.single'))),
                  ButtonSegment(value: LockerAddMode.range,  label: Text(loc.t('center.locker.addMode.range'))),
                  ButtonSegment(value: LockerAddMode.grid,   label: Text(loc.t('center.locker.addMode.grid'))),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(height: 16),

              // 단건 모드: 라커 번호 입력
              if (_mode == LockerAddMode.single)
                TextField(
                  controller: _noCtrl,
                  decoration: InputDecoration(
                    labelText: loc.t('center.locker.addNoHint'),
                    border: const OutlineInputBorder(),
                  ),
                ),

              // 범위 모드: 시작·끝 번호 입력
              if (_mode == LockerAddMode.range)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _fromCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: loc.t('center.locker.addFrom'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('~', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _toCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: loc.t('center.locker.addTo'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                ]),

              // 격자 모드: 시작 번호·열당 개수·열 수 입력 + 미리보기
              if (_mode == LockerAddMode.grid) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _startCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: loc.t('center.locker.addFrom'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _perRowCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: loc.t('center.locker.addPerRow'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('×', style: TextStyle(fontSize: 18)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _rowsCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: loc.t('center.locker.addRows'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                ]),
                _buildGridPreview(loc),
              ],

              const SizedBox(height: 12),
              // 공통: 월 요금 입력 (선택)
              TextField(
                controller: _feeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc.t('center.locker.feeLabel'),
                  border: const OutlineInputBorder(),
                  suffixText: loc.t('center.locker.feeSuffix'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('common.cancel'))),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          // 저장 중이면 로딩 인디케이터 표시
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(loc.t('center.locker.addBtn')),
        ),
      ],
    );
  }
}
