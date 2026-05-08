class AppConfig {
  const AppConfig._();

  // 기본값은 Render 배포 백엔드. 로컬 테스트 시 --dart-define로 덮어쓰기.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://yuhyun-sensor-monitoring-back.onrender.com',
  );

  // true면 기존 목업 데이터 사용, false면 실 API 우선 사용
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );
}
