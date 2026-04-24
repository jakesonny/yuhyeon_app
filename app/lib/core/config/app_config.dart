class AppConfig {
  const AppConfig._();

  // iOS simulator: localhost, Android emulator: 10.0.2.2
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
}
