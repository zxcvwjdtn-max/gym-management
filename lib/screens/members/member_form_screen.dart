import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../utils/snack_helper.dart';
import '../../widgets/kakao_address_dialog.dart';
import '../../widgets/app_select.dart';

class MemberFormScreen extends StatefulWidget {
  final MemberModel? member;
  const MemberFormScreen({super.key, this.member});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _memberNoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _addressDetailCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  String? _gender;
  String? _memberType = 'REGULAR';  // 기본값: 일반
  String? _sportType;
  String _smsYn = 'N';
  String _clothRentalYn = 'N';
  String _lockerRentalYn = 'N';
  bool _saving = false;

  // 사진
  File? _selectedPhoto;
  String? _currentPhotoUrl; // 기존 등록된 사진 URL

  // 고객 구분 (멀티-선택)
  List<MemberGroupDefModel> _groupDefs = [];
  Set<int> _selectedGroupDefIds = {};
  bool _groupDefsLoaded = false;

  // 회원번호를 사용자가 직접 수정했는지 추적
  bool _memberNoManuallyEdited = false;
  // WebView2 설치 여부 (주소 검색 버튼 활성화용)
  bool _webView2Available = false;

  bool get isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final m = widget.member!;
      _currentPhotoUrl = m.photoUrl;
      _memberNoCtrl.text = m.memberNo;
      _nameCtrl.text = m.memberName;
      _phoneCtrl.text = m.phone ?? '';
      _emailCtrl.text = m.email ?? '';
      _parentPhoneCtrl.text = m.parentPhone ?? '';
      _postalCodeCtrl.text = m.postalCode ?? '';
      _addressCtrl.text = m.address ?? '';
      _addressDetailCtrl.text = m.addressDetail ?? '';
      _birthCtrl.text = m.birthDate ?? '';
      _memoCtrl.text = m.memo ?? '';
      _gender = m.gender;
      _memberType = m.memberType ?? 'REGULAR';
      _sportType = m.sportType;
      _smsYn = m.smsYn ?? 'Y';
      _clothRentalYn = m.clothRentalYn ?? 'N';
      _lockerRentalYn = m.lockerRentalYn ?? 'N';
      _memberNoManuallyEdited = true; // 수정 모드에서는 자동변경 안 함
    } else {
      // 신규 등록: 로그인한 관리자(체육관)의 기본 종목 사용
      _sportType = context.read<AuthProvider>().sportType;
    }

    // 고객 구분 목록 로드
    _loadGroupDefs();

    // WebView2 설치 여부 확인
    isWebView2Available().then((v) {
      if (mounted) setState(() => _webView2Available = v);
    });

    // 전화번호 변경 시 회원번호 자동 설정
    _phoneCtrl.addListener(_onPhoneChanged);
    // 회원번호 직접 입력 감지
    _memberNoCtrl.addListener(_onMemberNoChanged);
  }

  // 고객 구분 목록 로드
  Future<void> _loadGroupDefs() async {
    try {
      final list = await context.read<ApiService>().getMemberGroupDefs();
      if (mounted) {
        setState(() {
          _groupDefs = list;
          _groupDefsLoaded = true;
          if (isEdit) {
            _selectedGroupDefIds = widget.member!.groupDefIds.toSet();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _groupDefsLoaded = true);
    }
  }

  // 전화번호 변경 시 회원번호 자동 설정
  void _onPhoneChanged() {
    if (_memberNoManuallyEdited || isEdit) return;
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), ''); // 숫자만
    if (phone.length >= 4) {
      final last4 = phone.substring(phone.length - 4);
      // 현재 회원번호가 이전 전화번호 뒷자리와 같을 때만 자동 업데이트
      _memberNoCtrl.removeListener(_onMemberNoChanged);
      _memberNoCtrl.text = last4;
      _memberNoCtrl.addListener(_onMemberNoChanged);
    }
  }

  // 회원번호 수동 입력 여부 감지
  void _onMemberNoChanged() {
    // 전화번호 뒷자리와 다른 값으로 바꾸면 수동 입력으로 간주
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final autoVal = phone.length >= 4 ? phone.substring(phone.length - 4) : '';
    if (_memberNoCtrl.text.isNotEmpty && _memberNoCtrl.text != autoVal) {
      _memberNoManuallyEdited = true;
    } else if (_memberNoCtrl.text.isEmpty) {
      _memberNoManuallyEdited = false;
    }
  }

  @override
  void dispose() {
    _memberNoCtrl.removeListener(_onMemberNoChanged);
    _phoneCtrl.removeListener(_onPhoneChanged);
    _memberNoCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _postalCodeCtrl.dispose();
    _addressCtrl.dispose();
    _addressDetailCtrl.dispose();
    _birthCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // 카카오 주소 검색 팝업 표시 후 결과 반영
  Future<void> _searchAddress() async {
    final result = await showKakaoAddressDialog(context);
    if (result != null && mounted) {
      setState(() {
        _postalCodeCtrl.text = result.zonecode;
        _addressCtrl.text = result.address;
        _addressDetailCtrl.clear();
      });
      // 상세주소 필드로 포커스 이동
      FocusScope.of(context).nextFocus();
    }
  }

  // 생년월일 데이트피커 표시
  Future<void> _pickBirthDate() async {
    // 현재 입력값 파싱 (없으면 30년 전 기본값)
    DateTime initial;
    try {
      initial = DateTime.parse(_birthCtrl.text);
    } catch (_) {
      final now = DateTime.now();
      initial = DateTime(now.year - 30, now.month, now.day);
    }

    final loc = context.read<LocaleProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: loc.locale,
      helpText: loc.t('memberForm.birthDate.pick'),
      cancelText: loc.t('common.cancel'),
      confirmText: loc.t('common.confirm'),
    );

    if (picked != null && mounted) {
      setState(() {
        _birthCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // 회원 정보 저장 (등록 또는 수정)
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = context.read<ApiService>();
      final body = <String, dynamic>{
        'memberNo': _memberNoCtrl.text.trim(),
        'memberName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'parentPhone': _parentPhoneCtrl.text.trim(),
        'postalCode': _postalCodeCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'addressDetail': _addressDetailCtrl.text.trim(),
        'birthDate': _birthCtrl.text.trim(),
        'gender': _gender,
        'memberType': _memberType,
        'sportType': _sportType,
        'smsYn': _smsYn,
        'clothRentalYn': _clothRentalYn,
        'lockerRentalYn': _lockerRentalYn,
        'memo': _memoCtrl.text.trim(),
      };

      int? memberId;
      if (isEdit) {
        await api.updateMember(widget.member!.memberId!, body);
        memberId = widget.member!.memberId;
      } else {
        final created = await api.createMember(body);
        if (created is Map) memberId = created['memberId'];
      }

      // 고객 구분 그룹 저장
      if (memberId != null && _groupDefsLoaded) {
        await api.updateMemberGroups(memberId, _selectedGroupDefIds.toList());
      }

      // 사진 업로드 (선택된 경우)
      if (_selectedPhoto != null && memberId != null) {
        final bytes = await _selectedPhoto!.readAsBytes();
        final filename = 'member_${memberId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPhotoUrl = await api.uploadMemberPhoto(memberId, bytes, filename);
        if (mounted) setState(() => _currentPhotoUrl = newPhotoUrl);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        final loc = context.read<LocaleProvider>();
        showErrorSnack(context, '${loc.t('memberForm.saveFailed')}: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? loc.t('memberForm.title.edit') : loc.t('memberForm.title.add')),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 프로필 사진 ──────────────────────────────────
                  Center(child: _buildPhotoSection()),
                  const SizedBox(height: 20),

                  _sectionTitle(loc.t('memberForm.section.basic')),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _memberNoCtrl,
                        decoration: _dec(
                          isEdit ? loc.t('memberForm.memberNo') : loc.t('memberForm.memberNo.hint'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: _dec(loc.t('memberForm.name')),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? loc.t('memberForm.name.required') : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _dec(loc.t('memberForm.phone')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _parentPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: _dec(loc.t('memberForm.parentPhone')),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('이메일'),
                  ),
                  const SizedBox(height: 14),
                  // ── 주소 (우편번호 + 주소 + 상세주소) ──
                  Row(children: [
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        controller: _postalCodeCtrl,
                        decoration: _dec(loc.t('memberForm.postalCode')),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: _webView2Available ? '' : loc.t('memberForm.webviewMissing'),
                      child: ElevatedButton.icon(
                        onPressed: _webView2Available ? _searchAddress : null,
                        icon: const Icon(Icons.search, size: 16),
                        label: Text(loc.t('memberForm.findPostal')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: _dec(loc.t('memberForm.address')),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _addressDetailCtrl,
                    decoration: _dec(loc.t('memberForm.addressDetail')),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    // 생년월일 — 데이트피커
                    Expanded(
                      child: TextFormField(
                        controller: _birthCtrl,
                        readOnly: true,
                        onTap: _pickBirthDate,
                        decoration: _dec(loc.t('memberForm.birthDate')).copyWith(
                          suffixIcon: const Icon(Icons.calendar_month, size: 20),
                          hintText: 'YYYY-MM-DD',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FormSelect<String>(
                        label: loc.t('memberForm.gender'),
                        currentLabel: _gender == 'M'
                            ? loc.t('memberForm.gender.male')
                            : _gender == 'F' ? loc.t('memberForm.gender.female') : null,
                        hint: loc.t('memberForm.select'),
                        options: [
                          (loc.t('memberForm.gender.male'), 'M'),
                          (loc.t('memberForm.gender.female'), 'F'),
                        ],
                        onSelected: (v) => setState(() => _gender = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  FormSelect<String>(
                    label: loc.t('memberForm.type'),
                    currentLabel: {
                      'REGULAR': loc.t('memberForm.type.regular'),
                      'GROUP': loc.t('memberForm.type.group'),
                      'VIP': loc.t('memberForm.type.vip'),
                    }[_memberType],
                    hint: loc.t('memberForm.select'),
                    options: [
                      (loc.t('memberForm.type.regular'), 'REGULAR'),
                      (loc.t('memberForm.type.group'), 'GROUP'),
                      (loc.t('memberForm.type.vip'), 'VIP'),
                    ],
                    onSelected: (v) => setState(() => _memberType = v),
                  ),
                  const SizedBox(height: 14),
                  // ── 고객 구분 (멀티-선택) ──
                  if (_groupDefs.isNotEmpty) ...[
                    _GroupDefPicker(
                      groupDefs: _groupDefs,
                      selected: _selectedGroupDefIds,
                      onToggle: (id) => setState(() {
                        if (_selectedGroupDefIds.contains(id)) {
                          _selectedGroupDefIds.remove(id);
                        } else {
                          _selectedGroupDefIds.add(id);
                        }
                      }),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('memberForm.sms'),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'N', label: Text(loc.t('memberForm.sms.none'))),
                          ButtonSegment(value: 'Y', label: Text(loc.t('memberForm.sms.inOnly'))),
                          ButtonSegment(value: 'BOTH', label: Text(loc.t('memberForm.sms.both'))),
                        ],
                        selected: {_smsYn},
                        onSelectionChanged: (s) => setState(() => _smsYn = s.first),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _RentalToggle(
                          label: loc.t('memberForm.clothRental'),
                          icon: Icons.checkroom,
                          value: _clothRentalYn == 'Y',
                          onChanged: (v) => setState(() => _clothRentalYn = v ? 'Y' : 'N'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _RentalToggle(
                          label: loc.t('memberForm.lockerRental'),
                          icon: Icons.lock_outline,
                          value: _lockerRentalYn == 'Y',
                          onChanged: (v) => setState(() => _lockerRentalYn = v ? 'Y' : 'N'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _memoCtrl,
                    decoration: _dec(loc.t('memberForm.memo')),
                    maxLines: 3,
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.t('memberForm.ticketInfo'),
                            style: TextStyle(
                                fontSize: 13, color: Colors.blue.shade700),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(loc.t('common.cancel')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(isEdit ? loc.t('memberForm.btn.editSave') : loc.t('memberForm.btn.register')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 사진 선택/미리보기 ─────────────────────────────────────
  Widget _buildPhotoSection() {
    Widget photoWidget;
    if (_selectedPhoto != null) {
      photoWidget = Image.file(_selectedPhoto!, fit: BoxFit.cover);
    } else if (_currentPhotoUrl != null) {
      photoWidget = Image.network(
        '${_currentPhotoUrl!}?t=${DateTime.now().millisecondsSinceEpoch}',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoPlaceholder(),
      );
    } else {
      photoWidget = _photoPlaceholder();
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: 120,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
              color: Colors.grey.shade100,
            ),
            clipBehavior: Clip.antiAlias,
            child: photoWidget,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.camera_alt, size: 16),
          label: Text(_selectedPhoto != null
              ? '사진 변경'
              : (_currentPhotoUrl != null ? '사진 변경' : '사진 등록')),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1565C0)),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.person, size: 48, color: Colors.grey),
      SizedBox(height: 6),
      Text('사진 없음', style: TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1000,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _selectedPhoto = File(picked.path));
    }
  }

  // 섹션 제목 위젯 반환
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
              width: 4,
              height: 18,
              color: const Color(0xFF1565C0),
              margin: const EdgeInsets.only(right: 8)),
          Text(t,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0))),
        ]),
      );

  // 입력 필드 공통 데코레이션 반환
  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

// ── 고객 구분 멀티-선택 위젯 ──────────────────────────────────────
class _GroupDefPicker extends StatelessWidget {
  final List<MemberGroupDefModel> groupDefs;
  final Set<int> selected;
  final void Function(int groupDefId) onToggle;

  const _GroupDefPicker({
    required this.groupDefs, required this.selected, required this.onToggle,
  });

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.blue; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('고객 구분',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: groupDefs.map((g) {
            final color = _parseColor(g.groupColor);
            final isSelected = g.groupDefId != null && selected.contains(g.groupDefId);
            return GestureDetector(
              onTap: () { if (g.groupDefId != null) onToggle(g.groupDefId!); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isSelected)
                    Icon(Icons.check_circle, size: 14, color: color)
                  else
                    Icon(Icons.circle_outlined, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text(g.groupName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? color : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RentalToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RentalToggle({
    required this.label, required this.icon,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: value ? const Color(0xFF1565C0) : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(8),
          color: value ? const Color(0xFF1565C0).withOpacity(0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
              color: value ? const Color(0xFF1565C0) : Colors.grey.shade500),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  color: value ? const Color(0xFF1565C0) : Colors.grey.shade700,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                )),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF1565C0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
