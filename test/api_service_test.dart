import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_management/services/api_service.dart';
import 'package:gym_management/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'admin-jwt-token',
      'gymId': '1',
      'sportType': 'FITNESS',
    });
  });

  // ── 로그인 ─────────────────────────────────────────────────

  group('login - 로그인', () {
    test('로그인 성공 - 토큰 및 체육관 정보 반환', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'token': 'admin-jwt-token',
              'adminName': '테스트관장',
              'gymId': 1,
              'gymName': '테스트헬스',
              'gymCode': 'GYM001',
              'locale': 'ko',
              'checkoutMode': 'CHECK_IN_ONLY',
            },
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.login('owner01', 'password123');
        expect(result['token'], 'admin-jwt-token');
        expect(result['gymName'], '테스트헬스');
        expect(result['locale'], 'ko');
      }, () => mockClient);
    });
  });

  // ── 회원 관리 ─────────────────────────────────────────────

  group('회원 관련 API', () {
    test('getMembers - 전체 회원 목록 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/members'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'memberId': 1,
                'memberName': '김철수',
                'memberNo': 'M00001',
                'phone': '010-1234-5678',
                'membershipStatus': 'ACTIVE',
                'membershipEndDate': '2026-06-30',
              },
              {
                'memberId': 2,
                'memberName': '이영희',
                'memberNo': 'M00002',
                'phone': '010-9876-5432',
                'membershipStatus': 'EXPIRED',
                'membershipEndDate': '2026-04-30',
              },
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final members = await service.getMembers();
        expect(members.length, 2);
        expect(members[0].memberName, '김철수');
        expect(members[1].membershipStatus, 'EXPIRED');
      }, () => mockClient);
    });

    test('getMembers - 키워드 필터 적용', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['keyword'], '김');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'memberId': 1, 'memberName': '김철수', 'memberNo': 'M00001'},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final members = await service.getMembers(keyword: '김');
        expect(members.length, 1);
        expect(members[0].memberName, '김철수');
      }, () => mockClient);
    });

    test('getMemberDetail - 회원 상세 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/members/1'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'memberId': 1,
              'memberName': '김철수',
              'memberNo': 'M00001',
              'phone': '010-1234-5678',
              'email': 'kim@example.com',
              'birthDate': '1990-01-15',
              'gender': 'M',
              'memberType': 'REGULAR',
              'pointBalance': 5000,
            },
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final member = await service.getMemberDetail(1);
        expect(member.memberId, 1);
        expect(member.email, 'kim@example.com');
        expect(member.pointBalance, 5000);
      }, () => mockClient);
    });

    test('getExpiringToday - 오늘 만료 회원', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/members/expiring-today'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'memberId': 3, 'memberName': '만료회원', 'membershipEndDate': '2026-05-12'},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final members = await service.getExpiringToday();
        expect(members.length, 1);
        expect(members[0].memberName, '만료회원');
      }, () => mockClient);
    });

    test('deleteMember - 회원 삭제', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, contains('/members/1'));

        return http.Response(
          jsonEncode({'success': true, 'data': null, 'message': 'success'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        await service.deleteMember(1);
      }, () => mockClient);
    });
  });

  // ── 이용권 관리 ────────────────────────────────────────────

  group('이용권 관련 API', () {
    test('getMemberships - 회원별 이용권 이력', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/memberships/member/1'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'membershipId': 10,
                'ticketName': '3개월권',
                'startDate': '2026-03-01',
                'endDate': '2026-06-01',
                'status': 'ACTIVE',
                'paymentAmount': 270000,
                'paymentMethod': 'CARD',
              },
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final memberships = await service.getMemberships(1);
        expect(memberships.length, 1);
        expect(memberships[0].ticketName, '3개월권');
        expect(memberships[0].status, 'ACTIVE');
      }, () => mockClient);
    });

    test('extendMembership - 이용기간 연장', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/memberships/10/extend'));
        expect(request.url.queryParameters['days'], '30');

        return http.Response(
          jsonEncode({'success': true, 'data': null, 'message': 'success'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        await service.extendMembership(10, 30);
      }, () => mockClient);
    });
  });

  // ── 출석 관리 ─────────────────────────────────────────────

  group('출석 관련 API', () {
    test('getTodayAttendance - 오늘 출석 현황', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/attendance/today'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'attendanceId': 1, 'memberName': '김철수', 'attendanceTime': '2026-05-12T09:30:00'},
              {'attendanceId': 2, 'memberName': '이영희', 'attendanceTime': '2026-05-12T10:00:00'},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final attendances = await service.getTodayAttendance();
        expect(attendances.length, 2);
      }, () => mockClient);
    });
  });

  // ── PT 관리 ───────────────────────────────────────────────

  group('PT 관련 API', () {
    test('getTrainers - 트레이너 목록', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/pt/trainers'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'adminId': 10, 'adminName': '박트레이너', 'specialty': '웨이트'},
              {'adminId': 11, 'adminName': '이트레이너', 'specialty': '필라테스'},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final trainers = await service.getTrainers();
        expect(trainers.length, 2);
        expect(trainers[0]['specialty'], '웨이트');
      }, () => mockClient);
    });

    test('completePtSession - PT 세션 완료', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/pt/sessions/1/complete'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'sessionId': 1, 'status': 'COMPLETED', 'sessionNo': 5},
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final session = await service.completePtSession(1);
        expect(session.status, 'COMPLETED');
      }, () => mockClient);
    });
  });

  // ── 라커 관리 ─────────────────────────────────────────────

  group('라커 관련 API', () {
    test('getLockers - 전체 라커 목록', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'lockerId': 1, 'lockerNo': 'A01', 'status': 'AVAILABLE'},
              {'lockerId': 2, 'lockerNo': 'A02', 'status': 'OCCUPIED'},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final lockers = await service.getLockers();
        expect(lockers.length, 2);
        expect(lockers[0].status, 'AVAILABLE');
        expect(lockers[1].status, 'OCCUPIED');
      }, () => mockClient);
    });

    test('releaseLocker - 라커 반납', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/lockers/1/release'));

        return http.Response(
          jsonEncode({'success': true, 'data': null, 'message': 'success'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        await service.releaseLocker(1);
      }, () => mockClient);
    });
  });

  // ── 전자계약 ─────────────────────────────────────────────

  group('전자계약 API', () {
    test('getContractTemplates - 템플릿 목록', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/contract/templates'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'templateId': 1,
                'templateName': '기본 회원 계약서',
                'isActive': true,
              },
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final templates = await service.getContractTemplates();
        expect(templates.length, 1);
        expect(templates[0]['isActive'], true);
      }, () => mockClient);
    });

    test('getPendingContracts - 입회 대기 목록', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/contract/applications/pending'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'applicationId': 5,
                'applicantName': '신규회원',
                'applicantPhone': '010-1111-2222',
                'submittedYn': true,
                'confirmedYn': false,
              },
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final pending = await service.getPendingContracts();
        expect(pending.length, 1);
        expect(pending[0]['applicantName'], '신규회원');
        expect(pending[0]['confirmedYn'], false);
      }, () => mockClient);
    });
  });

  // ── 포인트 ───────────────────────────────────────────────

  group('포인트 API', () {
    test('getMemberPoint - 회원 포인트 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/points/members/1'));

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'memberId': 1,
              'pointBalance': 3500,
              'ledgers': [
                {'pointType': 'EARN', 'pointAmount': 5000, 'description': '이용권 구매'},
                {'pointType': 'USE', 'pointAmount': -1500, 'description': '포인트 사용'},
              ],
            },
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.getMemberPoint(1);
        expect(result['pointBalance'], 3500);
        expect((result['ledgers'] as List).length, 2);
      }, () => mockClient);
    });
  });

  // ── 공통코드 ─────────────────────────────────────────────

  group('getCodes - 공통코드', () {
    test('SPORT_TYPE 코드 조회', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'code': 'ALL', 'codeName': '전체'},
              {'code': 'FITNESS', 'codeName': '헬스'},
              {'code': 'PILATES', 'codeName': '필라테스'},
              {'code': 'YOGA', 'codeName': '요가'},
              {'code': 'SWIMMING', 'codeName': '수영'},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final codes = await service.getCodes('SPORT_TYPE');
        expect(codes.length, 5);
        expect(codes.any((c) => c['code'] == 'FITNESS'), true);
      }, () => mockClient);
    });
  });

  // ── 매출/회계 ─────────────────────────────────────────────

  group('회계 API', () {
    test('getDailySummary - 일별 매출 요약', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['from'], '2026-05-01');
        expect(request.url.queryParameters['to'], '2026-05-31');

        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'date': '2026-05-01', 'totalIncome': 500000, 'cardAmount': 400000, 'cashAmount': 100000},
              {'date': '2026-05-02', 'totalIncome': 300000, 'cardAmount': 300000, 'cashAmount': 0},
            ],
            'message': 'success',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final summary = await service.getDailySummary('2026-05-01', '2026-05-31');
        expect(summary.length, 2);
        expect(summary[0]['totalIncome'], 500000);
      }, () => mockClient);
    });
  });
}
