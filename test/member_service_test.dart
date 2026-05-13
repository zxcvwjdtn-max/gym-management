import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_management/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'test-jwt-token',
      'gymId': '1',
      'sportType': 'FITNESS',
    });
  });

  // ── 회원 등록/수정 ─────────────────────────────────────────

  group('createMember - 회원 등록', () {
    test('필수 정보로 회원 등록 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/members'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['memberName'], '신규회원');
        expect(body['phone'], '010-9999-0000');

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'memberId': 100,
            'memberName': '신규회원',
            'memberNo': 'M00100',
            'sportType': 'FITNESS',
            'memberType': 'REGULAR',
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final result = await service.createMember({
          'memberName': '신규회원',
          'phone': '010-9999-0000',
          'memberType': 'REGULAR',
        });
        expect(result['memberId'], 100);
        expect(result['memberNo'], 'M00100');
      }, () => mockClient);
    });

    test('중복 회원번호 등록 시 예외 발생', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': false,
          'message': '이미 존재하는 회원번호입니다.',
          'data': null,
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        expect(
          () => service.createMember({'memberName': '중복회원', 'memberNo': 'M00001'}),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });
  });

  group('updateMember - 회원 정보 수정', () {
    test('회원 정보 수정 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, contains('/members/1'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {'memberId': 1, 'memberName': '수정된이름', 'phone': '010-1111-2222'},
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final result = await service.updateMember(1, {'memberName': '수정된이름', 'phone': '010-1111-2222'});
        expect(result['memberName'], '수정된이름');
      }, () => mockClient);
    });
  });

  // ── 이용권 관련 ────────────────────────────────────────────

  group('createMembership - 이용권 등록', () {
    test('이용권 신규 등록 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/memberships'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'membershipId': 50,
            'ticketName': '3개월권',
            'startDate': '2026-05-01',
            'endDate': '2026-08-01',
            'status': 'ACTIVE',
            'paymentAmount': 270000,
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final result = await service.createMembership({
          'memberId': 1,
          'ticketId': 3,
          'startDate': '2026-05-01',
          'paymentAmount': 270000,
          'paymentMethod': 'CARD',
        });
        expect(result['status'], 'ACTIVE');
        expect(result['paymentAmount'], 270000);
      }, () => mockClient);
    });

    test('존재하지 않는 이용권ID로 등록 시 실패', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': false,
          'message': '이용권을 찾을 수 없습니다.',
          'data': null,
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        expect(
          () => service.createMembership({'memberId': 1, 'ticketId': 9999}),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });
  });

  group('pauseMembership / resumeMembership - 정지/해제', () {
    test('이용권 일시정지 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/memberships/10/pause'));
        return http.Response(jsonEncode({'success': true, 'data': null, 'message': 'success'}),
            200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        await service.pauseMembership(10, days: 14);
      }, () => mockClient);
    });

    test('일시정지 해제 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/memberships/10/resume'));
        return http.Response(jsonEncode({'success': true, 'data': null, 'message': 'success'}),
            200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        await service.resumeMembership(10);
      }, () => mockClient);
    });
  });

  // ── 라커 ─────────────────────────────────────────────────

  group('assignLocker / releaseLocker - 라커 배정/반납', () {
    test('회원에게 라커 배정 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/lockers/1/assign'));
        return http.Response(jsonEncode({
          'success': true,
          'data': {'lockerId': 1, 'lockerNo': 'A01', 'status': 'OCCUPIED', 'memberId': 5},
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final result = await service.assignLocker(1, {'memberId': 5, 'startDate': '2026-05-01', 'endDate': '2026-06-01'});
        expect(result.status, 'OCCUPIED');
      }, () => mockClient);
    });
  });

  // ── 공통코드 ─────────────────────────────────────────────

  group('getCodes - ALL 코드 제외 로직', () {
    test('SPORT_TYPE에서 ALL 코드 포함 여부 확인', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {'code': 'ALL', 'codeName': '전체', 'sortOrder': 0},
            {'code': 'FITNESS', 'codeName': '헬스', 'sortOrder': 1},
            {'code': 'PILATES', 'codeName': '필라테스', 'sortOrder': 2},
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final codes = await service.getCodes('SPORT_TYPE');
        // API는 ALL 포함 반환, UI에서 필터링
        expect(codes.any((c) => c['code'] == 'ALL'), true);
        expect(codes.length, 3);
      }, () => mockClient);
    });
  });

  // ── 고객 구분 ─────────────────────────────────────────────

  group('getMemberGroupDefs - 고객 구분 관리', () {
    test('고객 구분 목록 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/member-groups'));
        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {'groupDefId': 1, 'groupName': 'VIP', 'groupColor': '#FFD700'},
            {'groupDefId': 2, 'groupName': '원생', 'groupColor': '#87CEEB'},
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final groups = await service.getMemberGroupDefs();
        expect(groups.length, 2);
        expect(groups[0].groupName, 'VIP');
      }, () => mockClient);
    });

    test('회원 구분 일괄 업데이트', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, contains('/member-groups/members/1/groups'));
        return http.Response(jsonEncode({'success': true, 'data': null, 'message': 'success'}),
            200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        await service.updateMemberGroups(1, [1, 2]);
      }, () => mockClient);
    });
  });

  // ── 직원 관리 ─────────────────────────────────────────────

  group('직원 관련 API', () {
    test('직원 목록 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/admins'));
        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {'adminId': 1, 'adminName': '박트레이너', 'isTrainer': 'Y', 'specialty': '웨이트'},
            {'adminId': 2, 'adminName': '이직원', 'isTrainer': 'N'},
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final staff = await service.getStaff();
        expect(staff.length, 2);
        expect(staff[0]['isTrainer'], 'Y');
      }, () => mockClient);
    });

    test('직원 등록 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response(jsonEncode({
          'success': true,
          'data': {'adminId': 10, 'adminName': '신규직원', 'loginId': 'staff10'},
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final result = await service.createStaff({
          'adminName': '신규직원',
          'loginId': 'staff10',
          'loginPw': 'password123!',
          'authGroupId': 3,
        });
        expect(result['adminId'], 10);
      }, () => mockClient);
    });

    test('직원 출근 이력 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/admins/1/attendance'));
        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {'attendanceDate': '2026-05-12', 'checkInAt': '09:00:00', 'checkOutAt': '18:00:00'},
            {'attendanceDate': '2026-05-11', 'checkInAt': '09:05:00', 'checkOutAt': null},
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final attendance = await service.getStaffAttendance(1);
        expect(attendance.length, 2);
        expect(attendance[0]['checkOutAt'], '18:00:00');
        expect(attendance[1]['checkOutAt'], null);
      }, () => mockClient);
    });
  });

  // ── 통계 ─────────────────────────────────────────────────

  group('통계 API', () {
    test('연도별 월별 매출 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['year'], '2026');
        return http.Response(jsonEncode({
          'success': true,
          'data': List.generate(12, (i) => {
            'month': '2026-${(i + 1).toString().padLeft(2, '0')}',
            'totalIncome': 5000000 + i * 100000,
            'cardAmount': 4000000,
            'cashAmount': 1000000,
          }),
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final summary = await service.getMonthlySummary(2026);
        expect(summary.length, 12);
        expect(summary[0]['month'], '2026-01');
      }, () => mockClient);
    });

    test('시간대별 출석 통계', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/attendance/hourly'));
        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {'hour': 6, 'count': 5},
            {'hour': 7, 'count': 12},
            {'hour': 8, 'count': 25},
            {'hour': 9, 'count': 18},
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();
      await http.runWithClient(() async {
        final stats = await service.getHourlyStats('2026-05-12');
        expect(stats.length, 4);
        expect(stats[2]['count'], 25); // 8시가 피크
      }, () => mockClient);
    });
  });
}
