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

  // ── 상담 관리 ─────────────────────────────────────────────────

  group('상담 관리', () {
    test('상담 목록 조회 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/consultations'));

        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {
              'consultationId': 1,
              'applicantName': '홍길동',
              'phone': '010-1234-5678',
              'consultDate': '2026-05-12',
              'status': 'PENDING',
              'memo': '필라테스 문의',
            },
            {
              'consultationId': 2,
              'applicantName': '김영희',
              'phone': '010-9876-5432',
              'consultDate': '2026-05-11',
              'status': 'COMPLETED',
              'memo': '헬스 등록 문의',
            },
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.getConsultations();
        expect(result.length, 2);
        expect(result[0]['applicantName'], '홍길동');
        expect(result[1]['status'], 'COMPLETED');
      }, () => mockClient);
    });

    test('상담 등록 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['applicantName'], '이신규');
        expect(body['phone'], '010-1111-2222');

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'consultationId': 10,
            'applicantName': '이신규',
            'status': 'PENDING',
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.createConsultation({
          'applicantName': '이신규',
          'phone': '010-1111-2222',
          'consultDate': '2026-05-15',
          'memo': '요가 문의',
        });
        expect(result['consultationId'], 10);
        expect(result['status'], 'PENDING');
      }, () => mockClient);
    });

    test('상담 상태 완료 처리', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, contains('/consultations/1/complete'));

        return http.Response(jsonEncode({
          'success': true,
          'data': null,
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        await service.completeConsultation(1);
      }, () => mockClient);
    });

    test('상담 삭제 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, contains('/consultations/1'));

        return http.Response(jsonEncode({
          'success': true,
          'data': null,
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        await service.deleteConsultation(1);
      }, () => mockClient);
    });

    test('상담 없는 경우 빈 목록 반환', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': true,
          'data': [],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.getConsultations();
        expect(result, isEmpty);
      }, () => mockClient);
    });
  });

  // ── 전자계약 ──────────────────────────────────────────────────

  group('전자계약 관리', () {
    test('계약 확인 처리 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/contract/applications/1/confirm'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'applicationId': 1,
            'confirmedYn': 'Y',
            'pdfUrl': 'http://example.com/contracts/1.pdf',
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.confirmContract(1);
        expect(result['confirmedYn'], 'Y');
        expect(result['pdfUrl'], isNotNull);
      }, () => mockClient);
    });

    test('계약서 발송 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/contract/send'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'applicationId': 5,
            'shortCode': 'def456',
            'contractUrl': 'http://example.com/c/def456',
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.sendContract({
          'templateId': 1,
          'applicantName': '김신입',
          'applicantPhone': '010-5555-6666',
        });
        expect(result['applicationId'], 5);
        expect(result['contractUrl'], contains('c/def456'));
      }, () => mockClient);
    });

    test('이미 확인된 계약 재확인 시 예외', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': false,
          'message': '이미 확인된 계약서입니다.',
          'data': null,
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        expect(
          () => service.confirmContract(1),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });

    test('계약 신청 삭제 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response(jsonEncode({
          'success': true,
          'data': null,
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        await service.deleteContractApplication(1);
      }, () => mockClient);
    });
  });

  // ── 알림/SMS 발송 ─────────────────────────────────────────────

  group('알림 발송', () {
    test('선택 회원에게 SMS 발송 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/notifications/send'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['memberIds'], isA<List>());

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'sentCount': 3,
            'failedCount': 0,
            'usedCredits': 3,
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.sendNotification({
          'templateId': 1,
          'memberIds': [1, 2, 3],
          'message': '안녕하세요, 이번 달 이벤트가 있습니다.',
        });
        expect(result['sentCount'], 3);
        expect(result['failedCount'], 0);
      }, () => mockClient);
    });

    test('크레딧 부족 시 발송 실패', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': false,
          'message': '알림 크레딧이 부족합니다.',
          'data': null,
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        expect(
          () => service.sendNotification({
            'templateId': 1,
            'memberIds': List.generate(1000, (i) => i),
            'message': '대량 발송',
          }),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });

    test('발송 이력 조회 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/notifications/logs'));

        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {
              'logId': 1,
              'templateName': '이벤트 안내',
              'sentCount': 50,
              'sentAt': '2026-05-12T10:00:00',
            },
            {
              'logId': 2,
              'templateName': '만료 예정 안내',
              'sentCount': 8,
              'sentAt': '2026-05-11T09:00:00',
            },
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.getNotificationLogs();
        expect(result.length, 2);
        expect(result[0]['templateName'], '이벤트 안내');
        expect(result[1]['sentCount'], 8);
      }, () => mockClient);
    });
  });

  // ── 포인트 관리 ──────────────────────────────────────────────

  group('포인트 관리', () {
    test('회원 포인트 잔액 조회', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/members/1/points'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'memberId': 1,
            'balance': 3500,
            'totalEarned': 10000,
            'totalUsed': 6500,
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.getMemberPoints(1);
        expect(result['balance'], 3500);
        expect(result['totalEarned'], 10000);
      }, () => mockClient);
    });

    test('포인트 수동 적립 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/members/1/points/earn'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'newBalance': 4000,
            'earnedAmount': 500,
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.earnPoints(1, 500, '이벤트 적립');
        expect(result['newBalance'], 4000);
        expect(result['earnedAmount'], 500);
      }, () => mockClient);
    });

    test('포인트 수동 차감 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/members/1/points/use'));

        return http.Response(jsonEncode({
          'success': true,
          'data': {
            'newBalance': 3000,
            'usedAmount': 500,
          },
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.usePoints(1, 500, '포인트 결제');
        expect(result['newBalance'], 3000);
        expect(result['usedAmount'], 500);
      }, () => mockClient);
    });

    test('잔액 초과 차감 시 예외', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({
          'success': false,
          'message': '포인트 잔액이 부족합니다.',
          'data': null,
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        expect(
          () => service.usePoints(1, 999999, '초과 차감'),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });

    test('포인트 이력 조회 성공', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/members/1/points/history'));

        return http.Response(jsonEncode({
          'success': true,
          'data': [
            {
              'ledgerId': 1,
              'changeType': 'EARN',
              'changeAmount': 1350,
              'balance': 3500,
              'reason': '이용권 결제 적립',
              'createdAt': '2026-05-12T10:00:00',
            },
            {
              'ledgerId': 2,
              'changeType': 'USE',
              'changeAmount': -500,
              'balance': 3000,
              'reason': '포인트 결제',
              'createdAt': '2026-05-10T15:00:00',
            },
          ],
          'message': 'success',
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final service = ApiService();

      await http.runWithClient(() async {
        final result = await service.getPointHistory(1);
        expect(result.length, 2);
        expect(result[0]['changeType'], 'EARN');
        expect(result[1]['changeType'], 'USE');
      }, () => mockClient);
    });
  });
}
