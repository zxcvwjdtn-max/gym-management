/// 상대 경로(/files/...)를 전체 URL로 변환
String? _fullPhotoUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return 'http://localhost:8080/api$path';
}

/// GROUP_CONCAT 결과 "1,2,3" → [1, 2, 3]
List<int> _parseGroupIds(dynamic v) {
  if (v == null || v.toString().isEmpty) return const [];
  return v.toString()
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();
}

// =================== Member ===================
class MemberModel {
  final int? memberId;
  final int? gymId;
  final String memberNo;
  final String memberName;
  final String? phone;
  final String? email;
  final String? parentPhone;
  final String? postalCode;
  final String? address;
  final String? addressDetail;
  final String? birthDate;
  final String? gender;
  final String? memberType;
  final String? sportType;
  final String? joinDate;
  final String? smsYn;
  final String? memo;
  final String? photoUrl;
  final String? managerName;
  final String? clothRentalYn;
  final String? lockerRentalYn;
  final String? membershipStatus;
  final String? membershipStartDate;
  final String? membershipEndDate;
  final int? remainDays;
  final int? remainCount;
  final String? ticketName;
  final String? ticketType;   // PERIOD / COUNT
  final bool? hasLocker;
  final bool? attendedToday;
  final String? lastAttendanceDate;
  final int? pointBalance;
  final List<int> groupDefIds;  // 고객 구분 그룹 IDs

  MemberModel({
    this.memberId, this.gymId, required this.memberNo, required this.memberName,
    this.phone, this.email, this.parentPhone, this.postalCode, this.address, this.addressDetail,
    this.birthDate, this.gender,
    this.memberType, this.sportType, this.joinDate, this.smsYn, this.memo, this.photoUrl,
    this.managerName, this.clothRentalYn, this.lockerRentalYn,
    this.membershipStatus, this.membershipStartDate, this.membershipEndDate,
    this.remainDays, this.remainCount, this.ticketName, this.ticketType,
    this.hasLocker, this.attendedToday, this.lastAttendanceDate, this.pointBalance,
    this.groupDefIds = const [],
  });

  // JSON에서 객체 생성
  factory MemberModel.fromJson(Map<String, dynamic> json) => MemberModel(
    memberId: json['memberId'],
    gymId: json['gymId'],
    memberNo: json['memberNo'] ?? '',
    memberName: json['memberName'] ?? '',
    phone: json['phone'],
    email: json['email'],
    parentPhone: json['parentPhone'],
    postalCode: json['postalCode'],
    address: json['address'],
    addressDetail: json['addressDetail'],
    birthDate: json['birthDate'],
    gender: json['gender'],
    memberType: json['memberType'],
    sportType: json['sportType'],
    joinDate: json['joinDate'],
    smsYn: json['smsYn'],
    memo: json['memo'],
    photoUrl: _fullPhotoUrl(json['photoUrl']),
    managerName: json['managerName'],
    clothRentalYn: json['clothRentalYn'],
    lockerRentalYn: json['lockerRentalYn'],
    membershipStatus: json['membershipStatus'],
    membershipStartDate: json['membershipStartDate'],
    membershipEndDate: json['membershipEndDate'],
    remainDays: json['remainDays'],
    remainCount: json['remainCount'],
    ticketName: json['ticketName'],
    ticketType: json['ticketType'],
    hasLocker: json['hasLocker'],
    attendedToday: json['attendedToday'],
    lastAttendanceDate: json['lastAttendanceDate'],
    pointBalance: json['pointBalance'],
    groupDefIds: _parseGroupIds(json['groupDefIds']),
  );

  Map<String, dynamic> toJson() => {
    if (memberId != null) 'memberId': memberId,
    if (gymId != null) 'gymId': gymId,
    'memberNo': memberNo,
    'memberName': memberName,
    'phone': phone,
    'email': email,
    'parentPhone': parentPhone,
    'postalCode': postalCode,
    'address': address,
    'addressDetail': addressDetail,
    'birthDate': birthDate,
    'gender': gender,
    'memberType': memberType,
    'sportType': sportType,
    'joinDate': joinDate,
    'smsYn': smsYn ?? 'Y',
    'clothRentalYn': clothRentalYn ?? 'N',
    'lockerRentalYn': lockerRentalYn ?? 'N',
    'memo': memo,
    'photoUrl': photoUrl,
  };
}

// =================== Membership ===================
class MembershipModel {
  final int? membershipId;
  final int? gymId;
  final int? memberId;
  final String? memberName;
  final int? ticketId;
  final String? ticketName;
  final String? startDate;
  final String? endDate;
  final String? status;
  final int? paymentAmount;
  final String? paymentMethod;
  final String? memo;
  final int? remainDays;
  final int? remainCount;
  final String? pauseStartDate;
  final String? pauseEndDate;

  MembershipModel({
    this.membershipId, this.gymId, this.memberId, this.memberName,
    this.ticketId, this.ticketName, this.startDate, this.endDate,
    this.status, this.paymentAmount, this.paymentMethod, this.memo,
    this.remainDays, this.remainCount, this.pauseStartDate, this.pauseEndDate,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) => MembershipModel(
    membershipId: json['membershipId'],
    gymId: json['gymId'],
    memberId: json['memberId'],
    memberName: json['memberName'],
    ticketId: json['ticketId'],
    ticketName: json['ticketName'],
    startDate: json['startDate'],
    endDate: json['endDate'],
    status: json['status'],
    paymentAmount: json['paymentAmount'],
    paymentMethod: json['paymentMethod'],
    memo: json['memo'],
    remainDays: json['remainDays'],
    remainCount: json['remainCount'],
    pauseStartDate: json['pauseStartDate'],
    pauseEndDate: json['pauseEndDate'],
  );
}

// =================== Ticket ===================
class TicketModel {
  final int? ticketId;
  final int? gymId;
  final String ticketName;
  final String? ticketCode;
  final int durationMonths;
  final int? durationDays;
  final int weeklyDays;
  final int price;
  final String? description;
  final String ticketScope; // COMMON=공통 / GYM=체육관별
  final String ticketType;  // PERIOD=기간별 / COUNT=횟수별
  final int? totalCount;    // 횟수별 이용권 총 횟수
  final String? sportType;

  bool get isCommon  => ticketScope == 'COMMON';
  bool get isCount   => ticketType  == 'COUNT';

  TicketModel({
    this.ticketId, this.gymId, required this.ticketName, this.ticketCode,
    required this.durationMonths, this.durationDays, required this.weeklyDays,
    required this.price, this.description,
    this.ticketScope = 'GYM', this.ticketType = 'PERIOD', this.totalCount,
    this.sportType,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
    ticketId: json['ticketId'],
    gymId: json['gymId'],
    ticketName: json['ticketName'] ?? '',
    ticketCode: json['ticketCode'],
    durationMonths: json['durationMonths'] ?? 0,
    durationDays: json['durationDays'],
    weeklyDays: json['weeklyDays'] ?? 0,
    price: json['price'] ?? 0,
    description: json['description'],
    ticketScope: json['ticketScope'] ?? (json['gymId'] == null ? 'COMMON' : 'GYM'),
    ticketType: json['ticketType'] ?? 'PERIOD',
    totalCount: json['totalCount'],
    sportType: json['sportType'],
  );

  Map<String, dynamic> toJson() => {
    if (ticketId != null) 'ticketId': ticketId,
    if (gymId != null) 'gymId': gymId,
    'ticketName': ticketName,
    if (ticketCode != null) 'ticketCode': ticketCode,
    'durationMonths': durationMonths,
    if (durationDays != null) 'durationDays': durationDays,
    'weeklyDays': weeklyDays,
    'price': price,
    if (description != null) 'description': description,
    'ticketScope': ticketScope,
    'ticketType': ticketType,
    if (totalCount != null) 'totalCount': totalCount,
    if (sportType != null) 'sportType': sportType,
  };
}

// =================== GymDashboard ===================
class GymDashboardModel {
  final int gymId;
  final String gymName;
  final int todayAttendance;
  final int activeMembers;
  final int expiringSoon;

  GymDashboardModel({
    required this.gymId, required this.gymName,
    required this.todayAttendance, required this.activeMembers,
    required this.expiringSoon,
  });

  factory GymDashboardModel.fromJson(Map<String, dynamic> json) => GymDashboardModel(
    gymId: json['gymId'],
    gymName: json['gymName'] ?? '',
    todayAttendance: json['todayAttendance'] ?? 0,
    activeMembers: json['activeMembers'] ?? 0,
    expiringSoon: json['expiringSoon'] ?? 0,
  );
}

// =================== PtContract ===================
class PtContractModel {
  final int? contractId;
  final int? gymId;
  final int? trainerId;
  final String? trainerName;
  final String? trainerSpecialty;
  final int? memberId;
  final String? memberName;
  final String? memberNo;
  final String? memberPhone;
  final String? photoUrl;
  final int totalSessions;
  final int usedSessions;
  final int remainSessions;
  final String startDate;
  final String endDate;
  final int price;
  final String status;
  final String? memo;
  final String? createdAt;

  PtContractModel({
    this.contractId, this.gymId, this.trainerId, this.trainerName,
    this.trainerSpecialty, this.memberId, this.memberName, this.memberNo,
    this.memberPhone, this.photoUrl,
    required this.totalSessions, required this.usedSessions,
    required this.remainSessions, required this.startDate,
    required this.endDate, required this.price, required this.status,
    this.memo, this.createdAt,
  });

  factory PtContractModel.fromJson(Map<String, dynamic> j) => PtContractModel(
    contractId: j['contractId'],
    gymId: j['gymId'],
    trainerId: j['trainerId'],
    trainerName: j['trainerName'],
    trainerSpecialty: j['trainerSpecialty'],
    memberId: j['memberId'],
    memberName: j['memberName'],
    memberNo: j['memberNo'],
    memberPhone: j['memberPhone'],
    photoUrl: _fullPhotoUrl(j['photoUrl']),
    totalSessions: j['totalSessions'] ?? 0,
    usedSessions: j['usedSessions'] ?? 0,
    remainSessions: j['remainSessions'] ?? 0,
    startDate: j['startDate'] ?? '',
    endDate: j['endDate'] ?? '',
    price: j['price'] ?? 0,
    status: j['status'] ?? 'ACTIVE',
    memo: j['memo'],
    createdAt: j['createdAt'],
  );
}

// =================== PtSession ===================
class PtSessionModel {
  final int? sessionId;
  final int? contractId;
  final int? gymId;
  final int? trainerId;
  final String? trainerName;
  final int? memberId;
  final String? memberName;
  final String? memberNo;
  final String? photoUrl;
  final String sessionDate;
  final String startTime;
  final String endTime;
  final int sessionNo;
  final String status;
  final String? memo;

  PtSessionModel({
    this.sessionId, this.contractId, this.gymId,
    this.trainerId, this.trainerName, this.memberId,
    this.memberName, this.memberNo, this.photoUrl,
    required this.sessionDate, required this.startTime,
    required this.endTime, required this.sessionNo,
    required this.status, this.memo,
  });

  factory PtSessionModel.fromJson(Map<String, dynamic> j) => PtSessionModel(
    sessionId: j['sessionId'],
    contractId: j['contractId'],
    gymId: j['gymId'],
    trainerId: j['trainerId'],
    trainerName: j['trainerName'],
    memberId: j['memberId'],
    memberName: j['memberName'],
    memberNo: j['memberNo'],
    photoUrl: _fullPhotoUrl(j['photoUrl']),
    sessionDate: j['sessionDate'] ?? '',
    startTime: j['startTime'] ?? '',
    endTime: j['endTime'] ?? '',
    sessionNo: j['sessionNo'] ?? 1,
    status: j['status'] ?? 'SCHEDULED',
    memo: j['memo'],
  );
}

// =================== AttendanceModel ===================
class AttendanceModel {
  final int? attendanceId;
  final int? memberId;
  final String memberName;
  final String memberNo;
  final String? photoUrl;
  final String? birthDate;
  final String? ticketName;
  final String? membershipStatus;
  final String? membershipEndDate;
  final int? remainDays;
  final int? remainCount;
  final String? attendanceDate;       // YYYY-MM-DD
  final DateTime? attendanceTime;
  final DateTime? checkoutTime;
  final String? checkType;
  final int? todayGymAttendanceCount;
  final String? clothRentalYn;
  final String? lockerRentalYn;

  AttendanceModel({
    this.attendanceId, this.memberId, required this.memberName,
    required this.memberNo, this.photoUrl, this.birthDate, this.ticketName,
    this.membershipStatus, this.membershipEndDate, this.remainDays, this.remainCount,
    this.attendanceDate, this.attendanceTime, this.checkoutTime, this.checkType,
    this.todayGymAttendanceCount, this.clothRentalYn, this.lockerRentalYn,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) => AttendanceModel(
    attendanceId: json['attendanceId'],
    memberId: json['memberId'],
    memberName: json['memberName'] ?? '',
    memberNo: json['memberNo'] ?? '',
    photoUrl: _fullPhotoUrl(json['photoUrl']),
    birthDate: json['birthDate'],
    ticketName: json['ticketName'],
    membershipStatus: json['membershipStatus'],
    membershipEndDate: json['membershipEndDate'],
    remainDays: json['remainDays'],
    remainCount: json['remainCount'],
    attendanceDate: json['attendanceDate'],
    attendanceTime: json['attendanceTime'] != null
        ? DateTime.tryParse(json['attendanceTime']) : null,
    checkoutTime: json['checkoutTime'] != null
        ? DateTime.tryParse(json['checkoutTime']) : null,
    checkType: json['checkType'],
    todayGymAttendanceCount: json['todayGymAttendanceCount'],
    clothRentalYn: json['clothRentalYn'],
    lockerRentalYn: json['lockerRentalYn'],
  );
}

// =================== AccountingModel ===================
class AccountingModel {
  final int? accountingId;
  final int? gymId;
  final String? accountingType;   // INCOME / EXPENSE
  final String? category;
  final int? amount;
  final String? description;
  final String? memberName;
  final String? accountingDate;
  final String? paymentMethod;

  AccountingModel({
    this.accountingId, this.gymId, this.accountingType, this.category,
    this.amount, this.description, this.memberName, this.accountingDate,
    this.paymentMethod,
  });

  factory AccountingModel.fromJson(Map<String, dynamic> json) => AccountingModel(
    accountingId: json['accountingId'],
    gymId: json['gymId'],
    accountingType: json['accountingType'],
    category: json['category'],
    amount: json['amount'],
    description: json['description'],
    memberName: json['memberName'],
    accountingDate: json['accountingDate'],
    paymentMethod: json['paymentMethod'],
  );
}

// =================== LockerModel ===================
class LockerModel {
  final int? lockerId;
  final int? gymId;
  final String? lockerNo;
  final int? memberId;
  final String? memberName;
  final String? memberNo;
  final String? startDate;
  final String? endDate;
  final int? monthlyFee;
  final String? memo;
  final String? status;   // AVAILABLE / OCCUPIED / MAINTENANCE

  final int? groupId;
  final int? groupCols;

  LockerModel({
    this.lockerId, this.gymId, this.lockerNo, this.memberId,
    this.memberName, this.memberNo, this.startDate, this.endDate,
    this.monthlyFee, this.memo, this.status,
    this.groupId, this.groupCols,
  });

  factory LockerModel.fromJson(Map<String, dynamic> json) => LockerModel(
    lockerId: json['lockerId'],
    gymId: json['gymId'],
    lockerNo: json['lockerNo'],
    memberId: json['memberId'],
    memberName: json['memberName'],
    memberNo: json['memberNo'],
    startDate: json['startDate'],
    endDate: json['endDate'],
    monthlyFee: json['monthlyFee'],
    memo: json['memo'],
    status: json['status'],
    groupId: json['groupId'],
    groupCols: json['groupCols'],
  );
}

// =================== ConsultationModel ===================
class ConsultationModel {
  final int? consultationId;
  final int? gymId;
  final int? memberId;
  final String? memberName;
  final String? consultDate;
  final String? content;
  final String? createdAt;
  final String? createdBy;

  ConsultationModel({
    this.consultationId, this.gymId, this.memberId, this.memberName,
    this.consultDate, this.content, this.createdAt, this.createdBy,
  });

  factory ConsultationModel.fromJson(Map<String, dynamic> json) => ConsultationModel(
    consultationId: json['consultationId'],
    gymId: json['gymId'],
    memberId: json['memberId'],
    memberName: json['memberName'],
    consultDate: json['consultDate'],
    content: json['content'],
    createdAt: json['createdAt'],
    createdBy: json['createdBy'],
  );
}

// =================== MemberGroupDefModel ===================
class MemberGroupDefModel {
  final int? groupDefId;
  final int? gymId;
  final String groupName;
  final String groupColor;
  final int sortOrder;
  final int memberCount;

  MemberGroupDefModel({
    this.groupDefId, this.gymId,
    required this.groupName,
    this.groupColor = '#1565C0',
    this.sortOrder = 0,
    this.memberCount = 0,
  });

  factory MemberGroupDefModel.fromJson(Map<String, dynamic> json) => MemberGroupDefModel(
    groupDefId: json['groupDefId'],
    gymId: json['gymId'],
    groupName: json['groupName'] ?? '',
    groupColor: json['groupColor'] ?? '#1565C0',
    sortOrder: json['sortOrder'] ?? 0,
    memberCount: json['memberCount'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    if (groupDefId != null) 'groupDefId': groupDefId,
    if (gymId != null) 'gymId': gymId,
    'groupName': groupName,
    'groupColor': groupColor,
    'sortOrder': sortOrder,
  };
}

// =================== CommunityPostModel ===================
class CommunityPostModel {
  final int? postId;
  final int? gymId;
  final String postType;   // NOTICE | MESSAGE
  final String title;
  final String? content;
  final String? isPinned;
  final String? createdAt;
  final String? createdBy;

  CommunityPostModel({
    this.postId, this.gymId,
    required this.postType,
    required this.title,
    this.content, this.isPinned,
    this.createdAt, this.createdBy,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> j) => CommunityPostModel(
    postId: j['postId'],
    gymId: j['gymId'],
    postType: j['postType'] ?? 'NOTICE',
    title: j['title'] ?? '',
    content: j['content'],
    isPinned: j['isPinned'],
    createdAt: j['createdAt'],
    createdBy: j['createdBy'],
  );

  Map<String, dynamic> toJson() => {
    if (postId != null) 'postId': postId,
    if (gymId != null) 'gymId': gymId,
    'postType': postType,
    'title': title,
    if (content != null) 'content': content,
    'isPinned': isPinned ?? 'N',
  };
}

// =================== WorkoutModel ===================
class WorkoutModel {
  final int? workoutId;
  final int? gymId;
  final String title;
  final String? content;
  final String? workoutDate;
  final String? createdAt;
  final String? createdBy;

  WorkoutModel({
    this.workoutId, this.gymId,
    required this.title,
    this.content, this.workoutDate,
    this.createdAt, this.createdBy,
  });

  factory WorkoutModel.fromJson(Map<String, dynamic> j) => WorkoutModel(
    workoutId: j['workoutId'],
    gymId: j['gymId'],
    title: j['title'] ?? '',
    content: j['content'],
    workoutDate: j['workoutDate'],
    createdAt: j['createdAt'],
    createdBy: j['createdBy'],
  );

  Map<String, dynamic> toJson() => {
    if (workoutId != null) 'workoutId': workoutId,
    if (gymId != null) 'gymId': gymId,
    'title': title,
    if (content != null) 'content': content,
    if (workoutDate != null) 'workoutDate': workoutDate,
  };
}
