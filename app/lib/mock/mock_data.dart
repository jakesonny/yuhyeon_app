class DashboardMetric {
  const DashboardMetric(this.title, this.value);
  final String title;
  final String value;
}

class SensorSummary {
  const SensorSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.lastReceived,
  });
  final String id;
  final String name;
  final String status;
  final String lastReceived;
}

class AlarmItem {
  const AlarmItem({
    required this.sensorCode,
    required this.sensorName,
    required this.severity,
    required this.message,
    required this.timeAgo,
  });
  final String sensorCode;
  final String sensorName;
  final String severity;
  final String message;
  final String timeAgo;
}

class SiteItem {
  const SiteItem({
    required this.name,
    required this.location,
    required this.manager,
    required this.sensorCount,
    required this.warningCount,
  });
  final String name;
  final String location;
  final String manager;
  final int sensorCount;
  final int warningCount;
}

class FileItem {
  const FileItem({
    required this.name,
    required this.size,
    required this.uploadedBy,
    required this.uploadedAt,
  });
  final String name;
  final String size;
  final String uploadedBy;
  final String uploadedAt;
}

class UserItem {
  const UserItem({
    required this.email,
    required this.role,
    required this.phone,
    required this.active,
  });
  final String email;
  final String role;
  final String phone;
  final bool active;
}

class DemoMockData {
  const DemoMockData._();

  static const bool demoMode = true;

  static const dashboardMetrics = <DashboardMetric>[
    DashboardMetric('전체 센서', '128'),
    DashboardMetric('정상', '120'),
    DashboardMetric('주의', '5'),
    DashboardMetric('위험', '3'),
  ];

  static const recentAlarms = <AlarmItem>[
    AlarmItem(
      sensorCode: 'S-302555',
      sensorName: '지하수위계 1',
      severity: '위험',
      message: '1차 상한 기준 초과',
      timeAgo: '1분 전',
    ),
    AlarmItem(
      sensorCode: 'S-302554',
      sensorName: '지하수위계 2',
      severity: '주의',
      message: '측정값 상승 추세',
      timeAgo: '10분 전',
    ),
    AlarmItem(
      sensorCode: 'S-80053',
      sensorName: '수위계 80053',
      severity: '위험',
      message: '데이터 급변 감지',
      timeAgo: '21분 전',
    ),
  ];

  static const sensors = <SensorSummary>[
    SensorSummary(id: '1', name: 'S-302555', status: '위험', lastReceived: '1분 전'),
    SensorSummary(id: '2', name: 'S-302554', status: '주의', lastReceived: '5분 전'),
    SensorSummary(id: '3', name: 'S-80053-1', status: '정상', lastReceived: '2분 전'),
    SensorSummary(id: '4', name: 'S-80053-2', status: '정상', lastReceived: '2분 전'),
    SensorSummary(id: '5', name: 'S-110012', status: '정상', lastReceived: '9분 전'),
  ];

  static const sites = <SiteItem>[
    SiteItem(name: 'A 현장', location: '서울', manager: '홍길동', sensorCount: 42, warningCount: 2),
    SiteItem(name: 'B 현장', location: '부산', manager: '김현우', sensorCount: 21, warningCount: 1),
    SiteItem(name: 'C 현장', location: '인천', manager: '이서연', sensorCount: 65, warningCount: 5),
  ];

  static const files = <FileItem>[
    FileItem(name: '보고서_2026_04_23.pdf', size: '2.1 MB', uploadedBy: 'admin', uploadedAt: '오늘'),
    FileItem(name: '현장도면_A.png', size: '980 KB', uploadedBy: 'manager', uploadedAt: '어제'),
    FileItem(name: '월간센서요약.xlsx', size: '430 KB', uploadedBy: 'operator', uploadedAt: '2일 전'),
  ];

  static const users = <UserItem>[
    UserItem(email: 'admin@geomonitor.com', role: 'Administrator', phone: '010-1234-5678', active: true),
    UserItem(email: 'manager@geomonitor.com', role: 'Manager', phone: '010-3333-4444', active: true),
    UserItem(email: 'monitor@geomonitor.com', role: 'Monitor', phone: '010-8888-9999', active: false),
  ];
}
