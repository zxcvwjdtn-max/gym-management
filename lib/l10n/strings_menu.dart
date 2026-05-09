// 메뉴 관련 문자열 (menu.* 키)
const Map<String, Map<String, String>> kMenuStrings = {
  // ── 메뉴: 최상위 ──────────────────────────────────
  'menu.dashboard':      {'ko': '대시보드', 'en': 'Dashboard'},
  'menu.members':        {'ko': '회원관리', 'en': 'Members'},
  'menu.attendance':     {'ko': '출석관리', 'en': 'Attendance'},
  'menu.notifications':  {'ko': '알림톡관리', 'en': 'Notifications'},
  'menu.accounting':     {'ko': '회계관리', 'en': 'Accounting'},
  'menu.statistics':     {'ko': '통계관리', 'en': 'Statistics'},
  'menu.pt':             {'ko': 'PT관리', 'en': 'PT'},
  'menu.center':         {'ko': '센터관리',  'en': 'Center'},
  'menu.community':      {'ko': '커뮤니티',  'en': 'Community'},
  'menu.notice':         {'ko': '공지사항',  'en': 'Notice'},
  'menu.message':        {'ko': '전달사항',  'en': 'Messages'},
  'menu.workout':        {'ko': '오늘의 운동', 'en': "Today's Workout"},
  'menu.logout':         {'ko': '로그아웃', 'en': 'Logout'},
  'menu.superadmin':     {'ko': '전체 관리자', 'en': 'Super Admin'},

  // ── 메뉴: 회원관리 ────────────────────────────────
  'menu.member_list':     {'ko': '회원리스트',       'en': 'Member List'},
  'menu.member_group':    {'ko': '회원그룹리스트',   'en': 'Member Groups'},
  'menu.expiring_today':  {'ko': '오늘 만료회원',    'en': 'Expiring Today'},
  'menu.inactive':        {'ko': '잠수회원',         'en': 'Inactive'},
  'menu.suspended':       {'ko': '정지회원',         'en': 'Suspended'},
  'menu.birthdays':       {'ko': '생일자 목록',      'en': 'Birthdays'},

  // ── 메뉴: 출석관리 ────────────────────────────────
  'menu.attendance_check':   {'ko': '출석체크',        'en': 'Check-In'},
  'menu.attendance_status':  {'ko': '출석현황',        'en': 'Attendance Status'},
  'menu.hourly_attendance':  {'ko': '시간대별 출석',   'en': 'Hourly Attendance'},

  // ── 메뉴: 알림톡 ──────────────────────────────────
  'menu.notification_send':     {'ko': '알림톡 발송', 'en': 'Send'},
  'menu.notification_auto':     {'ko': '자동발송',    'en': 'Auto Send'},
  'menu.notification_template': {'ko': '문자 샘플',   'en': 'Templates'},
  'menu.notification_log':      {'ko': '발송목록',    'en': 'Send History'},

  // ── 메뉴: 회계 ────────────────────────────────────
  'menu.daily_sales':         {'ko': '일별매출',     'en': 'Daily Sales'},
  'menu.monthly_sales':       {'ko': '월별매출',     'en': 'Monthly Sales'},
  'menu.yearly_sales':        {'ko': '년별매출',     'en': 'Yearly Sales'},
  'menu.unpaid':              {'ko': '미수 목록',    'en': 'Unpaid'},
  'menu.monthly_settlement':  {'ko': '월별 정산',    'en': 'Monthly Settlement'},

  // ── 메뉴: 통계 ────────────────────────────────────
  'menu.visit_stats':  {'ko': '방문통계', 'en': 'Visit Stats'},
  'menu.sales_stats':  {'ko': '매출통계', 'en': 'Sales Stats'},

  // ── 메뉴: PT ──────────────────────────────────────
  'menu.pt_programs':   {'ko': 'PT 프로그램',  'en': 'PT Programs'},
  'menu.pt_contracts':  {'ko': 'PT 계약 관리', 'en': 'PT Contracts'},
  'menu.pt_sessions':   {'ko': 'PT 출석 현황', 'en': 'PT Sessions'},
  'menu.pt_schedule':   {'ko': 'PT 스케줄',    'en': 'PT Schedule'},

  // ── 메뉴: 센터관리 ────────────────────────────────
  'menu.staff':              {'ko': '직원관리',      'en': 'Staff'},
  'menu.ticket':             {'ko': '이용권 관리',   'en': 'Tickets'},
  'menu.locker':             {'ko': '라커 관리',     'en': 'Locker'},
  'menu.group_def':          {'ko': '고객 구분 관리', 'en': 'Customer Groups'},
  'menu.bulk_extend':        {'ko': '기간일괄연장',  'en': 'Bulk Extend'},
  'menu.center_accounting':  {'ko': '회계관리',      'en': 'Accounting'},
  'menu.settings':           {'ko': '설정',          'en': 'Settings'},

  // ── 메뉴: 슈퍼 관리자 ────────────────────────────
  'menu.super_gym':     {'ko': '체육관 관리', 'en': 'Gym Management'},
  'menu.super_ticket':  {'ko': '이용권 관리', 'en': 'Tickets'},
  'menu.super_gym_ad':  {'ko': '광고 관리',   'en': 'Ads'},
  'menu.excel_upload':  {'ko': '엑셀 업로드', 'en': 'Excel Upload'},
};
