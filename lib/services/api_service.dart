import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../config.dart';
import '../utils/app_logger.dart';

class ApiService {
  static const String baseUrl = AppConfig.serverUrl;

  /// 401 응답 수신 시 호출되는 콜백 — AuthProvider에서 주입
  void Function()? onUnauthorized;

  // ── 내부 헬퍼 ───────────────────────────────────────────────

  // 저장된 인증 토큰 반환
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // HTTP 요청 헤더 생성 (토큰 포함)
  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 응답 바디를 안전하게 JSON 파싱합니다.
  /// JSON이 아닌 경우(HTML 에러 페이지 등)에도 예외 대신 null 반환.
  dynamic _parseBody(http.Response response) {
    final raw = utf8.decode(response.bodyBytes);
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  // 응답 상태 코드 검증 및 data 추출
  dynamic _handle(http.Response response, String method, String url) {
    final body = _parseBody(response);
    AppLogger.res(method, url, response.statusCode, body);

    // 401: 토큰 만료 → 자동 로그아웃
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw Exception('인증이 만료되었습니다. 다시 로그인해 주세요.');
    }

    if (body == null) {
      throw Exception('서버 응답을 파싱할 수 없습니다. (HTTP ${response.statusCode})');
    }
    if (response.statusCode >= 200 && response.statusCode < 300 &&
        body['success'] == true) {
      return body['data'];
    }
    throw Exception(body['message'] ?? '서버 오류 (${response.statusCode})');
  }

  // GET 요청
  Future<dynamic> _get(String path) async {
    final url = '$baseUrl$path';
    AppLogger.req('GET', url);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _headers(),
      );
      return _handle(response, 'GET', url);
    } catch (e) {
      AppLogger.err('GET', url, e);
      rethrow;
    }
  }

  // POST 요청
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final url = '$baseUrl$path';
    AppLogger.req('POST', url, body: body);
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return _handle(response, 'POST', url);
    } catch (e) {
      AppLogger.err('POST', url, e);
      rethrow;
    }
  }

  // PUT 요청
  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final url = '$baseUrl$path';
    AppLogger.req('PUT', url, body: body);
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return _handle(response, 'PUT', url);
    } catch (e) {
      AppLogger.err('PUT', url, e);
      rethrow;
    }
  }

  // PATCH 요청
  Future<dynamic> _patch(String path, [Map<String, dynamic>? body]) async {
    final url = '$baseUrl$path';
    AppLogger.req('PATCH', url, body: body);
    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handle(response, 'PATCH', url);
    } catch (e) {
      AppLogger.err('PATCH', url, e);
      rethrow;
    }
  }

  // DELETE 요청
  Future<dynamic> _delete(String path, {Object? body}) async {
    final url = '$baseUrl$path';
    AppLogger.req('DELETE', url);
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: await _headers(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handle(response, 'DELETE', url);
    } catch (e) {
      AppLogger.err('DELETE', url, e);
      rethrow;
    }
  }

  // ── Auth ────────────────────────────────────────────────────

  /// 로그인 — 토큰 및 체육관 정보 반환
  Future<Map<String, dynamic>> login(String loginId, String password) async {
    const url = '$baseUrl/auth/login';
    final reqBody = {'loginId': loginId, 'password': password};
    AppLogger.req('POST', url, body: {'loginId': loginId, 'password': '***'});
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reqBody),
      );
      final body = _parseBody(response);
      AppLogger.res('POST', url, response.statusCode, body);

      if (body == null) {
        throw Exception('서버 응답을 파싱할 수 없습니다. (HTTP ${response.statusCode})');
      }
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? '로그인 실패');
      }
      return Map<String, dynamic>.from(body['data']);
    } catch (e) {
      AppLogger.err('POST', url, e);
      rethrow;
    }
  }

  // ── Dashboard ───────────────────────────────────────────────

  /// 대시보드 통계 조회
  Future<GymDashboardModel> getDashboard() async {
    final data = await _get('/gyms/dashboard');
    return GymDashboardModel.fromJson(data);
  }

  // ── Members ─────────────────────────────────────────────────

  /// 회원 목록 조회 (키워드·구분 필터)
  Future<List<MemberModel>> getMembers({String? keyword, String? memberType, String? membershipStatus}) async {
    var path = '/members';
    final params = <String>[];
    if (keyword != null && keyword.isNotEmpty) params.add('keyword=${Uri.encodeComponent(keyword)}');
    if (memberType != null) params.add('memberType=$memberType');
    if (membershipStatus != null) params.add('membershipStatus=$membershipStatus');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    final data = await _get(path) as List;
    return data.map((e) => MemberModel.fromJson(e)).toList();
  }

  /// 회원 상세 조회
  Future<MemberModel> getMemberDetail(int memberId) async {
    final data = await _get('/members/$memberId');
    return MemberModel.fromJson(data);
  }

  /// 오늘 만료 회원 목록 조회
  Future<List<MemberModel>> getExpiringToday() async {
    final data = await _get('/members/expiring-today') as List;
    return data.map((e) => MemberModel.fromJson(e)).toList();
  }

  /// 만료 회원 목록 조회
  Future<List<MemberModel>> getExpiredMembers() async {
    final data = await _get('/members/expired') as List;
    return data.map((e) => MemberModel.fromJson(e)).toList();
  }

  /// N일 이상 미출석 회원 목록 조회
  Future<List<MemberModel>> getInactiveMembers(int days) async {
    final data = await _get('/members/inactive?days=$days') as List;
    return data.map((e) => MemberModel.fromJson(e)).toList();
  }

  /// 정지 회원 목록 조회
  Future<List<MemberModel>> getSuspendedMembers() async {
    final data = await _get('/members/suspended') as List;
    return data.map((e) => MemberModel.fromJson(e)).toList();
  }

  /// 이번 달 생일자 목록 조회
  Future<List<MemberModel>> getBirthdays() async {
    final data = await _get('/members/birthdays') as List;
    return data.map((e) => MemberModel.fromJson(e)).toList();
  }

  /// 회원 등록
  Future<Map<String, dynamic>> createMember(Map<String, dynamic> body) async {
    return await _post('/members', body);
  }

  /// 회원 정보 수정
  Future<Map<String, dynamic>> updateMember(int memberId, Map<String, dynamic> body) async {
    return await _put('/members/$memberId', body);
  }

  /// 회원 프로필 사진 업로드 — POST /members/{memberId}/photo
  Future<String> uploadMemberPhoto(int memberId, List<int> imageBytes, String filename) async {
    final url = '$baseUrl/members/$memberId/photo';
    AppLogger.req('POST[photo]', url, body: {'filename': filename});
    try {
      final req = http.MultipartRequest('POST', Uri.parse(url));
      final token = await getToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes(
        'photo', imageBytes,
        filename: filename,
      ));
      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);
      final body = _parseBody(response);
      AppLogger.res('POST[photo]', url, response.statusCode, body);
      if (response.statusCode == 401) {
        onUnauthorized?.call();
        throw Exception('인증이 만료되었습니다. 다시 로그인해 주세요.');
      }
      if (response.statusCode != 200 || body?['success'] != true) {
        throw Exception(body?['message'] ?? '사진 업로드 실패');
      }
      return body['data'] as String? ?? '';
    } catch (e) {
      AppLogger.err('POST[photo]', url, e);
      rethrow;
    }
  }

  /// 회원 그룹(memberType) 일괄 변경
  Future<void> bulkUpdateMemberType(List<int> memberIds, String memberType) async {
    await _patch('/members/bulk-type', {
      'memberIds': memberIds,
      'memberType': memberType,
    });
  }

  /// 회원 삭제
  Future<void> deleteMember(int memberId) async {
    await _delete('/members/$memberId');
  }

  // ── Memberships ─────────────────────────────────────────────

  /// 회원의 이용권 이력 조회
  Future<List<MembershipModel>> getMemberships(int memberId) async {
    final data = await _get('/memberships/member/$memberId') as List;
    return data.map((e) => MembershipModel.fromJson(e)).toList();
  }

  /// 이용권 등록
  Future<Map<String, dynamic>> createMembership(Map<String, dynamic> body) async {
    return await _post('/memberships', body);
  }

  /// 이용권 기간 연장
  Future<void> extendMembership(int membershipId, int days) async {
    await _patch('/memberships/$membershipId/extend', {'days': days});
  }

  /// 전체 이용권 일괄 연장
  Future<void> bulkExtend(int days) async {
    await _patch('/memberships/bulk-extend', {'days': days});
  }

  /// 이용권 일시정지 (days: 정지 일수, 0이면 기간 미지정)
  Future<void> pauseMembership(int membershipId, {int days = 0}) async {
    await _patch('/memberships/$membershipId/pause', {'days': days});
  }

  /// 이용권 재개
  Future<void> resumeMembership(int membershipId) async {
    await _patch('/memberships/$membershipId/resume');
  }

  /// 이용권 정지 (days > 0이면 기간 지정, 0이면 무기한)
  Future<void> suspendMembership(int membershipId, {int days = 0}) async {
    await _patch('/memberships/$membershipId/suspend', days > 0 ? {'days': days} : null);
  }

  /// 이용권 삭제 (soft delete)
  Future<void> deleteMembership(int membershipId) async {
    await _delete('/memberships/$membershipId');
  }

  // ── Tickets ─────────────────────────────────────────────────

  /// 이용권 종류 목록 조회 (scope: 'GYM'=센터만, 'COMMON'=공통만, null=전체)
  Future<List<TicketModel>> getTickets({String? scope}) async {
    final query = scope != null ? '?scope=$scope' : '';
    final data = await _get('/tickets$query') as List;
    return data.map((e) => TicketModel.fromJson(e)).toList();
  }

  /// 이용권 종류 저장 (신규·수정)
  Future<TicketModel> saveTicket(TicketModel ticket) async {
    final data = ticket.ticketId == null
        ? await _post('/tickets', ticket.toJson())
        : await _put('/tickets/${ticket.ticketId}', ticket.toJson());
    return TicketModel.fromJson(data);
  }

  /// 이용권 종류 삭제
  Future<void> deleteTicket(int ticketId) async {
    await _delete('/tickets/$ticketId');
  }

  // ── Attendance ──────────────────────────────────────────────

  /// 오늘 출석 목록 조회
  Future<List<AttendanceModel>> getTodayAttendance() async {
    final data = await _get('/attendance/today') as List;
    return data.map((e) => AttendanceModel.fromJson(e)).toList();
  }

  /// 날짜별 출석 목록 조회
  Future<List<AttendanceModel>> getAttendanceByDate(String date) async {
    final data = await _get('/attendance/date/$date') as List;
    return data.map((e) => AttendanceModel.fromJson(e)).toList();
  }

  /// 시간대별 출석 통계 조회
  Future<List<Map<String, dynamic>>> getHourlyStats(String date) async {
    final data = await _get('/attendance/hourly?date=$date') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 회원별 출석 이력 조회
  Future<List<AttendanceModel>> getMemberAttendance(int memberId,
      {String? from, String? to}) async {
    var path = '/attendance/member/$memberId';
    final params = <String>[];
    if (from != null) params.add('from=$from');
    if (to != null) params.add('to=$to');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    final data = await _get(path) as List;
    return data.map((e) => AttendanceModel.fromJson(e)).toList();
  }

  /// 출석 기록 삭제
  Future<void> deleteAttendance(int attendanceId) async {
    await _delete('/attendance/$attendanceId');
  }

  /// 수동 출석 등록 (임의 날짜/시각)
  /// date: YYYY-MM-DD, inTime/outTime: HH:mm
  Future<void> createManualAttendance({
    required int memberId,
    required String date,
    required String inTime,
    String? outTime,
  }) async {
    await _post('/attendance/manual', {
      'memberId': memberId,
      'attendanceDate': date,
      'attendanceTime': inTime,
      if (outTime != null && outTime.isNotEmpty) 'checkoutTime': outTime,
    });
  }

  /// 회원별 매출 이력 조회
  Future<List<AccountingModel>> getMemberAccounting(int memberId) async {
    final data = await _get('/accounting/member/$memberId') as List;
    return data.map((e) => AccountingModel.fromJson(e)).toList();
  }

  /// 회원별 PT 세션 목록
  Future<List<PtSessionModel>> getPtSessionsByMember(int memberId) async {
    final data = await _get('/pt/sessions/member/$memberId') as List;
    return data.map((e) => PtSessionModel.fromJson(e)).toList();
  }

  // ── Lockers ──────────────────────────────────────────────────

  /// 체육관 라커 전체 목록
  Future<List<LockerModel>> getLockers() async {
    final data = await _get('/lockers') as List;
    return data.map((e) => LockerModel.fromJson(e)).toList();
  }

  /// 회원별 라커 목록
  Future<List<LockerModel>> getLockersByMember(int memberId) async {
    final data = await _get('/lockers/member/$memberId') as List;
    return data.map((e) => LockerModel.fromJson(e)).toList();
  }

  /// 라커 등록
  Future<LockerModel> createLocker(Map<String, dynamic> body) async {
    final data = await _post('/lockers', body);
    return LockerModel.fromJson(data);
  }

  /// 라커 수정
  Future<LockerModel> updateLocker(int lockerId, Map<String, dynamic> body) async {
    final data = await _put('/lockers/$lockerId', body);
    return LockerModel.fromJson(data);
  }

  /// 라커 배정
  Future<LockerModel> assignLocker(int lockerId, Map<String, dynamic> body) async {
    final data = await _patch('/lockers/$lockerId/assign', body);
    return LockerModel.fromJson(data);
  }

  /// 라커 배정 해제
  Future<void> releaseLocker(int lockerId) async {
    await _patch('/lockers/$lockerId/release');
  }

  /// 라커 삭제
  Future<void> deleteLocker(int lockerId) async {
    await _delete('/lockers/$lockerId');
  }

  /// 격자 배치 등록
  Future<List<LockerModel>> createLockerBatch(Map<String, dynamic> body) async {
    final data = await _post('/lockers/batch', body) as List;
    return data.map((e) => LockerModel.fromJson(e)).toList();
  }

  /// 그룹 전체 삭제
  Future<void> deleteLockerGroup(int groupId) async {
    await _delete('/lockers/group/$groupId');
  }

  /// 선택 항목 일괄 삭제
  Future<void> deleteLockerBulk(List<int> ids) async {
    await _delete('/lockers/bulk', body: ids);
  }

  // ── Consultations ────────────────────────────────────────────

  /// 회원 상담 목록
  Future<List<ConsultationModel>> getConsultations(int memberId) async {
    final data = await _get('/consultations/member/$memberId') as List;
    return data.map((e) => ConsultationModel.fromJson(e)).toList();
  }

  /// 상담 등록
  Future<ConsultationModel> createConsultation(Map<String, dynamic> body) async {
    final data = await _post('/consultations', body);
    return ConsultationModel.fromJson(data);
  }

  /// 상담 수정
  Future<ConsultationModel> updateConsultation(int consultationId, Map<String, dynamic> body) async {
    final data = await _put('/consultations/$consultationId', body);
    return ConsultationModel.fromJson(data);
  }

  /// 상담 삭제
  Future<void> deleteConsultation(int consultationId) async {
    await _delete('/consultations/$consultationId');
  }

  // ── Notifications ────────────────────────────────────────────

  /// 알림톡 템플릿 목록 조회
  Future<List<Map<String, dynamic>>> getNotificationTemplates() async {
    final data = await _get('/notifications/templates') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 알림톡 발송
  Future<void> sendNotification(Map<String, dynamic> request) async {
    await _post('/notifications/send', request);
  }

  /// 알림톡 발송 로그 조회
  Future<List<Map<String, dynamic>>> getNotificationLogs({String? from, String? to}) async {
    var path = '/notifications/logs';
    if (from != null) path += '?fromDate=$from${to != null ? "&toDate=$to" : ""}';
    final data = await _get(path) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ── Accounting ───────────────────────────────────────────────

  /// 일별 매출 요약 조회
  Future<List<Map<String, dynamic>>> getDailySummary(String from, String to) async {
    final data = await _get('/accounting/daily?from=$from&to=$to') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 지출 항목별 합계 조회
  Future<List<Map<String, dynamic>>> getExpenseSummary(String from, String to) async {
    final data = await _get('/accounting/expense-summary?from=$from&to=$to') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 특정 날짜 매출/매입 상세 내역
  Future<List<Map<String, dynamic>>> getAccountingDetails(String date) async {
    final data = await _get('/accounting/details?date=$date') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 월별 매출 요약 조회
  Future<List<Map<String, dynamic>>> getMonthlySummary(int year) async {
    final data = await _get('/accounting/monthly?year=$year') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 연별 매출 요약 조회
  Future<List<Map<String, dynamic>>> getYearlySummary() async {
    final data = await _get('/accounting/yearly') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 미수금 목록 조회
  Future<List<Map<String, dynamic>>> getUnpaidList() async {
    final data = await _get('/accounting/unpaid') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 미수금 수납 처리
  Future<void> receiveUnpaid(int accountingId, {
    required String paymentMethod,
    String? cardCompany,
    int? amount,
  }) async {
    await _patch('/accounting/$accountingId/receive', {
      'paymentMethod': paymentMethod,
      if (cardCompany != null) 'cardCompany': cardCompany,
      if (amount != null) 'amount': amount,
    });
  }

  /// 기타 매출 등록
  Future<Map<String, dynamic>> createExtraSales(Map<String, dynamic> body) async {
    return await _post('/accounting/extra', body);
  }

  /// 지출 등록
  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> body) async {
    return await _post('/accounting/purchase', body);
  }

  // ── Codes ────────────────────────────────────────────────────

  /// 공통코드 그룹별 코드 목록 조회
  Future<List<Map<String, dynamic>>> getCodes(String groupCode) async {
    final data = await _get('/codes/$groupCode') as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ── Staff (Admins) ───────────────────────────────────────────

  /// 직원 목록 조회
  Future<List<Map<String, dynamic>>> getStaff() async {
    final data = await _get('/admins') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 직원 등록
  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> body) async {
    return await _post('/admins', body);
  }

  /// 직원 정보 수정
  Future<void> updateStaff(int adminId, Map<String, dynamic> body) async {
    await _put('/admins/$adminId', body);
  }

  /// 직원 비활성화
  Future<void> deleteStaff(int adminId) async {
    await _delete('/admins/$adminId');
  }

  /// 직원 출근 이력 조회
  Future<List<Map<String, dynamic>>> getStaffAttendance(
    int adminId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final f = (from ?? DateTime.now().subtract(const Duration(days: 90)))
        .toIso8601String()
        .substring(0, 10);
    final t = (to ?? DateTime.now()).toIso8601String().substring(0, 10);
    final data = await _get('/admins/$adminId/attendance?from=$f&to=$t') as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ── PT 관리 ─────────────────────────────────────────────────

  /// 트레이너 목록 조회 (is_trainer = Y)
  Future<List<Map<String, dynamic>>> getTrainers() async {
    final data = await _get('/pt/trainers') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// PT 계약 목록 (전체 또는 트레이너별)
  Future<List<PtContractModel>> getPtContracts({int? trainerId}) async {
    final path = trainerId != null
        ? '/pt/contracts?trainerId=$trainerId'
        : '/pt/contracts';
    final data = await _get(path) as List;
    return data.map((e) => PtContractModel.fromJson(e)).toList();
  }

  /// 회원별 PT 계약 목록
  Future<List<PtContractModel>> getPtContractsByMember(int memberId) async {
    final data = await _get('/pt/contracts/member/$memberId') as List;
    return data.map((e) => PtContractModel.fromJson(e)).toList();
  }

  /// PT 계약 등록
  Future<PtContractModel> createPtContract(Map<String, dynamic> body) async {
    final data = await _post('/pt/contracts', body);
    return PtContractModel.fromJson(data);
  }

  /// PT 계약 수정
  Future<PtContractModel> updatePtContract(int contractId, Map<String, dynamic> body) async {
    final data = await _put('/pt/contracts/$contractId', body);
    return PtContractModel.fromJson(data);
  }

  /// PT 계약 취소
  Future<void> cancelPtContract(int contractId) async {
    await _delete('/pt/contracts/$contractId');
  }

  /// PT 세션 목록 (날짜 또는 기간)
  Future<List<PtSessionModel>> getPtSessions({String? date, String? from, String? to}) async {
    String path;
    if (from != null && to != null) {
      path = '/pt/sessions?from=$from&to=$to';
    } else {
      path = '/pt/sessions${date != null ? '?date=$date' : ''}';
    }
    final data = await _get(path) as List;
    return data.map((e) => PtSessionModel.fromJson(e)).toList();
  }

  /// 계약별 세션 목록
  Future<List<PtSessionModel>> getPtSessionsByContract(int contractId) async {
    final data = await _get('/pt/sessions/contract/$contractId') as List;
    return data.map((e) => PtSessionModel.fromJson(e)).toList();
  }

  /// PT 세션 등록
  Future<PtSessionModel> createPtSession(Map<String, dynamic> body) async {
    final data = await _post('/pt/sessions', body);
    return PtSessionModel.fromJson(data);
  }

  /// PT 세션 수정
  Future<PtSessionModel> updatePtSession(int sessionId, Map<String, dynamic> body) async {
    final data = await _put('/pt/sessions/$sessionId', body);
    return PtSessionModel.fromJson(data);
  }

  /// PT 세션 완료
  Future<PtSessionModel> completePtSession(int sessionId) async {
    final data = await _patch('/pt/sessions/$sessionId/complete');
    return PtSessionModel.fromJson(data);
  }

  /// PT 세션 취소
  Future<PtSessionModel> cancelPtSession(int sessionId) async {
    final data = await _patch('/pt/sessions/$sessionId/cancel');
    return PtSessionModel.fromJson(data);
  }

  /// PT 세션 노쇼
  Future<PtSessionModel> noShowPtSession(int sessionId) async {
    final data = await _patch('/pt/sessions/$sessionId/no-show');
    return PtSessionModel.fromJson(data);
  }

  // ── Super Admin ──────────────────────────────────────────────

  /// 전체 체육관 목록 조회 (슈퍼 관리자)
  Future<List<Map<String, dynamic>>> getAllGyms() async {
    final data = await _get('/super/gyms') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 체육관 등록 (슈퍼 관리자)
  Future<Map<String, dynamic>> registerGym(Map<String, dynamic> body) async {
    return await _post('/super/gyms', body);
  }

  /// 체육관 기본 정보 수정 (슈퍼 관리자)
  Future<Map<String, dynamic>> updateGym(int gymId, Map<String, dynamic> body) async {
    final data = await _put('/super/gyms/$gymId', body);
    return data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
  }

  /// 체육관 광고 설정 변경 (슈퍼 관리자)
  Future<void> updateGymAdSettings(int gymId, {
    required String adEnabled,
    required String adClient,
    required String adSlot,
  }) async {
    await _put('/super/gyms/$gymId/ad', {
      'adEnabled': adEnabled,
      'adClient': adClient,
      'adSlot': adSlot,
    });
  }

  /// 슈퍼어드민: 이용권 목록 (gymId, scope 필터 가능)
  Future<List<TicketModel>> getAllTickets({int? gymId, String? scope}) async {
    final params = <String, String>{};
    if (gymId != null) params['gymId'] = gymId.toString();
    if (scope != null) params['scope'] = scope;
    final query = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _get('/super/tickets$query') as List;
    return data.map((e) => TicketModel.fromJson(e)).toList();
  }

  /// 슈퍼어드민: 이용권 저장 (생성/수정)
  Future<TicketModel> saveGlobalTicket(TicketModel ticket) async {
    final data = ticket.ticketId == null
        ? await _post('/super/tickets', ticket.toJson())
        : await _put('/super/tickets/${ticket.ticketId}', ticket.toJson());
    return TicketModel.fromJson(data);
  }

  /// 슈퍼어드민: 이용권 삭제
  Future<void> deleteGlobalTicket(int ticketId) async {
    await _delete('/super/tickets/$ticketId');
  }

  // ── Member Excel Upload ─────────────────────────────────────

  /// 회원 엑셀 일괄 업로드 — 로그인한 체육관에 등록 (센터 관리자)
  /// 엑셀 업로드 배치 이력 목록 조회 — 센터
  Future<List<dynamic>> getUploadBatches() async {
    final data = await _get('/members/upload-batches');
    return data is List ? data : [];
  }

  /// 엑셀 업로드 배치 이력 목록 조회 — 슈퍼 관리자 (특정 체육관)
  Future<List<dynamic>> getUploadBatchesForGym(int gymId) async {
    final data = await _get('/super/gyms/$gymId/members/upload-batches');
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> uploadMembersExcel(List<int> bytes, String filename) async {
    return _uploadExcel('/members/upload-excel', bytes, filename);
  }

  /// 회원 엑셀 일괄 업로드 — 특정 체육관에 등록 (슈퍼 관리자)
  Future<Map<String, dynamic>> uploadMembersExcelForGym(
      int gymId, List<int> bytes, String filename) async {
    return _uploadExcel('/super/gyms/$gymId/members/upload-excel', bytes, filename);
  }

  /// 엑셀 업로드 배치 삭제 — 센터 관리자
  Future<Map<String, dynamic>> deleteUploadBatch(String batchId) async {
    final data = await _delete('/members/upload-batch/$batchId');
    return data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
  }

  /// 엑셀 업로드 배치 삭제 — 슈퍼 관리자 (특정 체육관)
  Future<Map<String, dynamic>> deleteUploadBatchForGym(int gymId, String batchId) async {
    final data = await _delete('/super/gyms/$gymId/members/upload-batch/$batchId');
    return data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> _uploadExcel(String path, List<int> bytes, String filename) async {
    final url = '$baseUrl$path';
    AppLogger.req('POST[multipart]', url, body: {'file': filename});
    try {
      final req = http.MultipartRequest('POST', Uri.parse(url));
      final token = await getToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);
      final data = _handle(response, 'POST[multipart]', url);
      return data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
    } catch (e) {
      AppLogger.err('POST[multipart]', url, e);
      rethrow;
    }
  }

  // ── Points ──────────────────────────────────────────────────

  /// 회원 포인트 잔액 + 이력 조회
  Future<Map<String, dynamic>> getMemberPoint(int memberId) async {
    final data = await _get('/points/members/$memberId');
    return Map<String, dynamic>.from(data);
  }

  /// 포인트 수동 적립/차감 (amount > 0: 적립, < 0: 차감)
  Future<Map<String, dynamic>> adjustPoint(int memberId, int amount, String description) async {
    final data = await _post('/points/adjust', {
      'memberId': memberId,
      'amount': amount,
      'description': description,
    });
    return Map<String, dynamic>.from(data);
  }

  /// 체육관 포인트 설정 조회
  Future<Map<String, dynamic>> getPointSettings() async {
    final data = await _get('/gyms/point-settings');
    return Map<String, dynamic>.from(data);
  }

  /// 체육관 포인트 설정 수정
  Future<void> updatePointSettings(String enabled, double ratePercent) async {
    await _put('/gyms/point-settings', {
      'pointEnabled': enabled,
      'pointRatePercent': ratePercent,
    });
  }

  /// 퇴실 관리 모드 조회
  Future<String> getCheckoutMode() async {
    final data = await _get('/gyms/checkout-mode') as Map;
    return data['checkoutMode']?.toString() ?? 'CHECK_IN_ONLY';
  }

  /// 퇴실 관리 모드 수정
  Future<void> updateCheckoutMode(String mode) async {
    await _put('/gyms/checkout-mode', {'checkoutMode': mode});
  }

  // ── 키오스크 공지 설정 ────────────────────────────────────────────

  Future<Map<String, dynamic>> getKioskSettings() async {
    final data = await _get('/gyms/kiosk-settings');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> updateKioskSettings({
    required String mode,
    required String notice,
  }) async {
    await _put('/gyms/kiosk-settings', {
      'kioskDisplayMode': mode,
      'kioskNotice': notice,
    });
  }

  Future<List<int>?> getKioskImage() async {
    final headers = await _headers();
    final uri = Uri.parse('$baseUrl/gyms/kiosk-image');
    AppLogger.req('GET', uri.toString());
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) return response.bodyBytes;
    return null;
  }

  Future<void> uploadKioskImage(List<int> bytes, String filename) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/gyms/kiosk-image');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${token ?? ''}'
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename));
    final streamed = await request.send();
    final body = jsonDecode(await streamed.stream.bytesToString());
    AppLogger.res('POST', uri.toString(), streamed.statusCode, body);
    if (streamed.statusCode != 200) {
      throw Exception(body['message'] ?? '이미지 업로드 실패');
    }
  }

  // ── 전자계약 ─────────────────────────────────────────────────────

  /// 계약서 템플릿 목록
  Future<List<Map<String, dynamic>>> getContractTemplates() async {
    final data = await _get('/contract/templates') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 계약서 템플릿 생성
  Future<Map<String, dynamic>> createContractTemplate(Map<String, dynamic> body) async {
    final data = await _post('/contract/templates', body);
    return Map<String, dynamic>.from(data ?? {});
  }

  /// 계약서 템플릿 수정
  Future<void> updateContractTemplate(int id, Map<String, dynamic> body) async {
    await _put('/contract/templates/$id', body);
  }

  /// 계약서 템플릿 삭제
  Future<void> deleteContractTemplate(int id) async {
    await _delete('/contract/templates/$id');
  }

  /// 계약서 템플릿 대표 설정
  Future<void> activateContractTemplate(int id) async {
    await _put('/contract/templates/$id/activate', {});
  }

  /// 계약서 발송 (SMS 알림톡)
  Future<Map<String, dynamic>> sendContract(Map<String, dynamic> body) async {
    final data = await _post('/contract/send', body);
    return Map<String, dynamic>.from(data ?? {});
  }

  /// 입회 대기 목록 (제출됨 + 미확인)
  Future<List<Map<String, dynamic>>> getPendingContracts() async {
    final data = await _get('/contract/applications/pending') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 전체 계약 신청 목록
  Future<List<Map<String, dynamic>>> getAllContracts() async {
    final data = await _get('/contract/applications') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// 계약서 확인 (PDF 생성 + 이메일 발송)
  Future<void> confirmContract(int applicationId) async {
    await _post('/contract/applications/$applicationId/confirm', {});
  }

  /// 계약 신청 삭제
  Future<void> deleteContract(int applicationId) async {
    await _delete('/contract/applications/$applicationId');
  }

  /// PDF 저장 경로 설정 조회
  Future<Map<String, dynamic>> getContractPdfSettings() async {
    final data = await _get('/contract/pdf-settings');
    return Map<String, dynamic>.from(data ?? {});
  }

  /// PDF 로컬 저장 경로 변경
  Future<void> updateLocalPdfDir(String localPdfDir) async {
    await _put('/contract/pdf-settings', {'localPdfDir': localPdfDir});
  }

  // ── 커뮤니티 — 공지사항 / 전달사항 ────────────────────────────

  Future<List<CommunityPostModel>> getCommunityPosts(String postType, {int? limit}) async {
    var path = '/community/posts?postType=$postType';
    if (limit != null) path += '&limit=$limit';
    final data = await _get(path) as List;
    return data.map((e) => CommunityPostModel.fromJson(e)).toList();
  }

  Future<CommunityPostModel> createCommunityPost(Map<String, dynamic> body) async {
    final data = await _post('/community/posts', body);
    return CommunityPostModel.fromJson(data);
  }

  Future<void> updateCommunityPost(int postId, Map<String, dynamic> body) async {
    await _put('/community/posts/$postId', body);
  }

  Future<void> deleteCommunityPost(int postId) async {
    await _delete('/community/posts/$postId');
  }

  // ── 커뮤니티 — 오늘의 운동 ────────────────────────────────────

  Future<List<WorkoutModel>> getWorkouts({int? limit}) async {
    var path = '/community/workouts';
    if (limit != null) path += '?limit=$limit';
    final data = await _get(path) as List;
    return data.map((e) => WorkoutModel.fromJson(e)).toList();
  }

  Future<WorkoutModel?> getLatestWorkout() async {
    try {
      final data = await _get('/community/workouts/latest');
      if (data == null) return null;
      return WorkoutModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<WorkoutModel> createWorkout(Map<String, dynamic> body) async {
    final data = await _post('/community/workouts', body);
    return WorkoutModel.fromJson(data);
  }

  Future<void> updateWorkout(int workoutId, Map<String, dynamic> body) async {
    await _put('/community/workouts/$workoutId', body);
  }

  Future<void> deleteWorkout(int workoutId) async {
    await _delete('/community/workouts/$workoutId');
  }

  // ── 고객 구분 (MemberGroupDef) ─────────────────────────────

  /// 고객 구분 목록 조회
  Future<List<MemberGroupDefModel>> getMemberGroupDefs() async {
    final data = await _get('/member-groups') as List;
    return data.map((e) => MemberGroupDefModel.fromJson(e)).toList();
  }

  /// 고객 구분 등록
  Future<MemberGroupDefModel> createMemberGroupDef(Map<String, dynamic> body) async {
    final data = await _post('/member-groups', body);
    return MemberGroupDefModel.fromJson(data);
  }

  /// 고객 구분 수정
  Future<void> updateMemberGroupDef(int groupDefId, Map<String, dynamic> body) async {
    await _put('/member-groups/$groupDefId', body);
  }

  /// 고객 구분 삭제
  Future<void> deleteMemberGroupDef(int groupDefId) async {
    await _delete('/member-groups/$groupDefId');
  }

  /// 특정 회원의 그룹 일괄 교체
  Future<void> updateMemberGroups(int memberId, List<int> groupDefIds) async {
    await _put('/member-groups/members/$memberId/groups', {'groupDefIds': groupDefIds});
  }

  /// 선택 회원들의 그룹 일괄 교체
  Future<void> bulkUpdateMemberGroups(List<int> memberIds, List<int> groupDefIds) async {
    await _put('/member-groups/members/bulk-groups', {
      'memberIds': memberIds,
      'groupDefIds': groupDefIds,
    });
  }
}
